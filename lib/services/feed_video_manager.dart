import 'package:flutter/foundation.dart';

class FeedVideoManager {
  static final FeedVideoManager _instance = FeedVideoManager._internal();
  factory FeedVideoManager() => _instance;
  FeedVideoManager._internal();

  String? _activeVideoId;
  final Map<String, VoidCallback> _pauseCallbacks = {};
  bool isMuted = true;

  String? get activeVideoId => _activeVideoId;

  void register(String videoId, VoidCallback onPause) {
    _pauseCallbacks[videoId] = onPause;
  }

  void unregister(String videoId) {
    _pauseCallbacks.remove(videoId);
    if (_activeVideoId == videoId) {
      _activeVideoId = null;
    }
  }

  void play(String videoId, VoidCallback onPause) {
    if (_activeVideoId != null && _activeVideoId != videoId) {
      final previousPause = _pauseCallbacks[_activeVideoId];
      if (previousPause != null) {
        try {
          previousPause();
        } catch (e) {
          debugPrint('Error pausing previous video: $e');
        }
      }
    }
    _activeVideoId = videoId;
    _pauseCallbacks[videoId] = onPause;
  }

  void pause(String videoId) {
    if (_activeVideoId == videoId) {
      _activeVideoId = null;
    }
    final pauseCallback = _pauseCallbacks[videoId];
    if (pauseCallback != null) {
      try {
        pauseCallback();
      } catch (e) {
        debugPrint('Error pausing video $videoId: $e');
      }
    }
  }

  void pauseAll() {
    _activeVideoId = null;
    for (final callback in _pauseCallbacks.values) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in pauseAll callback: $e');
      }
    }
  }
}
