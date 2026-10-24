import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../database_helper.dart';
import '../services/map_config.dart';
import '../services/route_metrics.dart';
import '../services/stats_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';

class ShiftDetailScreen extends StatelessWidget {
  const ShiftDetailScreen({super.key, required this.shift});

  final ShiftSummary shift;

  String _duration(Duration d) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy');
    final timeFormat = DateFormat('HH:mm');

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: context.colors.cream,
          title: Text('Shift details'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _row(context, 'Date', dateFormat.format(shift.startTime)),
            _row(context, 'Start', timeFormat.format(shift.startTime)),
            _row(context, 'End',
              shift.endTime == null
                  ? 'In progress'
                  : timeFormat.format(shift.endTime!),
            ),
            _row(context, 'Duration', _duration(shift.duration)),
            _row(context, 'Distance', '${shift.distanceKm.toStringAsFixed(2)} km'),
            _row(context, 'Driver ID', shift.driverId),
            SizedBox(height: 8),
            Text(
              'Route and visits',
              style: TextStyle(
                color: context.colors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10),
            _ShiftRoutePreview(shiftId: shift.id),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: context.colors.muted)),
          Spacer(),
          Text(value, style: TextStyle(color: context.colors.cream)),
        ],
      ),
    );
  }
}

/// Loads saved points and visits for a shift, then shows a read-only map.
class _ShiftRoutePreview extends StatefulWidget {
  const _ShiftRoutePreview({required this.shiftId});

  final int shiftId;

  @override
  State<_ShiftRoutePreview> createState() => _ShiftRoutePreviewState();
}

class _ShiftRoutePreviewState extends State<_ShiftRoutePreview> {
  late Future<({List<Map<String, dynamic>> logs, List<Map<String, dynamic>> visits})>
      _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _loadRoute();
  }

  Future<({List<Map<String, dynamic>> logs, List<Map<String, dynamic>> visits})>
      _loadRoute() async {
    final database = DatabaseHelper.instance;
    return (
      logs: await database.getLogsForShift(widget.shiftId),
      visits: await database.getVisitsForShift(widget.shiftId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        ({List<Map<String, dynamic>> logs, List<Map<String, dynamic>> visits})>(
      future: _routeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(color: context.colors.cream),
            ),
          );
        }
        if (snapshot.hasError) {
          return const _RouteMessage('Could not load this saved route.');
        }

        final data = snapshot.data!;
        final points = RouteMetrics.routePointsFromLogs(data.logs);
        if (points.isEmpty) {
          return const _RouteMessage('No location points were saved for this shift.');
        }
        final hasSpread = points.any(
          (point) =>
              point.latitude != points.first.latitude ||
              point.longitude != points.first.longitude,
        );
        final bounds = hasSpread
            ? LatLngBounds.fromPoints(points)
            : null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                backgroundColor: context.colors.background,
                initialCenter: points.first,
                initialZoom: 15,
                initialCameraFit: bounds == null
                    ? null
                    : CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(24),
                      ),
              ),
              children: [
                TileLayer(
                  urlTemplate: LiveMapConfig.tileUrl,
                  subdomains: LiveMapConfig.tileSubdomains,
                  userAgentPackageName:
                      LiveMapConfig.userAgentPackageName,
                ),
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
                    Polyline(
                      points: points,
                      color: LiveMapConfig.routeGlowColor,
                      strokeWidth: LiveMapConfig.routeGlowWidth.toDouble(),
                    ),
                    Polyline(
                      points: points,
                      color: LiveMapConfig.routeColor,
                      strokeWidth: LiveMapConfig.routeWidth,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final visit in data.visits)
                      if (visit['latitude'] is num &&
                          visit['longitude'] is num)
                        Marker(
                          point: LatLng(
                            (visit['latitude'] as num).toDouble(),
                            (visit['longitude'] as num).toDouble(),
                          ),
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.location_on,
                            color: context.colors.gold,
                            size: 32,
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
          ),
        );
      },
    );
  }
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: context.colors.muted),
      ),
    );
  }
}
