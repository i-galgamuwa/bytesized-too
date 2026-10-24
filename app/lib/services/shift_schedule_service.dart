import 'api_client.dart';

class ScheduledShift {
  ScheduledShift({
    required this.title,
    required this.start,
    required this.end,
    this.isSample = false,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool isSample;
}

class ShiftScheduleService {
  Future<List<ScheduledShift>> getUpcomingShifts() async {
    try {
      final List<dynamic> jsonList = await ApiClient.get('/assignments/mine');
      return jsonList.map((json) {
        final dateStr = json['scheduledDate'] as String;
        final timeStr = json['scheduledTime'] as String; // e.g. "10:00:00"

        final start = DateTime.parse('${dateStr}T$timeStr');
        final end = start.add(Duration(hours: 1)); // Assuming 1 hour per visit

        return ScheduledShift(
          title: '${json['clientName']} - ${json['note'] ?? 'Visit'}',
          start: start,
          end: end,
          isSample: false,
        );
      }).toList().cast<ScheduledShift>();
    } catch (e) {
      // Fallback to sample if offline or error
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day).add(
        Duration(days: 1, hours: 8),
      );
      return [
        ScheduledShift(
          title: 'OFFLINE · Morning route',
          start: tomorrow,
          end: tomorrow.add(Duration(hours: 8)),
          isSample: true,
        ),
      ];
    }
  }
}

