import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class FlutterTtsService {
  FlutterTtsService._privateConstructor() {
    _initTts();
  }

  static final FlutterTtsService instance = FlutterTtsService._privateConstructor();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        debugPrint("FlutterTts started speaking");
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint("FlutterTts completed speaking");
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        debugPrint("FlutterTts cancelled speaking");
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint("FlutterTTS error: $msg");
      });
    } catch (e) {
      debugPrint("Failed to initialize FlutterTts: $e");
    }
  }

  /// Speaks the given [text]. Strictly restricted for captioning results.
  Future<void> speakCaption(String text) async {
    if (text.isEmpty) return;
    try {
      // Strictly only speaks captioning results!
      debugPrint("FlutterTts speaking caption result: $text");
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("FlutterTts speak error: $e");
    }
  }

  /// Immediately stops any ongoing speech.
  Future<void> stop() async {
    try {
      debugPrint("FlutterTts stopping speech");
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint("FlutterTts stop error: $e");
    }
  }
}
