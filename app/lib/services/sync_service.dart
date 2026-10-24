import 'api_client.dart';
import '../database_helper.dart';

class SyncService {
  static Future<void> syncAll() async {
    await syncLocationLogs();
    // In a real app we'd also sync visits, but Visit model is complicated
    // since we need clientId, etc. For this mock, we just mark synced if visit ends.
  }

  static Future<void> syncLocationLogs() async {
    final unsynced = await DatabaseHelper.instance.getUnsyncedLocationLogs();
    if (unsynced.isEmpty) return;

    final List<Map<String, dynamic>> pings = unsynced.map((log) {
      return {
        'lat': log['latitude'],
        'lng': log['longitude'],
        'accuracyM': log['accuracy'] ?? 10.0,
        'speedMps': log['speed'] ?? 0.0,
        'battery': log['battery'] ?? 100,
        'recordedAt': log['timestamp'] + 'Z', // Need to ensure it's ISO UTC
      };
    }).toList();

    try {
      final result = await ApiClient.post('/locations/batch', body: {'pings': pings});
      if (result != null && result['accepted'] != null) {
        final ids = unsynced.map((e) => e['id'] as int).toList();
        await DatabaseHelper.instance.markLocationLogsSynced(ids);
      }
    } catch (e) {
      final ids = unsynced.map((e) => e['id'] as int).toList();
      await DatabaseHelper.instance.incrementLocationLogsRetry(ids);
    }
  }
}
