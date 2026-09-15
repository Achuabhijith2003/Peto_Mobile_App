import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SystemStatusProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isMaintenanceMode = false;
  String? _maintenanceMessage;

  bool get isMaintenanceMode => _isMaintenanceMode;
  String? get maintenanceMessage => _maintenanceMessage;

  SystemStatusProvider() {
    // Hook global Dio interceptor
    ApiService.onMaintenanceDetected = (msg) {
      triggerMaintenance(msg);
    };

    // Initial proactive health check
    checkHealth();
  }

  void triggerMaintenance(String? message) {
    _isMaintenanceMode = true;
    _maintenanceMessage = message ?? "Peto is currently undergoing scheduled maintenance. Please check back shortly.";
    notifyListeners();
  }

  void clearMaintenance() {
    _isMaintenanceMode = false;
    _maintenanceMessage = null;
    notifyListeners();
  }

  Future<bool> checkHealth() async {
    try {
      final res = await _apiService.checkHealth();
      if (res['maintenance'] == true || res['status'] == 'MAINTENANCE') {
        _isMaintenanceMode = true;
        _maintenanceMessage = res['message']?.toString() ?? "Peto is currently undergoing scheduled maintenance. Please check back shortly.";
        notifyListeners();
        return false;
      } else {
        if (_isMaintenanceMode) {
          _isMaintenanceMode = false;
          _maintenanceMessage = null;
          notifyListeners();
        }
        return true;
      }
    } catch (_) {
      return false;
    }
  }
}
