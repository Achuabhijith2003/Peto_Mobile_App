import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import '../main.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/posts/post_detail_screen.dart';
import '../screens/profile/public_profile_screen.dart';

/// Top-level background message handler invoked when the app is closed or in background.
/// MUST be annotated with @pragma('vm:entry-point') so it isn't stripped by Flutter tree-shaking.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[FCM Background] Received message while app is closed/background: ${message.messageId}');
  debugPrint('[FCM Background] Title: ${message.notification?.title}, Body: ${message.notification?.body}');
  debugPrint('[FCM Background] Data payload: ${message.data}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _cachedFcmToken;

  static const String channelId = 'peto_high_importance_channel';
  static const String channelName = 'Peto Notifications';
  static const String channelDescription =
      'High-priority alerts for Peto interactions, likes, comments, and messages.';

  /// Initialize Firebase, FCM listeners, local notification channels, and permissions.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();
      debugPrint('[PushNotificationService] Firebase Core initialized.');

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Initialize Local Notifications Plugin & Android Channel
      await _setupLocalNotifications();

      // 4. Request OS Notification Permissions (Android 13+ & iOS)
      await requestPermissions();

      // 5. Setup foreground notification listener
      _setupForegroundMessageListener();

      // 6. Setup tap / interaction listeners (background & terminated states)
      _setupNotificationTapListeners();

      // 7. Get and cache FCM token
      await syncTokenWithBackend();

      // 8. Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[PushNotificationService] FCM Token refreshed: $newToken');
        _cachedFcmToken = newToken;
        _registerToken(newToken);
      });

      _isInitialized = true;
      debugPrint('[PushNotificationService] Push notification service fully initialized.');
    } catch (e) {
      debugPrint(
        '[PushNotificationService] Warning: Push notification initialization could not complete: $e\n'
        'Note: Ensure google-services.json is placed in android/app/ for full FCM push capability.',
      );
    }
  }

  /// Configure Android high-importance notification channel & local notification settings
  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationClick(response.payload);
      },
    );

    // Create high-importance Android Notification Channel
    final androidNotificationChannel = const AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);
  }

  /// Request Notification Permissions (Android 13+ and iOS)
  Future<bool> requestPermissions() async {
    try {
      // Request FCM permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      // On Android 13+, request local notifications permission
      if (Platform.isAndroid) {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }

      debugPrint('[PushNotificationService] Notification permission status: ${settings.authorizationStatus}');
      return isAuthorized;
    } catch (e) {
      debugPrint('[PushNotificationService] Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Fetch FCM Token and register with backend server
  Future<void> syncTokenWithBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _cachedFcmToken = token;
        debugPrint('[PushNotificationService] Device FCM Token: $token');
        await _registerToken(token);
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Failed to retrieve FCM token: $e');
    }
  }

  /// Register device token with backend
  Future<void> _registerToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final res = await _apiService.registerDeviceToken(token, platform: platform);
      if (res.statusCode == 200) {
        debugPrint('[PushNotificationService] FCM token successfully registered with backend.');
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Could not register token with backend: $e');
    }
  }

  /// Unregister device token from backend (e.g. on user logout)
  Future<void> unregisterToken() async {
    try {
      if (_cachedFcmToken != null) {
        await _apiService.unregisterDeviceToken(_cachedFcmToken!);
        debugPrint('[PushNotificationService] FCM token unregistered.');
      }
    } catch (e) {
      debugPrint('[PushNotificationService] Error unregistering token: $e');
    }
  }

  /// Listen to messages when app is in the foreground and show high-priority heads-up banner
  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] Foreground notification received: ${message.notification?.title}');

      final notification = message.notification;
      if (notification != null) {
        final androidDetails = AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: notificationDetails,
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  /// Handle user clicking notifications from background or terminated states
  void _setupNotificationTapListeners() {
    // App opened from background state via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[PushNotificationService] Notification tapped from background: ${message.data}');
      _handleNotificationPayload(message.data);
    });

    // App launched from terminated/closed state via notification tap
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[PushNotificationService] App launched from terminated state via notification: ${message.data}');
        _handleNotificationPayload(message.data);
      }
    });
  }

  /// Route to appropriate screen based on payload (Post, Comments, Profile, or Notifications)
  Future<void> _handleNotificationPayload(Map<String, dynamic> data) async {
    try {
      // Retry waiting for navigator to mount (crucial when app is launched from terminated state)
      NavigatorState? navigatorState;
      for (int i = 0; i < 25; i++) {
        navigatorState = PetoUserApp.navigatorKey.currentState;
        if (navigatorState != null) break;
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (navigatorState == null) {
        debugPrint('[PushNotificationService] NavigatorState not available for navigation.');
        return;
      }

      final postId = data['postId']?.toString() ?? data['post_id']?.toString();
      final actorId = data['actorId']?.toString() ?? data['actor_id']?.toString();
      final type = data['type']?.toString().toLowerCase() ?? '';

      debugPrint('[PushNotificationService] Routing notification click: type=$type, postId=$postId, actorId=$actorId');

      // 1. If notification is tied to a post (like, comment, reply, post), navigate directly to PostDetailScreen
      if (postId != null && postId.isNotEmpty) {
        final isCommentType = type == 'comment' || type == 'reply';
        navigatorState.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              postId: postId,
              autoOpenComments: isCommentType,
            ),
          ),
        );
        return;
      }

      // 2. If notification is a follow or user interaction, navigate to PublicProfileScreen
      if (type == 'follow' && actorId != null && actorId.isNotEmpty) {
        navigatorState.push(
          MaterialPageRoute(
            builder: (_) => PublicProfileScreen(userId: actorId),
          ),
        );
        return;
      }

      // 3. Otherwise, navigate to NotificationScreen
      navigatorState.push(
        MaterialPageRoute(
          builder: (_) => const NotificationScreen(),
        ),
      );
    } catch (e) {
      debugPrint('[PushNotificationService] Error navigating on notification tap: $e');
    }
  }

  void _handleLocalNotificationClick(String? payload) {
    try {
      if (payload != null && payload.isNotEmpty) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _handleNotificationPayload(decoded);
            return;
          }
        } catch (_) {}
      }
      _handleNotificationPayload({});
    } catch (e) {
      debugPrint('[PushNotificationService] Error handling local notification click: $e');
    }
  }
}
