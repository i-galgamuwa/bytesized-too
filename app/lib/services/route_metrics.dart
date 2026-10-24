import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Shared rules for cleaning GPS points before showing or measuring a route.
class RouteMetrics {
  const RouteMetrics._();

  static const double maximumAccuracyMeters = 25;
  static const double maximumImpliedSpeedMetersPerSecond = 60;
  static const double minimumDistanceMeters = 10;

  static String formatElapsed(Duration elapsed) {
    final safe = elapsed.isNegative ? Duration.zero : elapsed;
    final hours = safe.inHours.toString().padLeft(2, '0');
    final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Returns valid route points in time order, ignoring inaccurate fixes and
  /// impossible jumps. Old rows with no accuracy value are kept for history.
  static List<Map<String, dynamic>> acceptedLocationLogs(
    Iterable<Map<String, dynamic>> logs,
  ) {
    final ordered = logs.toList()
      ..sort((a, b) {
        final first = _timestamp(a);
        final second = _timestamp(b);
        if (first == null || second == null) {
          return ((a['id'] as num?)?.toInt() ?? 0)
              .compareTo((b['id'] as num?)?.toInt() ?? 0);
        }
        return first.compareTo(second);
      });

    final accepted = <Map<String, dynamic>>[];
    for (final point in ordered) {
      if (!_hasValidCoordinates(point) || !_hasGoodAccuracy(point)) continue;
      if (accepted.isNotEmpty &&
          !isNextPointAcceptable(accepted.last, point)) {
        continue;
      }
      accepted.add(point);
    }
    return accepted;
  }

  /// The background service uses this before saving each new point.
  static bool isNextPointAcceptable(
    Map<String, dynamic>? previousAccepted,
    Map<String, dynamic> candidate,
  ) {
    if (!_hasValidCoordinates(candidate) || !_hasGoodAccuracy(candidate)) {
      return false;
    }
    if (previousAccepted == null) return true;

    final metres = distanceMetersBetween(previousAccepted, candidate);
    final previousTime = _timestamp(previousAccepted);
    final currentTime = _timestamp(candidate);
    if (previousTime == null || currentTime == null) return false;

    final seconds = currentTime.difference(previousTime).inMilliseconds / 1000;
    if (seconds <= 0) {
      // A stationary duplicate is harmless; movement without elapsed time
      // cannot produce a trustworthy speed calculation.
      return metres == 0;
    }
    return metres / seconds <= maximumImpliedSpeedMetersPerSecond;
  }

  /// Computes distance after applying the same accuracy and jump rules used
  /// by the live map. Small movements at or below the GPS noise threshold
  /// remain visible as fixes but do not add distance.
  static double distanceKmFromLogs(List<Map<String, dynamic>> logs) {
    final accepted = acceptedLocationLogs(logs);
    var metres = 0.0;
    for (var i = 1; i < accepted.length; i++) {
      final segment = distanceMetersBetween(accepted[i - 1], accepted[i]);
      if (segment > _movementThresholdMeters(accepted[i])) {
        metres += segment;
      }
    }
    return metres / 1000;
  }

  /// Splits route distance by the local day of each segment's ending point.
  /// The caller supplies one log list per shift to avoid joining shifts.
  static List<double> distanceKmByDay(
    Iterable<List<Map<String, dynamic>>> shiftLogs,
    DateTime firstDay, {
    int dayCount = 7,
  }) {
    final daily = List<double>.filled(dayCount, 0);
    final start = DateTime(firstDay.year, firstDay.month, firstDay.day);
    for (final logs in shiftLogs) {
      final accepted = acceptedLocationLogs(logs);
      for (var i = 1; i < accepted.length; i++) {
        final point = accepted[i];
        final timestamp = _timestamp(point)?.toLocal();
        if (timestamp == null) continue;
        final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
        final dayIndex = DateTime.utc(day.year, day.month, day.day)
            .difference(DateTime.utc(start.year, start.month, start.day))
            .inDays;
        if (dayIndex < 0 || dayIndex >= dayCount) continue;

        final segment = distanceMetersBetween(accepted[i - 1], point);
        if (segment > _movementThresholdMeters(point)) {
          daily[dayIndex] += segment / 1000;
        }
      }
    }
    return daily;
  }

  static List<LatLng> routePointsFromLogs(
    List<Map<String, dynamic>> logs,
  ) {
    return acceptedLocationLogs(logs).map((row) {
      return LatLng(
        (row['latitude'] as num).toDouble(),
        (row['longitude'] as num).toDouble(),
      );
    }).toList();
  }

  static double distanceMetersBetween(
    Map<String, dynamic> from,
    Map<String, dynamic> to,
  ) {
    return Geolocator.distanceBetween(
      (from['latitude'] as num).toDouble(),
      (from['longitude'] as num).toDouble(),
      (to['latitude'] as num).toDouble(),
      (to['longitude'] as num).toDouble(),
    );
  }

  static double _movementThresholdMeters(Map<String, dynamic> point) {
    final accuracy = (point['accuracy'] as num?)?.toDouble() ?? 0;
    return accuracy > minimumDistanceMeters
        ? accuracy
        : minimumDistanceMeters;
  }

  static bool _hasGoodAccuracy(Map<String, dynamic> point) {
    final accuracy = (point['accuracy'] as num?)?.toDouble();
    return accuracy == null || accuracy <= maximumAccuracyMeters;
  }

  static bool _hasValidCoordinates(Map<String, dynamic> point) {
    return point['latitude'] is num && point['longitude'] is num;
  }

  static DateTime? _timestamp(Map<String, dynamic> point) {
    return DateTime.tryParse(point['timestamp'] as String? ?? '');
  }
}
