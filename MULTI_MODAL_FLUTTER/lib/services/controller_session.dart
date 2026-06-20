import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/connection_status.dart';
import 'audio_queue_manager.dart';
import 'face_tts_service.dart';
import 'websocket_service.dart';
import 'webrtc_service.dart';
import 'flutter_tts_service.dart';

/// Sentinel modes are modes in which the user interacts with the camera
/// (hand gestures, face movements, etc.) as a core feature.
///
/// When one of these modes is active we must NOT re-raise a [PERSON_NEAR]
/// alert for a person who has already been alerted and is still in frame —
/// their natural movements are *expected* input, not a new threat.
const _sentinelModes = {'sign', 'face'};

class ControllerSession {
  ControllerSession({
    required this.webSocket,
    required this.webRTC,
    required this.audioQueue,
    required this.controllerHttpBase,
    required this.onStatusChanged,
    required this.getActiveMode,
    this.onHazardStateChanged,
    this.onModeOverride,
    this.onFrameAgeChanged,
    this.onSignTranslation,
    this.onFaceEvent,
  });

  final WebSocketService webSocket;
  final WebRTCService webRTC;
  final AudioQueueManager audioQueue;
  final String controllerHttpBase;
  final ValueChanged<ConnectionStatus> onStatusChanged;

  /// Returns the currently active mode string (e.g. 'danger', 'sign', 'face').
  ///
  /// This is injected so [ControllerSession] remains Riverpod-agnostic while
  /// still being able to query the live mode at the moment an alert arrives.
  final String Function() getActiveMode;

  /// Called when the backend reports a hazard-state change (e.g. "Alert", "Idle").
  final ValueChanged<String>? onHazardStateChanged;

  /// Called when the backend forces a mode switch (e.g. danger override).
  final ValueChanged<String>? onModeOverride;

  /// Called when the backend reports a new frame age value.
  final ValueChanged<String>? onFrameAgeChanged;

  final ValueChanged<String>? onSignTranslation;

  /// Called when a face event arrives from the backend.
  final ValueChanged<Map<String, dynamic>>? onFaceEvent;

  // ── Sentinel-mode suppression state ──────────────────────────────────────
  //
  // Tracks person IDs that have already been alerted.
  // When the active mode is a sentinel mode and we receive a PERSON_NEAR
  // alert for an ID in this set, we know the same person is still in frame
  // and the alert is suppressed (their movement is expected input, not a
  // new threat).
  //
  // IDs are added on the first (real) alert and removed when the backend
  // signals the person has left the frame via a 'person_left' message.
  // The set is also cleared on disconnect / session dispose.
  final Set<String> _alertedPersonIds = {};

  StreamSubscription<Map<String, dynamic>>? _messages;
  bool _signaling = false;
  String _hazardState = 'Idle';

  Future<void> start() async {
    _messages = webSocket.messages.listen(_handleMessage);
    webSocket.connectionStatus.addListener(_handleStatus);
    _handleStatus();
    await webSocket.connect();
  }

  void _handleStatus() {
    final status = webSocket.connectionStatus.value;
    onStatusChanged(status);
    if (status == ConnectionStatus.connected) {
      startVideo();
    }
    // Clear stale person-ID tracking on disconnect so we start fresh
    // when the connection is re-established.
    if (status == ConnectionStatus.disconnected ||
        status == ConnectionStatus.reconnecting) {
      _alertedPersonIds.clear();
    }
  }

