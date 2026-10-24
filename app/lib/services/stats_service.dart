import '../database_helper.dart';
import 'route_metrics.dart';

/// Numbers shown on Performance, built from SQLite (not fake demo data).
class PerformanceStats {
  PerformanceStats({
    required this.totalShifts,
    required this.totalDistanceKm,
    required this.hoursActive,
    required this.visitCount,
    required this.dailyDistanceKm,
    required this.dailyDates,
    required this.dailyVisits,
    required this.weeklyDistanceKm,
    required this.weeklyVisits,
    required this.weeklyShifts,
    required this.weeklyHoursActive,
  });

  final int totalShifts;
  final double totalDistanceKm;
  final double hoursActive;
  final int visitCount;
  final List<double> dailyDistanceKm; // last 7 days, oldest first
  final List<DateTime> dailyDates; // matching local dates, oldest first
  final List<int> dailyVisits;
  final double weeklyDistanceKm;
  final int weeklyVisits;
  final int weeklyShifts;
  final double weeklyHoursActive;
}

class ShiftSummary {
  ShiftSummary({
    required this.id,
    required this.driverId,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
  });

  final int id;
  final String driverId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
}

class StatsService {
  /// Uses the shared GPS filters so every screen reports the same distance.
  double distanceKmFromLogs(List<Map<String, dynamic>> logs) {
    return RouteMetrics.distanceKmFromLogs(logs);
  }

  Future<List<ShiftSummary>> loadShifts(String driverId) async {
    final rows = await DatabaseHelper.instance.getShiftsForDriver(driverId);
    final summaries = <ShiftSummary>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final logs = await DatabaseHelper.instance.getLogsForShift(id);
      summaries.add(
        ShiftSummary(
          id: id,
          driverId: row['driver_id'] as String,
          startTime: DateTime.parse(row['start_time'] as String),
          endTime: row['end_time'] == null
              ? null
              : DateTime.tryParse(row['end_time'] as String),
          distanceKm: distanceKmFromLogs(logs),
        ),
      );
    }
    return summaries;
  }

  Future<PerformanceStats> loadPerformance(String driverId) async {
    final shifts = await loadShifts(driverId);
    final allLogs = await DatabaseHelper.instance.getLogsForDriver(driverId);
    final visitCount = await DatabaseHelper.instance.getVisitCount(driverId);
    final visits = await DatabaseHelper.instance.getVisitsForDriver(driverId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: 6));
    final weekEnd = today.add(Duration(days: 1));
    final days = List<DateTime>.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    final logsByShift = <int, List<Map<String, dynamic>>>{};
    for (final row in allLogs) {
      final shiftId = (row['shift_id'] as num?)?.toInt();
      if (shiftId == null) continue;
      logsByShift.putIfAbsent(shiftId, () => []).add(row);
    }
    final daily = RouteMetrics.distanceKmByDay(
      logsByShift.values,
      weekStart,
    );

    final dailyVisitCounts = List<int>.filled(7, 0);
    for (final visit in visits) {
      final timestamp =
          DateTime.tryParse(visit['timestamp'] as String? ?? '')?.toLocal();
      if (timestamp == null) continue;
      final visitDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
      final index = DateTime.utc(visitDay.year, visitDay.month, visitDay.day)
          .difference(DateTime.utc(weekStart.year, weekStart.month, weekStart.day))
          .inDays;
      if (index >= 0 && index < dailyVisitCounts.length) {
        dailyVisitCounts[index] += 1;
      }
    }

    var weeklyHours = 0.0;
    var weeklyShiftCount = 0;
    for (final shift in shifts) {
      if (!shift.startTime.isBefore(weekStart) &&
          shift.startTime.isBefore(weekEnd)) {
        weeklyShiftCount += 1;
      }
      final shiftEnd = shift.endTime ?? now;
      final overlapStart =
          shift.startTime.isAfter(weekStart) ? shift.startTime : weekStart;
      final overlapEnd = shiftEnd.isBefore(weekEnd) ? shiftEnd : weekEnd;
      if (overlapEnd.isAfter(overlapStart)) {
        weeklyHours += overlapEnd.difference(overlapStart).inSeconds / 3600;
      }
    }

    final weeklyVisits = dailyVisitCounts.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    final weeklyDistance =
        daily.fold<double>(0, (sum, km) => sum + km);

    return PerformanceStats(
      totalShifts: shifts.length,
      // This card is intentionally the same last-seven-days window as the
      // weekly summary and the daily chart, not lifetime distance.
      totalDistanceKm: weeklyDistance,
      hoursActive: weeklyHours,
      visitCount: visitCount,
      dailyDistanceKm: daily,
      dailyDates: days,
      dailyVisits: dailyVisitCounts,
      weeklyDistanceKm: weeklyDistance,
      weeklyVisits: weeklyVisits,
      weeklyShifts: weeklyShiftCount,
      weeklyHoursActive: weeklyHours,
    );
  }
}
