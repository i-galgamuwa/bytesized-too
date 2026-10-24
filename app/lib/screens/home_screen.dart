import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../background_tracking_service.dart';
import '../database_helper.dart';
import '../services/auth_service.dart';
import '../services/location_permissions.dart';
import '../services/power_settings.dart';
import '../services/tracking_prefs.dart';
import '../theme/app_colors.dart';
import '../widgets/cream_button.dart';
import 'map_screen.dart';

import '../services/api_client.dart';
import '../services/sync_service.dart';

/// Main screen after login: greeting, status, and Start Tracking / live map.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onOpenDrawer,
  });

  final AuthUser user;
  final VoidCallback onOpenDrawer;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _permissions = LocationPermissions();

  bool _tracking = false;
  bool _isBusy = false;
  String? _statusHint;
  String? _city;
  int _todayVisits = 0;
  int _pendingSync = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_syncTrackingState());
    unawaited(_loadCity());
    unawaited(_loadTodayVisits());
    unawaited(_loadPendingSync());
  }

  Future<void> _loadPendingSync() async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedLocationLogs();
    if (!mounted) return;
    setState(() => _pendingSync = unsynced.length);
  }

  Future<void> _syncNow() async {
    setState(() => _isBusy = true);
    await SyncService.syncAll();
    await _loadPendingSync();
    setState(() => _isBusy = false);
  }

  Future<void> _loadTodayVisits() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final count = await DatabaseHelper.instance.getVisitCount(
      widget.user.driverId,
      since: start,
      until: start.add(Duration(days: 1)),
    );
    if (!mounted) return;
    setState(() => _todayVisits = count);
  }

  Future<void> _syncTrackingState() async {
    final running = await FlutterBackgroundService().isRunning();
    final activeShift = await DatabaseHelper.instance.getActiveShift(
      driverId: widget.user.driverId,
    );
    if (!mounted) return;
    setState(() => _tracking = running || activeShift != null);
  }

  /// Reverse-geocode the current GPS point. Stay blank if it fails.
  Future<void> _loadCity() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      var position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isEmpty || !mounted) return;
      final place = places.first;
      final city = place.locality?.trim();
      if (city == null || city.isEmpty) return;
      setState(() => _city = city);
    } catch (_) {
      // No internet, no GPS, or geocoding failed: show nothing.
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _toggleTracking() async {
    if (_isBusy) return;
    if (_tracking) {
      await _openMap();
    } else {
      await _startTracking();
    }
  }

  Future<void> _openMap() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => MapScreen(user: widget.user),
      ),
    );
    if (!mounted) return;
    await _syncTrackingState();
    await _loadTodayVisits();
  }

  Future<void> _startTracking() async {
    final hasConsent = await TrackingPrefs.hasConsent();
    if (!hasConsent) {
      if (!mounted) return;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Location & Privacy Consent'),
          content: Text(
            'We track your GPS route and client check-ins strictly during your active shift to verify routes and ensure safety. '
            'Tracking completely stops when you end your shift or log out.\n\n'
            'All data is secured and transmitted over HTTPS.\n\n'
            'Do you consent to this tracking?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('I Consent'),
            ),
          ],
        ),
      );
      if (agreed != true) return;
      await TrackingPrefs.setConsentGiven(true);
    }

    setState(() {
      _isBusy = true;
      _statusHint = 'Checking location permissions...';
    });

    final permission = await _permissions.checkAndRequest();
    if (!mounted) return;

    if (!permission.allowed) {
      setState(() {
        _isBusy = false;
        _statusHint = permission.message;
      });
      return;
    }

    try {
      // Create a shift locally
      await DatabaseHelper.instance.startShift(widget.user.driverId);
      // Start shift on the real backend
      try {
        await ApiClient.post('/shifts/start');
      } catch (e) {
        debugPrint('Failed to start shift on backend: $e');
        // We still allow local tracking, backend will catch up or we will sync later
      }

      if (!await TrackingPrefs.hasAskedBatteryOptimization()) {
        await PowerSettings.requestIgnoreBatteryOptimizations();
        await TrackingPrefs.markBatteryOptimizationAsked();
      }
      await startBackgroundTracking();
      if (!mounted) return;
      setState(() {
        _tracking = true;
        _isBusy = false;
        _statusHint = null;
      });
      unawaited(_loadCity());
      await _openMap();
    } catch (error) {
      await DatabaseHelper.instance.endActiveShift(widget.user.driverId);
      if (!mounted) return;
      setState(() {
        _tracking = false;
        _isBusy = false;
        _statusHint = 'Failed to start tracking: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _tracking ? 'Tracking' : 'Waiting';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onOpenDrawer,
                icon: Icon(Icons.menu, color: context.colors.cream),
              ),
              Spacer(),
              if (_city != null) ...[
                Icon(Icons.location_on, color: context.colors.gold, size: 18),
                SizedBox(width: 4),
                Text(_city!, style: TextStyle(color: context.colors.muted)),
              ],
            ],
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: TextStyle(color: context.colors.gold,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.user.name,
                  style: TextStyle(color: context.colors.cream,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 28),
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.cardHighlight.withValues(alpha: 0.6),
              ),
              child: Icon(
                Icons.directions_car_filled,
                size: 72,
                color: context.colors.cream,
              ),
            ),
          ),
          SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "Today's visits", style: TextStyle(color: context.colors.muted),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '$_todayVisits',
                        style: TextStyle(color: context.colors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: context.colors.cardHighlight,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Status', style: TextStyle(color: context.colors.muted),
                      ),
                      SizedBox(height: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(color: context.colors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_pendingSync > 0 && !_tracking) ...[
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_problem, color: context.colors.gold, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_pendingSync unsynced records',
                      style: TextStyle(color: context.colors.cream),
                    ),
                  ),
                  TextButton(
                    onPressed: _isBusy ? null : _syncNow,
                    child: Text('Sync Now', style: TextStyle(color: context.colors.gold)),
                  ),
                ],
              ),
            ),
          ],
          if (_statusHint != null) ...[
            SizedBox(height: 16),
            Text(
              _statusHint!,
              style: TextStyle(color: context.colors.error),
            ),
          ],
          Spacer(),
          CreamButton(
            label: _tracking ? 'View live map' : 'Start Tracking',
            busy: _isBusy,
            onPressed: _toggleTracking,
          ),
        ],
      ),
    );
  }
}
