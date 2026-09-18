import 'dart:io';
import 'api_service.dart';

/// External Ad Provider & Lifecycle Service for Flutter Mobile
/// Manages Google AdMob banner/native ads with official test units,
/// strict production/staging separation, and fallback safety.
class ExternalAdService {
  ExternalAdService._();
  static final ExternalAdService instance = ExternalAdService._();

  // Official Google AdMob Test Ad Unit IDs (guaranteed non-billable, policy compliant for Dev/Staging)
  static const String testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  /// Get the appropriate test ad unit ID for the current platform and format
  static String getTestAdUnitId({String format = 'BANNER'}) {
    if (Platform.isAndroid) {
      return format == 'NATIVE' ? testNativeAndroid : testBannerAndroid;
    } else if (Platform.isIOS) {
      return format == 'NATIVE' ? testNativeIos : testBannerIos;
    }
    return testBannerAndroid;
  }

  /// Request unified ad decision from Peto Ad Decision Engine
  /// Backend determines if Peto internal ad or external AdMob wins auction
  Future<Map<String, dynamic>?> requestAdDecision({
    String placement = 'FEED',
    int? organicCount,
  }) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    try {
      final decision = await ApiService().fetchUnifiedAdDecision(
        placement: placement,
        organicCount: organicCount,
      );

      final latencyMs = DateTime.now().millisecondsSinceEpoch - startTime;

      if (decision != null && decision['hasAd'] == true) {
        final ad = decision['ad'] as Map<String, dynamic>?;
        if (decision['source'] == 'EXTERNAL' && ad != null) {
          // Log lifecycle event AD_REQUEST -> SUCCESS
          ApiService().trackExternalAdEvent(
            eventType: 'AD_REQUEST',
            provider: ad['provider']?.toString() ?? 'ADMOB',
            placement: placement,
            adUnitId: ad['adUnitId']?.toString(),
            status: 'SUCCESS',
            latencyMs: latencyMs,
          );
        }
        return decision;
      }
    } catch (e) {
      final latencyMs = DateTime.now().millisecondsSinceEpoch - startTime;
      ApiService().trackExternalAdEvent(
        eventType: 'AD_ERROR',
        provider: 'ADMOB',
        placement: placement,
        status: 'FAILURE',
        errorCode: e.toString(),
        latencyMs: latencyMs,
      );
    }
    return null;
  }

  /// Log Impression event for external ad network
  Future<void> logImpression({
    required String provider,
    String? placement,
    String? adUnitId,
    String? creativeId,
  }) async {
    await ApiService().trackExternalAdEvent(
      eventType: 'AD_IMPRESSION',
      provider: provider,
      placement: placement ?? 'FEED',
      adUnitId: adUnitId,
      creativeId: creativeId,
      status: 'SUCCESS',
    );
  }

  /// Log Click event for external ad network
  Future<void> logClick({
    required String provider,
    String? placement,
    String? adUnitId,
    String? creativeId,
  }) async {
    await ApiService().trackExternalAdEvent(
      eventType: 'AD_CLICK',
      provider: provider,
      placement: placement ?? 'FEED',
      adUnitId: adUnitId,
      creativeId: creativeId,
      status: 'SUCCESS',
    );
  }
}
