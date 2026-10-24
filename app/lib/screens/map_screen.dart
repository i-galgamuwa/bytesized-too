import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../background_tracking_service.dart';
import '../database_helper.dart';
import '../services/auth_service.dart';
import '../services/location_permissions.dart';
import '../services/map_config.dart';
import '../services/route_metrics.dart';
import '../theme/app_colors.dart';
import '../widgets/cream_button.dart';

import '../services/api_client.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _fallback = LatLng(6.047453, 80.201629);

  final MapController _mapController = MapController();
  final List<Map<String, dynamic>> _locationLogs = [];
  final List<LatLng> _route = [];
  final List<Map<String, dynamic>> _visits = [];

  StreamSubscription<Map<String, dynamic>?>? _serviceSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;

  LatLng _current = _fallback;
  DateTime? _shiftStart;
  int? _shiftId;
  Duration _elapsed = Duration.zero;
  bool _mapReady = false;
  bool _follow = true;
  bool _busy = false;
  bool _offlineTiles = false;
  bool _offlineMode = false;
  bool _stopping = false;
  bool _hasFix = false;
  double _heading = 0;
  String? _hint;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreShift());
    unawaited(_watchConnectivity());
    try {
      _serviceSub = FlutterBackgroundService()
          .on(locationUpdateMethod)
          .listen(_onServiceLocation);
    } catch (_) {
      // Service is not running in widget tests / desktop.
    }
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _restoreShift() async {
    try {
      final shift = await DatabaseHelper.instance.getActiveShift(
        driverId: widget.user.driverId,
      );
      if (shift != null) {
        _shiftId = shift['id'] as int?;
        _shiftStart = DateTime.tryParse(shift['start_time'] as String? ?? '');
      }

      if (_shiftId != null) {
        final logs = await DatabaseHelper.instance.getLogsForShift(_shiftId!);
        final visits = await DatabaseHelper.instance.getVisitsForShift(_shiftId!);
        final acceptedLogs = RouteMetrics.acceptedLocationLogs(logs);
        _locationLogs
          ..clear()
          ..addAll(logs);
        _route
          ..clear()
          ..addAll(RouteMetrics.routePointsFromLogs(logs));
        _visits
          ..clear()
          ..addAll(visits);
        if (_route.isNotEmpty) {
          _current = _route.last;
          _hasFix = true;
        }
        if (acceptedLogs.isNotEmpty) {
          _heading =
              (acceptedLogs.last['heading'] as num?)?.toDouble() ?? 0;
        }
      }
    } catch (error) {
      // Plugins are unavailable in widget tests.
      debugPrint('Could not restore saved route: $error');
    }

    if (_route.isEmpty) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        final age = last == null
            ? null
            : DateTime.now().difference(last.timestamp.toLocal());
        if (last != null &&
            last.accuracy <= RouteMetrics.maximumAccuracyMeters &&
            age != null &&
            !age.isNegative &&
            age <= Duration(seconds: 10)) {
          _current = LatLng(last.latitude, last.longitude);
          _heading = last.heading;
          _hasFix = true;
        }
      } catch (_) {}
    }

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _hint = LocationPermissions.permissionMessage(permission);
      } else if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          permission != LocationPermission.always) {
        _hint =
            'Allow location access all the time in app settings to resume background tracking.';
      } else if (!_hasFix) {
        _hint =
            'Waiting for a fresh GPS location. The route will appear once GPS is ready.';
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {});
    _moveIfFollowing();
  }

  Future<void> _watchConnectivity() async {
    final connectivity = Connectivity();
    try {
      _setConnectionState(await connectivity.checkConnectivity());
      _connectivitySub = connectivity.onConnectivityChanged.listen(
        _setConnectionState,
        onError: (_) => _setConnectionState(const [ConnectivityResult.none]),
      );
    } catch (_) {
      // The route and location marker work even when the plugin is not present.
    }
  }

  void _setConnectionState(List<ConnectivityResult> results) {
    if (!mounted) return;
    final offline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    setState(() {
      _offlineMode = offline || _offlineTiles;
      if (!offline) _offlineTiles = false;
    });
  }

  void _tick() {
    final start = _shiftStart;
    if (start == null || !mounted) return;
    setState(() => _elapsed = DateTime.now().difference(start));
  }

  void _onServiceLocation(Map<String, dynamic>? event) {
    if (event == null) return;
    final lat = (event['latitude'] as num?)?.toDouble();
    final lng = (event['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final point = <String, dynamic>{
      'latitude': lat,
      'longitude': lng,
      'timestamp': event['timestamp'] as String? ??
          DateTime.now().toIso8601String(),
      'accuracy': (event['accuracy'] as num?)?.toDouble(),
      'speed': (event['speed'] as num?)?.toDouble(),
      'heading': (event['heading'] as num?)?.toDouble(),
    };
    if (_locationLogs.any((row) => row['timestamp'] == point['timestamp'])) {
      return;
    }
    _locationLogs.add(point);
    final acceptedLogs = RouteMetrics.acceptedLocationLogs(_locationLogs);
    if (acceptedLogs.isEmpty) return;
    final latest = acceptedLogs.last;
    final next = LatLng(
      (latest['latitude'] as num).toDouble(),
      (latest['longitude'] as num).toDouble(),
    );
    setState(() {
      _hint = null;
      _hasFix = true;
      _current = next;
      _heading = (latest['heading'] as num?)?.toDouble() ?? _heading;
      _route
        ..clear()
        ..addAll(RouteMetrics.routePointsFromLogs(_locationLogs));
    });
    _moveIfFollowing();
  }

  void _moveIfFollowing() {
    if (!_follow || !_mapReady) return;
    try {
      _mapController.move(_current, _mapController.camera.zoom);
    } catch (_) {}
  }

  Future<void> _logVisit() async {
    if (_busy) return;
    if (!_hasFix) {
      setState(() => _hint = 'Wait for a GPS fix before logging a visit.');
      return;
    }

    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Log visit', style: TextStyle(color: context.colors.cream),
        ),
        content: TextField(
          controller: noteController,
          maxLength: 120,
          maxLines: 2,
          style: TextStyle(color: context.colors.cream),
          decoration: InputDecoration(
            hintText: 'Optional note',
            hintStyle: TextStyle(color: context.colors.muted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(''),
            child: Text('Skip note'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(noteController.text.trim()),
            child: Text('Save visit'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final loggedAt = DateTime.now().toIso8601String();
      final visitId = await DatabaseHelper.instance.insertVisit(
        driverId: widget.user.driverId,
        timestamp: loggedAt,
        latitude: _current.latitude,
        longitude: _current.longitude,
        shiftId: _shiftId,
        note: note.isEmpty ? null : note,
      );

      // Attempt backend check-in/out
      try {
        final visit = await ApiClient.post('/visits/start', body: {
          'clientId': 1, // Mock or fetch actual
          'lat': _current.latitude,
          'lng': _current.longitude,
          'accuracyM': 10.0,
        });

        if (visit != null) {
          final serverId = visit['id'];
          await ApiClient.post('/visits/$serverId/end', body: {
            'lat': _current.latitude,
            'lng': _current.longitude,
            'accuracyM': 10.0,
            'notes': note.isEmpty ? 'Visit logged from GPS tracker' : note,
          });
          await DatabaseHelper.instance.markVisitSynced(visitId);
        }
      } catch (e) {
        debugPrint('Failed backend visit log: $e');
        await DatabaseHelper.instance.incrementVisitRetry(visitId);
      }

      if (!mounted) return;
      setState(() {
        _visits.add({
          'latitude': _current.latitude,
          'longitude': _current.longitude,
          'timestamp': loggedAt,
          'note': note,
        });
        _busy = false;
        _hint = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visit logged')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _hint = 'Could not log visit: $error';
      });
    }
  }

  Future<void> _stopTracking() async {
    if (_stopping) return;
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Stop tracking?', style: TextStyle(color: context.colors.cream),
        ),
        content: Text(
          'This will end your current shift and stop GPS tracking.', style: TextStyle(color: context.colors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep tracking'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Stop tracking'),
          ),
        ],
      ),
    );
    if (shouldStop != true || !mounted) return;

    setState(() => _stopping = true);
    await stopBackgroundTracking();
    if (_shiftId != null) {
      await DatabaseHelper.instance.endShift(_shiftId!);
    } else {
      await DatabaseHelper.instance.endActiveShift(widget.user.driverId);
    }
    try {
      await ApiClient.post('/shifts/end');
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _serviceSub?.cancel();
    _connectivitySub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = RouteMetrics.distanceKmFromLogs(_locationLogs);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              backgroundColor: context.colors.background,
              initialCenter: _current,
              initialZoom: 16,
              onMapReady: () {
                _mapReady = true;
                _moveIfFollowing();
              },
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _follow) {
                  setState(() => _follow = false);
                }
              },
            ),
            children: [
              if (!_offlineMode && !_offlineTiles)
                TileLayer(
                  urlTemplate: LiveMapConfig.tileUrl,
                  subdomains: LiveMapConfig.tileSubdomains,
                  userAgentPackageName:
                      LiveMapConfig.userAgentPackageName,
                  errorTileCallback: (tile, error, stackTrace) {
                    if (!_offlineTiles && mounted) {
                      setState(() {
                        _offlineTiles = true;
                        _offlineMode = true;
                      });
                    }
                  },
                ),
              if (!_offlineMode && !_offlineTiles)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: const [
                        LatLng(-85, -180),
                        LatLng(-85, 180),
                        LatLng(85, 180),
                        LatLng(85, -180),
                      ],
                      color: LiveMapConfig.mapTint,
                      borderStrokeWidth: 0,
                    ),
                  ],
                ),
              PolylineLayer(
                polylines: [
                  // The broad line underneath makes the route stand out on
                  // dark street tiles without changing the white route color.
                  Polyline(
                    points: _route,
                    color: LiveMapConfig.routeGlowColor,
                    strokeWidth: LiveMapConfig.routeGlowWidth.toDouble(),
                  ),
                  Polyline(
                    points: _route,
                    color: LiveMapConfig.routeColor,
                    strokeWidth: LiveMapConfig.routeWidth,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final visit in _visits)
                    if (visit['latitude'] is num &&
                        visit['longitude'] is num)
                      Marker(
                        point: LatLng(
                          (visit['latitude'] as num).toDouble(),
                          (visit['longitude'] as num).toDouble(),
                        ),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showVisitNote(visit),
                          child: Icon(
                            Icons.location_on, color: context.colors.gold,
                            size: 34,
                          ),
                        ),
                      ),
                  if (_hasFix)
                    Marker(
                      point: _current,
                      width: 52,
                      height: 52,
                      child: Transform.rotate(
                        angle: _heading * math.pi / 180,
                        child: Icon(
                          Icons.directions_car_filled, color: context.colors.cream,
                          size: 38,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    '© OpenStreetMap contributors © CARTO',
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_offlineMode || _offlineTiles)
                        const _HudChip(
                          icon: Icons.wifi_off,
                          label: 'Offline mode',
                        ),
                      Spacer(),
                      IconButton(
                        tooltip: 'Close map',
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: IconButton.styleFrom(
                          backgroundColor: context.colors.card.withValues(alpha: 0.94),
                          foregroundColor: context.colors.cream,
                        ),
                        icon: Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (_hint != null) ...[
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.card.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _hint!,
                        style: TextStyle(color: context.colors.cream),
                      ),
                    ),
                  ],
                  Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FloatingActionButton.small(
                      heroTag: 'follow_me',
                      backgroundColor:
                          _follow ? context.colors.gold : context.colors.card,
                      foregroundColor:
                          _follow ? context.colors.buttonText : context.colors.cream,
                      onPressed: !_hasFix
                          ? null
                          : () {
                              setState(() => _follow = true);
                              _moveIfFollowing();
                            },
                      child: Icon(Icons.my_location),
                    ),
                  ),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '© OpenStreetMap contributors © CARTO',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'TIME',
                          value: RouteMetrics.formatElapsed(_elapsed),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          label: 'DISTANCE',
                          value: '${distanceKm.toStringAsFixed(2)} km',
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        height: 62,
                        child: ElevatedButton(
                          onPressed: _busy || _stopping ? null : _logVisit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.cream,
                            foregroundColor: context.colors.buttonText,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, size: 20),
                              Text(
                                'Log Visit',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CreamButton(
                      label: 'Stop Tracking',
                      busy: _stopping,
                      onPressed: _stopTracking,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVisitNote(Map<String, dynamic> visit) async {
    final note = (visit['note'] as String?)?.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text(
          'Visit', style: TextStyle(color: context.colors.cream),
        ),
        content: Text(
          note == null || note.isEmpty ? 'No note was added.' : note,
          style: TextStyle(color: context.colors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: context.colors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: context.colors.cream,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.label,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, color: context.colors.gold, size: 18),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: context.colors.cream,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
