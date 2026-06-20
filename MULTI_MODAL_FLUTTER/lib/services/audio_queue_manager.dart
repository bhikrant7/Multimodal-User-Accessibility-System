import 'dart:async';

import 'package:just_audio/just_audio.dart';

enum AudioPriority { low, medium, high }

class AudioQueueEntry {
  final String uri;
  final AudioPriority priority;
  final bool isLocal;

  AudioQueueEntry({
    required this.uri,
    required this.priority,
    this.isLocal = false,
  });
}

class AudioQueueManager {
  AudioQueueManager() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _completeCurrent();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final List<AudioQueueEntry> _queue = [];
  AudioQueueEntry? _current;
  final StreamController<AudioQueueEntry?> _currentController =
      StreamController.broadcast();
  late final StreamSubscription<PlayerState> _playerStateSubscription;

  Stream<AudioQueueEntry?> get currentEntry => _currentController.stream;

  Future<void> playLocal(
    String assetPath, {
    AudioPriority priority = AudioPriority.high,
  }) async {
    await _enqueue(
      AudioQueueEntry(uri: assetPath, priority: priority, isLocal: true),
    );
  }

  Future<void> playRemote(
    String sourceUrl, {
    AudioPriority priority = AudioPriority.medium,
  }) async {
    await _enqueue(
      AudioQueueEntry(uri: sourceUrl, priority: priority, isLocal: false),
    );
  }

  Future<void> _enqueue(AudioQueueEntry entry) async {
    if (_current == null) {
      _current = entry;
      _currentController.add(_current);
      await _startPlayback(entry);
      return;
    }

    if (entry.priority.index > _current!.priority.index) {
      await _player.stop();
      _queue.insert(0, _current!);
      _current = entry;
      _currentController.add(_current);
      await _startPlayback(entry);
      return;
    }

    _queue.add(entry);
  }

  Future<void> _startPlayback(AudioQueueEntry entry) async {
    try {
      if (entry.isLocal) {
        await _player.setAsset(entry.uri);
      } else {
        await _player.setUrl(entry.uri);
      }
      _player.play();
    } catch (error) {
      await _completeCurrent();
    }
  }

  Future<void> _completeCurrent() async {
    _current = null;
    _currentController.add(null);
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _current = next;
      _currentController.add(_current);
      await _startPlayback(next);
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> stop() async {
    await _player.stop();
    _queue.clear();
    _current = null;
    _currentController.add(null);
  }

  Future<void> setVolume(double value) => _player.setVolume(value);

  void dispose() {
    _playerStateSubscription.cancel();
    _player.dispose();
    _currentController.close();
  }
}
