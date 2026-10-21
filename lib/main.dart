import 'package:flutter/material.dart';
import 'package:peto_user/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'providers/community_provider.dart';
import 'providers/reel_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/system_status_provider.dart';
import 'screens/errors/maintenance_screen.dart';
import 'services/notification_service.dart';
import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'providers/post_upload_provider.dart';
import 'services/post_upload_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await Workmanager().initialize(postUploadDispatcher);
    } catch (error) {
      debugPrint('Background upload scheduler initialization failed: $error');
    }
  }

  // Initialize Push Notifications (FCM & Local notification channels)
  try {
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('Notification service initialization: $e');
  }

  runApp(const PetoUserApp());
}

class PetoUserApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const PetoUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(
          lazy: false,
          create: (context) => PostUploadProvider(
            onCompleted: () =>
                context.read<PostProvider>().fetchPosts(refresh: true),
          ),
        ),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => ReelProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SystemStatusProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Peto',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: Consumer<SystemStatusProvider>(
          builder: (context, systemStatus, child) {
            if (systemStatus.isMaintenanceMode) {
              return MaintenanceScreen(
                message: systemStatus.maintenanceMessage,
                onResolved: () => systemStatus.clearMaintenance(),
              );
            }
            return child!;
          },
          child: const SplashScreen(),
        ),
      ),
    );
  }
}
