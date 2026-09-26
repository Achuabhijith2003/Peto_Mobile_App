import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'providers/community_provider.dart';
import 'providers/reel_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/system_status_provider.dart';
import 'screens/errors/maintenance_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Push Notifications (FCM & Local notification channels)
  try {
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('Notification service initialization: $e');
  }

  runApp(const PetoUserApp());
}

class PetoUserApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const PetoUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
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
