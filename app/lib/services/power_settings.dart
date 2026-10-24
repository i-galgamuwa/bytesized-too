import 'package:flutter/services.dart';

/// Talks to Android about battery saver / OEM killers.
class PowerSettings {
  static const _channel = MethodChannel('gps_sales_tracker/power');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final value = await _channel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return value ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } on MissingPluginException {
      // iOS / desktop: nothing to do.
    } catch (_) {
      // User can still change this in system settings.
    }
  }
}
