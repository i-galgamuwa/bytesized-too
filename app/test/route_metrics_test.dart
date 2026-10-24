import 'package:app/services/route_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _point(
  double latitude,
  double longitude,
  String timestamp, {
  double accuracy = 5,
}) {
  return {
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp,
    'accuracy': accuracy,
  };
}

void main() {
  test('formatElapsed pads hours, minutes, and seconds', () {
    expect(RouteMetrics.formatElapsed(Duration.zero), '00:00:00');
    expect(
      RouteMetrics.formatElapsed(
        const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
      '01:02:03',
    );
    expect(
      RouteMetrics.formatElapsed(const Duration(seconds: -5)),
      '00:00:00',
    );
  });

  test('accuracy above 25 meters is ignored', () {
    final logs = [
      _point(6.9271, 79.8612, '2026-10-24T08:00:00', accuracy: 26),
      _point(6.9272, 79.8612, '2026-10-24T08:00:08'),
    ];

    expect(RouteMetrics.acceptedLocationLogs(logs), hasLength(1));
    expect(RouteMetrics.distanceKmFromLogs(logs), 0);
  });

  test('an implied speed above 60 m/s drops the jump point', () {
    final logs = [
      _point(0, 0, '2026-10-24T08:00:00'),
      _point(0.02, 0, '2026-10-24T08:00:08'),
      _point(0.0002, 0, '2026-10-24T08:00:16'),
    ];

    final accepted = RouteMetrics.acceptedLocationLogs(logs);
    expect(accepted, hasLength(2));
    expect(accepted.last['latitude'], 0.0002);
  });

  test('short stationary movement does not add distance', () {
    final logs = [
      _point(0, 0, '2026-10-24T08:00:00', accuracy: 5),
      // About 5.5 m away: below the shared 10 m minimum.
      _point(0.00005, 0, '2026-10-24T08:00:08', accuracy: 5),
    ];

    expect(RouteMetrics.acceptedLocationLogs(logs), hasLength(2));
    expect(RouteMetrics.distanceKmFromLogs(logs), 0);
  });

  test('distance uses only accepted segments above the accuracy threshold', () {
    final logs = [
      _point(0, 0, '2026-10-24T08:00:00'),
      _point(0.00005, 0, '2026-10-24T08:00:08'),
      _point(0.0015, 0, '2026-10-24T08:00:16'),
    ];

    final distance = RouteMetrics.distanceKmFromLogs(logs);
    expect(distance, greaterThan(0.1));
    expect(distance, lessThan(0.2));
  });

  test('daily distance starts on the requested date and includes empty days', () {
    final logs = [
      _point(0, 0, '2026-10-22T08:00:00'),
      _point(0.001, 0, '2026-10-22T08:01:00'),
    ];

    final daily = RouteMetrics.distanceKmByDay([logs], DateTime(2026, 10, 20));
    expect(daily, hasLength(7));
    expect(daily[0], 0);
    expect(daily[2], greaterThan(0.1));
    expect(daily[6], 0);
  });
}
