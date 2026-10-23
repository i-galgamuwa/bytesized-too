import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'services/route_metrics.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _uuid = Uuid();

  static const _databaseName = 'gps_sales_tracker.db';
  static const _databaseVersion = 6;
  static const tableLocationLogs = 'location_logs';
  static const tableShifts = 'shifts';
  static const tableVisits = 'visits';

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    // Preserve the path used by existing installs. Correcting the path itself
    // needs a separate file migration or saved offline data could be hidden.
    final path = '\${documentsDirectory.path}/\$_databaseName';

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createShiftsTable(db);
    await _createVisitsTable(db);
    await _createLocationLogsTable(db);
  }

  Future<void> _createShiftsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableShifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        driver_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT
      )
    ''');
  }

  Future<void> _createVisitsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableVisits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        driver_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        shift_id INTEGER,
        note TEXT,
        is_synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _createLocationLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableLocationLogs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        shift_id INTEGER,
        accuracy REAL,
        speed REAL,
        heading REAL,
        battery INTEGER,
        is_synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createShiftsTable(db);
      await db.execute('ALTER TABLE $tableLocationLogs ADD COLUMN shift_id INTEGER');
    }
    if (oldVersion < 3) {
      await _createVisitsTable(db);
    }
    if (oldVersion < 4) {
      final info = await db.rawQuery('PRAGMA table_info($tableVisits)');
      if (info.isEmpty) {
        await _createVisitsTable(db);
      } else {
        await _addColumnIfMissing(db, tableVisits, 'latitude', 'REAL');
        await _addColumnIfMissing(db, tableVisits, 'longitude', 'REAL');
        await _addColumnIfMissing(db, tableVisits, 'shift_id', 'INTEGER');
      }
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, tableLocationLogs, 'client_id', 'TEXT DEFAULT ""');
      await _addColumnIfMissing(db, tableLocationLogs, 'is_synced', 'INTEGER DEFAULT 0');
      await _addColumnIfMissing(db, tableLocationLogs, 'retry_count', 'INTEGER DEFAULT 0');
      await _addColumnIfMissing(db, tableLocationLogs, 'accuracy', 'REAL');
      await _addColumnIfMissing(db, tableLocationLogs, 'speed', 'REAL');
      await _addColumnIfMissing(db, tableLocationLogs, 'battery', 'INTEGER');

      await _addColumnIfMissing(db, tableVisits, 'client_id', 'TEXT DEFAULT ""');
      await _addColumnIfMissing(db, tableVisits, 'is_synced', 'INTEGER DEFAULT 0');
      await _addColumnIfMissing(db, tableVisits, 'retry_count', 'INTEGER DEFAULT 0');
    }
    if (oldVersion < 6) {
      // Additive columns preserve every route and visit already on the device.
      await _addColumnIfMissing(db, tableLocationLogs, 'heading', 'REAL');
      await _addColumnIfMissing(db, tableVisits, 'note', 'TEXT');
    }
  }

  Future<void> _addColumnIfMissing(Database db, String table, String column, String type) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<int> startShift(String driverId) async {
    final db = await database;
    return db.insert(tableShifts, {
      'driver_id': driverId,
      'start_time': DateTime.now().toIso8601String(),
      'end_time': null,
    });
  }

  Future<void> endActiveShift(String driverId) async {
    final db = await database;
    final openShifts = await db.query(
      tableShifts,
      where: 'driver_id = ? AND end_time IS NULL',
      whereArgs: [driverId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (openShifts.isEmpty) return;
    await endShift(openShifts.first['id'] as int);
  }

  /// Ends a shift, removing accidental starts shorter than 15 seconds when
  /// they never recorded an accepted location point.
  Future<void> endShift(int shiftId) async {
    final db = await database;
    await db.transaction((txn) async {
      final shifts = await txn.query(
        tableShifts,
        where: 'id = ?',
        whereArgs: [shiftId],
        limit: 1,
      );
      if (shifts.isEmpty) return;

      final shift = shifts.first;
      final startedAt = DateTime.tryParse(shift['start_time'] as String? ?? '');
      final endedAt = DateTime.now();
      final logs = await txn.query(
        tableLocationLogs,
        where: 'shift_id = ?',
        whereArgs: [shiftId],
        orderBy: 'id ASC',
      );
      final hasAcceptedPoints =
          RouteMetrics.acceptedLocationLogs(logs).isNotEmpty;
      final isShortEmptyShift = startedAt != null &&
          endedAt.difference(startedAt) <= const Duration(seconds: 15) &&
          !hasAcceptedPoints;

      if (isShortEmptyShift) {
        await txn.delete(
          tableLocationLogs,
          where: 'shift_id = ?',
          whereArgs: [shiftId],
        );
        // A manually logged visit is still valuable even if its shift was an
        // accidental short start, so keep it and clear the removed link.
        await txn.update(
          tableVisits,
          {'shift_id': null},
          where: 'shift_id = ?',
          whereArgs: [shiftId],
        );
        await txn.delete(tableShifts, where: 'id = ?', whereArgs: [shiftId]);
        return;
      }

      await txn.update(
        tableShifts,
        {'end_time': endedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [shiftId],
      );
    });
  }

  Future<Map<String, dynamic>?> getActiveShift({String? driverId}) async {
    final db = await database;
    final rows = driverId == null
        ? await db.query(tableShifts, where: 'end_time IS NULL', orderBy: 'id DESC', limit: 1)
        : await db.query(tableShifts, where: 'driver_id = ? AND end_time IS NULL', whereArgs: [driverId], orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int?> getActiveShiftId() async {
    final db = await database;
    final rows = await db.query(tableShifts, columns: ['id'], where: 'end_time IS NULL', orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  Future<int> insertLocationLog({
    required double latitude,
    required double longitude,
    required String timestamp,
    double? accuracy,
    double? speed,
    double? heading,
    int? battery,
    int? shiftId,
  }) async {
    final db = await database;
    final resolvedShiftId = shiftId ?? await getActiveShiftId();
    return db.insert(tableLocationLogs, {
      'client_id': _uuid.v4(),
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'shift_id': resolvedShiftId,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'battery': battery,
      'is_synced': 0,
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLocationLogs() async {
    final db = await database;
    return db.query(tableLocationLogs, where: 'is_synced = 0', orderBy: 'id ASC', limit: 500);
  }

  Future<void> markLocationLogsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update(
      tableLocationLogs,
      {'is_synced': 1},
      where: 'id IN (${ids.join(",")})',
    );
  }

  Future<void> incrementLocationLogsRetry(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.rawUpdate('UPDATE $tableLocationLogs SET retry_count = retry_count + 1 WHERE id IN (${ids.join(",")})');
  }

  Future<List<Map<String, dynamic>>> getAllLocationLogs() async {
    final db = await database;
    return db.query(tableLocationLogs, orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> getShiftsForDriver(String driverId) async {
    final db = await database;
    return db.query(tableShifts, where: 'driver_id = ?', whereArgs: [driverId], orderBy: 'start_time DESC');
  }

  Future<List<Map<String, dynamic>>> getLogsForShift(int shiftId) async {
    final db = await database;
    return db.query(tableLocationLogs, where: 'shift_id = ?', whereArgs: [shiftId], orderBy: 'id ASC');
  }

  Future<List<Map<String, dynamic>>> getLogsForDriver(String driverId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT l.latitude, l.longitude, l.timestamp, l.shift_id,
             l.accuracy, l.speed, l.heading
      FROM $tableLocationLogs l
      INNER JOIN $tableShifts s ON s.id = l.shift_id
      WHERE s.driver_id = ?
      ORDER BY l.id ASC
    ''', [driverId]);
  }

  Future<int> insertVisit({
    required String driverId,
    required String timestamp,
    double? latitude,
    double? longitude,
    int? shiftId,
    String? note,
  }) async {
    final db = await database;
    final resolvedShiftId = shiftId ?? await getActiveShiftId();
    return db.insert(tableVisits, {
      'client_id': _uuid.v4(),
      'driver_id': driverId,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'shift_id': resolvedShiftId,
      'note': note,
      'is_synced': 0,
      'retry_count': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedVisits() async {
    final db = await database;
    return db.query(tableVisits, where: 'is_synced = 0', orderBy: 'id ASC');
  }

  Future<void> markVisitSynced(int id) async {
    final db = await database;
    await db.update(tableVisits, {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementVisitRetry(int id) async {
    final db = await database;
    await db.rawUpdate('UPDATE $tableVisits SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }

  Future<List<Map<String, dynamic>>> getVisitsForShift(int shiftId) async {
    final db = await database;
    return db.query(tableVisits, where: 'shift_id = ?', whereArgs: [shiftId], orderBy: 'id ASC');
  }

  Future<int> getVisitCount(
    String driverId, {
    DateTime? since,
    DateTime? until,
  }) async {
    final db = await database;
    final clauses = <String>['driver_id = ?'];
    final args = <Object?>[driverId];
    if (since != null) {
      clauses.add('timestamp >= ?');
      args.add(since.toIso8601String());
    }
    if (until != null) {
      clauses.add('timestamp < ?');
      args.add(until.toIso8601String());
    }
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableVisits WHERE ${clauses.join(' AND ')}',
      args,
    );
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getVisitsForDriver(
    String driverId,
  ) async {
    final db = await database;
    return db.query(
      tableVisits,
      where: 'driver_id = ?',
      whereArgs: [driverId],
      orderBy: 'timestamp ASC',
    );
  }
}
