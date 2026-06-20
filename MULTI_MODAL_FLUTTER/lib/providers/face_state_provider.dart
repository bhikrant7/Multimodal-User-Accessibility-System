import 'package:flutter_riverpod/flutter_riverpod.dart';

class FaceState {
  final String status;        // 'idle', 'registering', 'identifying', 'complete', 'failed', 'identified'
  final String? message;      // Human-readable prompt text (from backend)
  final String? sessionId;
  final String? personId;
  final double? confidence;

  FaceState({
    this.status = 'idle',
    this.message,
    this.sessionId,
    this.personId,
    this.confidence,
  });

  FaceState copyWith({
    String? status,
    String? message,
    String? sessionId,
    String? personId,
    double? confidence,
  }) {
    return FaceState(
      status: status ?? this.status,
      message: message ?? this.message,
      sessionId: sessionId ?? this.sessionId,
      personId: personId ?? this.personId,
      confidence: confidence ?? this.confidence,
    );
  }
}

class FaceStateNotifier extends StateNotifier<FaceState> {
  FaceStateNotifier() : super(FaceState());

  void updateState(FaceState newState) {
    state = newState;
  }
}

final faceStateProvider = StateNotifierProvider<FaceStateNotifier, FaceState>((ref) {
  return FaceStateNotifier();
});
