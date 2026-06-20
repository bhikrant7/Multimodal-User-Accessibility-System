import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tts_service.dart';
import '../services/sign_language_tts_service.dart';
import '../services/face_tts_service.dart';
import '../models/connection_status.dart';
import '../services/audio_queue_manager.dart';
import '../services/controller_session.dart';
import '../services/websocket_service.dart';
import '../services/webrtc_service.dart';

import 'active_mode_provider.dart';
export 'active_mode_provider.dart';

import 'face_state_provider.dart';
export 'face_state_provider.dart';

final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final audioQueueProvider = Provider<AudioQueueManager>((ref) {
  final manager = AudioQueueManager();
  ref.onDispose(manager.dispose);
  return manager;
});

final ttsProvider = Provider<TtsService>((ref) {
  final tts = TtsService();

  tts.init();

  return tts;
});

/// Hazard-state values that indicate an active alert / danger condition.
/// When any of these are reported, sign-language TTS must stop immediately.
const _alertHazardStates = {'alert', 'danger'};

final signLanguageTtsProvider = Provider<SignLanguageTtsService>((ref) {
  final service = SignLanguageTtsService();
  service.init();

  // Listen to hazard state changes and stop TTS on any alert/danger.
  ref.listen<String>(hazardStateProvider, (previous, next) {
    final normalised = next.toLowerCase();
    if (_alertHazardStates.any((s) => normalised.contains(s))) {
      service.stop();
    }
  });

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final controllerIpProvider = StateProvider<String>((ref) => '192.168.1.8');
final controllerPortProvider = StateProvider<int>((ref) => 8765);
final webrtcStunServerProvider = StateProvider<String>(
  (ref) => 'stun:stun.l.google.com:19302',
);

final websocketUrlProvider = Provider<String>((ref) {
  final ip = ref.watch(controllerIpProvider);
  final port = ref.watch(controllerPortProvider);
  return 'ws://$ip:$port';
});

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final url = ref.watch(websocketUrlProvider);
  final service = WebSocketService(url: url);
  ref.onDispose(service.dispose);
  return service;
});

final connectionStatusProvider = StateProvider<ConnectionStatus>(
  (ref) => ConnectionStatus.disconnected,
);

/// Hazard state reported by the backend (e.g. "Alert", "Idle").
final hazardStateProvider = StateProvider<String>((ref) => 'Idle');

/// Frame age reported by the backend.
final frameAgeProvider = StateProvider<String>((ref) => '—');
final signTranslationProvider = StateProvider<String>((ref) => '');
final webrtcServiceProvider = Provider<WebRTCService>((ref) {
  final service = WebRTCService(
    stunServer: ref.watch(webrtcStunServerProvider),
  );
  ref.onDispose(() async {
    await service.dispose();
  });
  return service;
});

final controllerSessionProvider = Provider<ControllerSession>((ref) {
  final ip = ref.watch(controllerIpProvider);
  final port = ref.watch(controllerPortProvider);
  final session = ControllerSession(
    webSocket: ref.watch(websocketServiceProvider),
    webRTC: ref.watch(webrtcServiceProvider),
    audioQueue: ref.watch(audioQueueProvider),
    controllerHttpBase: 'http://$ip:$port',
    // Provide a live read of the active mode so ControllerSession can
    // check it at alert-arrival time without holding a Riverpod ref.
    getActiveMode: () => ref.read(activeModeProvider),
    onStatusChanged: (status) {
      ref.read(connectionStatusProvider.notifier).state = status;
    },
    onHazardStateChanged: (state) {
      ref.read(hazardStateProvider.notifier).state = state;
    },
    onModeOverride: (mode) {
      ref.read(activeModeProvider.notifier).state = mode;
      ref.read(websocketServiceProvider).send({
        'type': 'set_mode',
        'mode': mode,
      });
    },
    onFrameAgeChanged: (age) {
      ref.read(frameAgeProvider.notifier).state = age;
    },

    onSignTranslation: (text) {
      ref.read(signTranslationProvider.notifier).state = text;
    },
    onFaceEvent: (data) {
      final eventType = data['event_type'] as String?;
      final messageKey = data['message_key'] as String?;
      final sessionId = data['session_id'] as String?;
      final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
      final text = data['text'] as String?;

      final currentState = ref.read(faceStateProvider);
      String status = currentState.status;
      if (eventType == 'PROMPT' || eventType == 'REGISTRATION_PROGRESS') {
        status = 'registering';
      } else if (eventType == 'REGISTRATION_COMPLETE') {
        status = 'complete';
      } else if (eventType == 'REGISTRATION_FAILED') {
        status = 'failed';
      } else if (eventType == 'IDENTIFIED') {
        status = 'identified';
      }

      String? personId;
      double? confidence;
      if (eventType == 'IDENTIFIED') {
        personId = metadata['person_name'] ?? metadata['person_id'] as String?;
        final confVal = metadata['confidence'];
        if (confVal is num) confidence = confVal.toDouble();
      }

      ref.read(faceStateProvider.notifier).updateState(
        FaceState(
          status: status,
          message: text ?? messageKey,
          sessionId: sessionId,
          personId: personId ?? currentState.personId,
          confidence: confidence ?? currentState.confidence,
        )
      );
    },
  );

  // Clear sign translation and handle camera stream switching when active mode changes
  ref.listen<String>(activeModeProvider, (previous, next) {
    ref.read(signTranslationProvider.notifier).state = '';
    final wasFace = previous == 'face';
    final isFace = next == 'face';
    if (wasFace || isFace) {
      ref.read(faceStateProvider.notifier).updateState(FaceState());
      FaceTtsService.instance.stop();
    }
  });

  Future.microtask(() {
    session.start();
  });
  ref.onDispose(session.dispose);
  return session;
});
