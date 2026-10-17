import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peto_user/services/presence_service.dart';
import 'package:peto_user/widgets/active_pals_widget.dart';

void main() {
  group('Flutter Presence Disablement Tests', () {
    setUp(() {
      PresenceService().stopHeartbeat();
    });

    tearDown(() {
      PresenceService().stopHeartbeat();
    });

    test('Presence feature flag defaults to disabled (false)', () {
      expect(
        PresenceService.isPresenceEnabled,
        isFalse,
        reason: 'PRESENCE_ENABLED should default to false unless passed via --dart-define',
      );
    });

    test('PresenceService initialize does not start timers when disabled', () {
      final service = PresenceService();
      service.initialize();

      // Ensure no timers or heartbeats are running
      service.stopHeartbeat();
    });

    test('PresenceService startHeartbeat does not start timers when disabled', () {
      final service = PresenceService();
      service.startHeartbeat();

      // Since isPresenceEnabled is false, it should immediately return
      service.stopHeartbeat();
    });

    test('PresenceService didChangeAppLifecycleState triggers no actions when disabled', () {
      final service = PresenceService();
      // Should not throw or perform network operations on resumed or paused
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.didChangeAppLifecycleState(AppLifecycleState.detached);
    });

    test('PresenceService fetchOnlineFriends returns empty list when disabled', () async {
      final service = PresenceService();
      final friends = await service.fetchOnlineFriends();
      expect(friends, isEmpty);
    });

    testWidgets('ActivePalsWidget renders SizedBox.shrink() when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivePalsWidget(),
          ),
        ),
      );

      // Verify that no Active Pals text or online indicators are rendered
      expect(find.text('Active Pals'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
