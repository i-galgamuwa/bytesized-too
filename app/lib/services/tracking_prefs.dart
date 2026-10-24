import 'package:shared_preferences/shared_preferences.dart';

class TrackingPrefs {
  static const _activeKey = 'is_tracking_active';
  static const _consentKey = 'privacy_consent_given';
  static const _batteryAskedKey = 'battery_optimization_asked';

  static Future<void> setActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, active);
  }

  static Future<bool> isActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activeKey) ?? false;
  }

  static Future<void> setConsentGiven(bool consent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, consent);
  }

  static Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  static Future<bool> hasAskedBatteryOptimization() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_batteryAskedKey) ?? false;
  }

  static Future<void> markBatteryOptimizationAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_batteryAskedKey, true);
  }
}
