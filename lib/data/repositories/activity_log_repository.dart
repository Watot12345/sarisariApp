import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/activity_log.dart';

/// Repository for recording and querying store activity audit logs in SQLite.
class ActivityLogRepository {
  final AppDatabase _appDb;
  static final List<ActivityLog> _memoryLogs = [];

  ActivityLogRepository([AppDatabase? appDb])
      : _appDb = appDb ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDb.database;

  /// Records a new store activity log entry (safe in both SQLite and in-memory test environments).
  Future<void> logActivity({
    required String actionType,
    required String title,
    required String description,
    DatabaseExecutor? txn,
  }) async {
    final entry = ActivityLog(
      actionType: actionType,
      title: title,
      description: description,
      createdAt: DateTime.now(),
    );
    _memoryLogs.insert(0, entry);
    if (_memoryLogs.length > 200) {
      _memoryLogs.removeLast();
    }

    try {
      final executor = txn ?? await _db;
      await executor.insert(
        'activity_logs',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Fallback to in-memory log when running in web/widget-test mode
    }
  }

  /// Retrieves recent store activity logs ordered newest first.
  Future<List<ActivityLog>> getRecentLogs({int limit = 100}) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'activity_logs',
        orderBy: 'created_at DESC, id DESC',
        limit: limit,
      );
      if (rows.isNotEmpty) {
        return rows.map(ActivityLog.fromMap).toList();
      }
    } catch (_) {}
    return List.unmodifiable(_memoryLogs.take(limit));
  }

  /// Clears all recorded activity logs.
  Future<void> clearLogs() async {
    _memoryLogs.clear();
    try {
      final db = await _db;
      await db.delete('activity_logs');
    } catch (_) {}
  }
}
