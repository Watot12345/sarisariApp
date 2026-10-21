import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';

class SettingsRepository {
  final AppDatabase _appDb;
  final Map<String, String> _memoryFallback;

  SettingsRepository([AppDatabase? appDb])
      : _appDb = appDb ?? AppDatabase.instance,
        _memoryFallback = {
          'store_name': 'SariMe',
          'theme_mode': 'system',
          'policy_accepted': 'false',
          'app_language': 'english',
        };

  Future<Database> get _db async => await _appDb.database;

  Future<String?> getSetting(String key) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (rows.isEmpty) return _memoryFallback[key];
      return rows.first['value'] as String?;
    } catch (_) {
      return _memoryFallback[key];
    }
  }

  Future<void> setSetting(String key, String value) async {
    _memoryFallback[key] = value;
    try {
      final db = await _db;
      await db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
