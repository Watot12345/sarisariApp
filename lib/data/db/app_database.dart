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
  static const int _dbVersion = 1;

  Database? _database;

  /// Retrieves the active SQLite database instance, opening and seeding if necessary.
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
        await DatabaseSeeder.seedIfEmpty(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Future migrations will be added here
      },
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT;');
        } catch (_) {
          // Column already exists
        }
      },
    );
  }

  /// Closes database connection (used during teardown or backups)
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
