import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import 'database_helper.dart';
import 'services/route_metrics.dart';
import 'services/tracking_prefs.dart';
import 'services/sync_service.dart';

const trackingNotificationChannelId = 'sales_tracker_foreground';
const trackingNotificationId = 888;

const _stopServiceMethod = 'stopService';
const locationUpdateMethod = 'locationUpdate';

final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeBackgroundTrackingService() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
  const channel = AndroidNotificationChannel(
    trackingNotificationChannelId,
    'Sales Tracker',
    description: 'Persistent notification while sales GPS tracking is active.',
    importance: Importance.defaultImportance,
  );

  await _notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundTrackingStart,
      autoStart: false,
      // Resume an open shift if the phone reboots mid-day.
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: trackingNotificationChannelId,
      initialNotificationTitle: 'Sales Tracker Active',
      initialNotificationContent: 'Recording GPS locations',
      foregroundServiceNotificationId: trackingNotificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundTrackingStart,
      onBackground: onIosBackground,
    ),
  );
}

Future<void> startBackgroundTracking() async {
  await TrackingPrefs.setActive(true);
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    return;
  }
  await service.startService();
}

Future<void> stopBackgroundTracking() async {
  await TrackingPrefs.setActive(false);
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke(_stopServiceMethod);
    // Wait briefly for stopSelf() to complete before the shift is closed.
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!await service.isRunning()) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onBackgroundTrackingStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  if (!await TrackingPrefs.isActive()) {
    await service.stopSelf();
    return;
  }

  var stopped = false;
  StreamSubscription<Position>? positionSubscription;
  Timer? watchdog;
  DateTime? lastFixAt;
  Map<String, dynamic>? lastAccepted;
  var pointCount = 0;
  var fixesSeen = 0;
  var handlingFix = false;

  final activeShift =
      await DatabaseHelper.instance.getActiveShift();
  if (activeShift == null) {
    await TrackingPrefs.setActive(false);
    await service.stopSelf();
    return;
  }
  final activeShiftId = activeShift['id'] as int;
  final savedLogs =
      await DatabaseHelper.instance.getLogsForShift(activeShiftId);
  final acceptedSavedLogs = RouteMetrics.acceptedLocationLogs(savedLogs);
  if (acceptedSavedLogs.isNotEmpty) {
    lastAccepted = acceptedSavedLogs.last;
    pointCount = acceptedSavedLogs.length;
    lastFixAt = DateTime.tryParse(
      acceptedSavedLogs.last['timestamp'] as String? ?? '',
    );
  }

  Future<void> showStatus(String body) async {
    if (service is! AndroidServiceInstance) return;
    await _notificationsPlugin.show(
      id: trackingNotificationId,
      title: 'Sales Tracker Active',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          trackingNotificationChannelId,
          'Sales Tracker',
          channelDescription:
              'Persistent notification while sales GPS tracking is active.',
          icon: 'ic_bg_service_small',
          ongoing: true,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  LocationSettings locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
        intervalDuration: const Duration(seconds: 8),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 8,
    );
  }

  Future<void> handlePosition(Position position) async {
    if (handlingFix) return;
    handlingFix = true;
    try {
      fixesSeen += 1;
      // The first fixes can be cached or noisy immediately after tracking
      // starts. Wait for the GPS chip to settle before saving any point.
      if (fixesSeen <= 2) return;

      final receivedAt = DateTime.now();
      final fixTime = position.timestamp.toLocal();
      if (receivedAt.difference(fixTime) > const Duration(seconds: 10)) {
        return;
      }

      final candidate = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': position.timestamp.toIso8601String(),
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
      };
      if (!RouteMetrics.isNextPointAcceptable(lastAccepted, candidate)) {
        return;
      }

      await DatabaseHelper.instance.insertLocationLog(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp.toIso8601String(),
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        battery: 100, // could add battery_plus later
        shiftId: activeShiftId,
      );

      lastAccepted = candidate;
      lastFixAt = receivedAt;
      pointCount += 1;

      service.invoke(locationUpdateMethod, candidate);
      await showStatus('Recording route · $pointCount points');
    } catch (error) {
      debugPrint('Failed to save location log: $error');
    } finally {
      handlingFix = false;
    }
  }

  late Future<void> Function() startListening;

  startListening = () async {
    if (stopped) return;
    await positionSubscription?.cancel();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings(),
    ).listen((Position position) {
      unawaited(handlePosition(position));
    }, onError: (Object error) {
      debugPrint('Background location stream error: $error');
      unawaited(showStatus('GPS paused — retrying (check airplane / GPS)'));
      // Do not stop the foreground service. Airplane mode and OEM
      // throttling often surface as stream errors; keep retrying.
      unawaited(Future<void>.delayed(const Duration(seconds: 8), () {
        if (!stopped) unawaited(startListening());
      }));
    }, onDone: () {
      if (!stopped) {
        unawaited(Future<void>.delayed(const Duration(seconds: 8), () {
          if (!stopped) unawaited(startListening());
        }));
      }
    }, cancelOnError: true);
  };

  Future<void> stop() async {
    stopped = true;
    watchdog?.cancel();
    await positionSubscription?.cancel();
    positionSubscription = null;
    await TrackingPrefs.setActive(false);
    await service.stopSelf();
  }

  service.on(_stopServiceMethod).listen((_) {
    unawaited(stop());
  });

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    await showStatus('Recording GPS locations');
  }

  await startListening();

  watchdog = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (stopped) return;

    // Auto-sync locations periodically during active shift
    try {
      await SyncService.syncLocationLogs();
    } catch (_) {}

    final last = lastFixAt;
    if (last == null) {
      unawaited(showStatus('Waiting for GPS fix…'));
      unawaited(startListening());
      return;
    }
    if (DateTime.now().difference(last) > const Duration(seconds: 60)) {
      unawaited(showStatus('GPS stalled — restarting listener'));
      unawaited(startListening());
    }
  });
}