  Future<void> startVideo() async {
    if (_signaling) return;
    _signaling = true;
    try {
      await webRTC.initialize();
      final offer = await webRTC.createOffer();
      webSocket.send({
        'type': 'webrtc_offer',
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
    } catch (error) {
      debugPrint('Unable to start camera stream: $error');
    } finally {
      _signaling = false;
    }
  }

  Future<void> _handleMessage(Map<String, dynamic> message) async {

    // ── Extract state & frame_age from ANY message ──────────────
    // The backend may embed these fields in various message types,
    // not just a dedicated "state" message.
    final msgState = message['state'];
    if (msgState is String && msgState.isNotEmpty) {
      _hazardState = msgState;
      onHazardStateChanged?.call(msgState);
      if (msgState.toLowerCase().contains('alert')) {
        await FlutterTtsService.instance.stop();
        await FaceTtsService.instance.stop();
      }
    }
    final frameAge = message['frame_age'];
    if (frameAge != null) {
      onFrameAgeChanged?.call(frameAge.toString());
    }

    // ── Type-specific handling ───────────────────────────────────
    switch (message['type']) {
  case 'webrtc_answer':
    final sdp = message['sdp'];
    if (sdp is String) {
      await webRTC.acceptAnswer(
        sdp: sdp,
        type: message['sdpType'] as String? ?? 'answer',
      );
    }
    break;

  case 'alert':
    debugPrint('ALERT KEY: ${message['key']}');
    await FlutterTtsService.instance.stop();
    await FaceTtsService.instance.stop();

    // ── Sentinel-mode person-alert suppression ───────────────
    // If we're in a sentinel mode (sign language / face recognition)
    // and the alert is PERSON_NEAR for a person we've already alerted
    // (they stayed in frame), suppress re-triggering.
    // We only suppress PERSON_NEAR — all other danger keys (obstacles,
    // vehicles, dogs, stream loss) must always fire regardless of mode.
    if (message['key'] == 'PERSON_NEAR') {
      final personId = message['person_id'] as String?;
      final activeMode = getActiveMode();
      final isSentinelMode = _sentinelModes.contains(activeMode);

      if (personId != null && isSentinelMode) {
        if (_alertedPersonIds.contains(personId)) {
          // Same person, still in frame, sentinel mode active —
          // their movement/gestures are expected input, not a new threat.
          debugPrint(
            '[ControllerSession] Suppressed PERSON_NEAR re-alert '
            'for person_id=$personId in sentinel mode "$activeMode"',
          );
          break; // Do NOT play audio, do NOT update hazard state
        } else {
          // First time seeing this person — alert normally, then register.
          _alertedPersonIds.add(personId);
          debugPrint(
            '[ControllerSession] Registered person_id=$personId '
            'for sentinel-mode suppression.',
          );
        }
      } else if (personId != null && !isSentinelMode) {
        // In danger mode: always alert, but also track the person ID so
        // that if the user switches to a sentinel mode while they are still
        // in frame we already know their ID and can suppress correctly.
        _alertedPersonIds.add(personId);
      }
      // If personId is null the backend doesn't support ID tracking —
      // fall through to normal alert behaviour unchanged.
    }

    // ── Normal alert handling ────────────────────────────────
    final asset = _alertAssets[message['key']];
    if (asset != null) {
      debugPrint('PLAYING ASSET: $asset');
      await audioQueue.playLocal(
        asset,
        priority: AudioPriority.high,
      );
    }
    final label = _alertLabels[message['key']] ?? 'Alert';
    _hazardState = label;
    onHazardStateChanged?.call(label);
    // Danger alert overrides whatever mode the UI is in
    onModeOverride?.call('danger');
    break;

  // ── Person left frame ────────────────────────────────────────
  // When the backend signals that a tracked person has left the frame,
  // remove them from the suppression set so that if they (or someone
  // else with the same tracker ID) re-enters, an alert fires normally.
  case 'person_left':
    final leftId = message['person_id'] as String?;
    if (leftId != null) {
      _alertedPersonIds.remove(leftId);
      debugPrint(
        '[ControllerSession] person_id=$leftId left frame — '
        'removed from sentinel suppression set.',
      );
    }
    break;

  case 'status':
    final state = message['state'];
    if (state is String && state.isNotEmpty) {
      _hazardState = state;
      onHazardStateChanged?.call(state);
      if (state.toLowerCase().contains('alert')) {
        await FlutterTtsService.instance.stop();
        await FaceTtsService.instance.stop();
      }
    }
    final statusFrameAge = message['frame_age'];
    if (statusFrameAge != null) {
      onFrameAgeChanged?.call('${statusFrameAge}ms');
    }
    break;

  case 'sign_translation':

    final text = message['text'];

    if (text is String && text.isNotEmpty) {

      debugPrint(
        'SIGN TRANSLATION: $text',
      );

      onSignTranslation?.call(
        text,
      );
    }

    break;

  case 'face_event':
    onFaceEvent?.call(message);
    
    final msgKey = message['message_key'] as String?;
    final text = message['text'] as String?;
    
    final normalised = _hazardState.toLowerCase();
    final isAlert = normalised.contains('alert') || normalised.contains('danger');

    if (msgKey != null && !isAlert) {
      final assetPath = _facePromptAssets[msgKey];
      if (assetPath != null) {
        await audioQueue.playLocal(assetPath, priority: AudioPriority.high);
      } else if (msgKey == 'identify_success' || msgKey == 'identify_unknown') {
        if (text != null && text.isNotEmpty) {
          await FaceTtsService.instance.speak(text);
        }
      }
    }
    break;

  case 'audio':
    final url = message['url'];
    if (url is String && url.isNotEmpty) {
      final sourceUrl = Uri.parse(url).hasScheme
          ? url
          : '$controllerHttpBase$url';

      debugPrint('REMOTE AUDIO URL: $sourceUrl');
      await audioQueue.playRemote(
        sourceUrl,
        priority: _audioPriority(
          (message['priority'] as num?)?.toInt() ?? 2,
        ),
      );
    }
    break;

  case 'audio_stop':
    await audioQueue.stop();
    break;

  case 'flutter_tts':
    final text = message['text'] as String?;
    final activeMode = getActiveMode();
    final hazardState = message['state'] as String? ?? '';
    final isAlert = hazardState.toLowerCase().contains('alert');
    if (text != null && activeMode == 'caption' && !isAlert) {
      await FlutterTtsService.instance.speakCaption(text);
    } else {
      debugPrint('[ControllerSession] Ignored flutter_tts message (mode=$activeMode, isAlert=$isAlert, text=$text)');
    }
    onModeOverride?.call('danger');
    break;
}
  }

  Future<void> dispose() async {
    webSocket.connectionStatus.removeListener(_handleStatus);
    await _messages?.cancel();
    await audioQueue.stop();
    _alertedPersonIds.clear();
  }

  static const _alertAssets = <String, String>{
    'OBSTACLE_NEAR': 'assets/audio/danger_alert.mp3',
    'OBSTACLE_MID': 'assets/audio/danger_alert.mp3',
    'PERSON_NEAR': 'assets/audio/person_alert.mp3',
    'VEHICLE_NEAR': 'assets/audio/vehicle_alert.mp3',
    'DOG_NEAR': 'assets/audio/dog_alert.mp3',
    'STREAM_LOST': 'assets/audio/danger_alert.mp3',
  };

  static const _facePromptAssets = <String, String>{
    'registration_start': 'assets/audio/prompts/look_straight.wav',
    'registration_left': 'assets/audio/prompts/turn_left.wav',
    'registration_right': 'assets/audio/prompts/turn_right.wav',
    'registration_complete': 'assets/audio/prompts/registration_complete.wav',
    'registration_failed': 'assets/audio/prompts/registration_left.wav',
  };

  static const _alertLabels = <String, String>{
    'OBSTACLE_NEAR': 'Alert: Obstacle Near',
    'OBSTACLE_MID': 'Alert: Obstacle Mid',
    'PERSON_NEAR': 'Alert: Person Near',
    'VEHICLE_NEAR': 'Alert: Vehicle Near',
    'DOG_NEAR': 'Alert: Dog Near',
    'STREAM_LOST': 'Alert: Stream Lost',
  };

  AudioPriority _audioPriority(int controllerPriority) {
    if (controllerPriority <= 0) return AudioPriority.high;
    if (controllerPriority == 1) return AudioPriority.medium;
    return AudioPriority.low;
  }
}
