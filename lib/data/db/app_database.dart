import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'migrations/m001_initial.dart';
import 'seed.dart';

/// SQLite Database Manager for Tindahan (Offline Only).
class AppDatabase {
  AppDatabase._();
  AppDatabase.forTesting(Database db) : _database = db {
    instance._database = db;
  }
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'tindahan.db';
  static const int _dbVersion = 3;

  Database? _database;

  /// Retrieves the active SQLite database instance, opening and initializing if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (kIsWeb) {
      throw UnsupportedError('Native SQLite runs on Android/iOS devices. Web preview uses in-memory state.');
    }
    _database = await _initDatabase().timeout(
      const Duration(seconds: 4),
      onTimeout: () => throw TimeoutException('Database initialization timed out'),
    );
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Enforce SQLite Foreign Key constraints for transactions
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await M001Initial.create(db);
        await DatabaseSeeder.seedDefaultsOnly(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Wipe v1 dummy seed data for clean production release
          await DatabaseSeeder.resetAllStoreData(db);
        }
        if (oldVersion < 3) {
          // Ensure activity_logs table and index exist without wiping user data
          await db.execute('''
            CREATE TABLE IF NOT EXISTS activity_logs (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              action_type TEXT NOT NULL,
              title       TEXT NOT NULL,
              description TEXT NOT NULL,
              created_at  TEXT NOT NULL
            );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);');
        }
      },
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT;');
        } catch (_) {
          // Column already exists
        }
        try {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS activity_logs (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              action_type TEXT NOT NULL,
              title       TEXT NOT NULL,
              description TEXT NOT NULL,
              created_at  TEXT NOT NULL
            );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);');
        } catch (_) {}
      },
    );
  }

  /// Wipes all products, customers, sales, and utang entries from the database.
  Future<void> resetAllData() async {
    try {
      final db = await database;
      await DatabaseSeeder.resetAllStoreData(db);
    } catch (_) {
      // Safe no-op in memory-only environments
    }
  }

  /// Closes database connection (used during teardown or backups)
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
