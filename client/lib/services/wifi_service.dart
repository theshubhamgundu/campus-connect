import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

class WiFiService {
  WiFiService._private();
  static final WiFiService instance = WiFiService._private();

  static const String campusSsid = 'CampusNet';
  static const String campusPass = 'CampusNet2025';

  Future<bool> _requestLocationPermission() async {
    final status = await Permission.location.status;
    if (status.isGranted) return true;
    final result = await Permission.location.request();
    return result.isGranted;
  }

  Future<String?> getCurrentSsid() async {
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      if (ssid == null) return null;
      return ssid.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  /// Ensure device is connected to CampusNet. Attempts programmatic connect
  /// when not already connected. Returns true if connected to CampusNet.
  Future<bool> ensureConnectedToCampusNet({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      final ssid = await getCurrentSsid();
      if (ssid != null && ssid == campusSsid) {
        return true;
      }

      // Request location permission required for SSID on newer Android
      final ok = await _requestLocationPermission();
      if (!ok) return false;

      // Try to connect programmatically
      try {
        final connected = await WiFiForIoTPlugin.connect(
          campusSsid,
          password: campusPass,
          security: NetworkSecurity.WPA,
          joinOnce: true,
          withInternet: false,
        );
        if (connected == true) {
          // Wait until SSID reflects change
          final end = DateTime.now().add(timeout);
          while (DateTime.now().isBefore(end)) {
            final current = await getCurrentSsid();
            if (current == campusSsid) return true;
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      } catch (e) {
        // ignore and fallthrough to false
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
