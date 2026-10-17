import 'dart:async';
import 'package:flutter/widgets.dart';
import 'api_service.dart';

/// Service managing real-time presence heartbeats, app lifecycle transitions,
/// and Active Pals data for the Peto Flutter mobile application.
///
/// Under the free Supabase tier, presence is DISABLED by default to eliminate
/// continuous database writes and polling overhead.
///
/// To re-enable presence:
/// Build or run with: `--dart-define PRESENCE_ENABLED=true`
class PresenceService with WidgetsBindingObserver {
  /// Feature flag: Defaults to false unless explicitly passed via --dart-define
  static const bool isPresenceEnabled = bool.fromEnvironment(
    'PRESENCE_ENABLED',
    defaultValue: false,
  );

  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;

  PresenceService._internal();

  Timer? _heartbeatTimer;
  Timer? _friendsPollTimer;
  final ApiService _apiService = ApiService();
  bool _isInitialized = false;

  /// Initializes presence observers and lifecycle listeners.
  /// When [isPresenceEnabled] is false, this is a strict no-op.
  void initialize() {
    if (!isPresenceEnabled) {
      debugPrint('[Presence] Feature disabled (PRESENCE_ENABLED=false). No timers or heartbeats started.');
      return;
    }

    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    startHeartbeat();
  }

  /// Starts periodic heartbeat (every 30s) and friends list refresh (every 20s).
  /// Strictly guarded against starting when [isPresenceEnabled] is false.
  void startHeartbeat() {
    if (!isPresenceEnabled) return;

    stopHeartbeat();

    // Initial immediate heartbeat
    sendHeartbeat();

    // 30-second interval periodic timer
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sendHeartbeat();
    });
  }

  /// Stops and cleans up all active timers.
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _friendsPollTimer?.cancel();
    _friendsPollTimer = null;
  }

  /// Sends a single presence heartbeat request to /presence/heartbeat.
  /// Strictly no-op if [isPresenceEnabled] is false.
  Future<void> sendHeartbeat() async {
    if (!isPresenceEnabled) return;

    try {
      await _apiService.client.post('/presence/heartbeat');
    } catch (e) {
      // Ignore heartbeat transmission failure
    }
  }

  /// Explicitly marks the user offline when logging out or terminating.
  Future<void> sendOffline() async {
    if (!isPresenceEnabled) return;

    try {
      await _apiService.client.post('/presence/offline');
    } catch (_) {}
  }

  /// Observes app lifecycle transitions.
  /// When disabled, never makes network calls or alters timers.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isPresenceEnabled) return;

    if (state == AppLifecycleState.resumed) {
      startHeartbeat();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      stopHeartbeat();
      sendOffline();
    }
  }

  /// Fetches online friends for the Active Pals tray.
  /// Returns empty list immediately when presence is disabled.
  Future<List<Map<String, dynamic>>> fetchOnlineFriends() async {
    if (!isPresenceEnabled) return [];

    try {
      final response = await _apiService.client.get('/presence/online');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final list = response.data['data'] as List?;
        if (list != null) {
          return list.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  void dispose() {
    stopHeartbeat();
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
  }
}
