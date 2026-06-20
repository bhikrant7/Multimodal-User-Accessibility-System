import 'package:flutter_tts/flutter_tts.dart';

/// A dedicated TTS service used exclusively by the Face Recognition feature.
///
/// This is intentionally isolated from [SignLanguageTtsService] and [AudioQueueManager]
/// so that it can operate independently.
class FaceTtsService {
  FaceTtsService._privateConstructor();
  static final FaceTtsService instance = FaceTtsService._privateConstructor();

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((_) {
      _isSpeaking = false;
    });
    _initialized = true;
  }

  /// Speak the given [text].
  ///
  /// If TTS is already speaking, the current speech is stopped first
  /// and restarted with the new text.
  /// If [text] is empty, this is a no-op.
  Future<void> speak(String text) async {
    if (!_initialized) {
      await init();
    }
    if (text.trim().isEmpty) return;

    // Always stop first to prevent overlapping sessions.
    await _tts.stop();
    _isSpeaking = false;

    await _tts.speak(text);
  }

  /// Immediately stop any in-progress speech.
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;

  Future<void> dispose() async {
    await _tts.stop();
    _isSpeaking = false;
  }
}
