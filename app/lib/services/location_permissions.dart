import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

/// Result of asking the user for GPS and notification access.
class LocationPermissionResult {
  LocationPermissionResult({
    required this.allowed,
    required this.message,
  });

  final bool allowed;
  final String message;
}

/// Same permission checks the map screen used before starting GPS.
class LocationPermissions {
  static String permissionMessage(LocationPermission permission) {
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission is turned off for this app. Enable it in app settings to resume GPS.';
    }
    return 'Location permission is needed to record your route.';
  }

  Future<LocationPermissionResult> checkAndRequest() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionResult(
        allowed: false,
        message: 'Location services are disabled. Please enable them.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionResult(
          allowed: false,
          message: 'Location permissions denied.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        allowed: false,
        message:
            'Location permissions are permanently denied. Please enable them from app settings.',
      );
    }

    // Android needs "Allow all the time" for background tracking.
    if (Platform.isAndroid && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    if (Platform.isAndroid && permission != LocationPermission.always) {
      return LocationPermissionResult(
        allowed: false,
        message:
            'Background location is required. Choose "Allow all the time" in app settings.',
      );
    }

    if (Platform.isAndroid) {
      final androidPlugin = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      if (granted == false) {
        return LocationPermissionResult(
          allowed: false,
          message:
              'Notification permission is required for background tracking.',
        );
      }
    }

    return LocationPermissionResult(
      allowed: true,
      message: 'Ready to track.',
    );
  }
}
