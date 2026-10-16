import 'dart:ffi';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart';
import 'package:tindahan/data/db/app_database.dart';
import 'package:tindahan/data/db/migrations/m001_initial.dart';
import 'package:tindahan/data/repositories/settings_repository.dart';
import 'package:tindahan/features/onboarding/providers/onboarding_provider.dart';

void main() {
  late Database db;
  late AppDatabase appDb;
  late SettingsRepository settingsRepo;

  setUp(() async {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('PRAGMA foreign_keys = ON;');
    await M001Initial.create(db);
    appDb = AppDatabase.forTesting(db);
    settingsRepo = SettingsRepository(appDb);
  });

  tearDown(() async {
    await db.close();
  });

  group('Onboarding & Privacy Policy Tests', () {
    test('OP-01: Policy is unaccepted by default on fresh install', () async {
      final onboardingProv = OnboardingProvider(settingsRepo: settingsRepo);
      // Wait for async load
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(onboardingProv.isPolicyAccepted, isFalse);
    });

    test('OP-02: Accepting policy persists to SQLite settings and updates state', () async {
      final onboardingProv = OnboardingProvider(settingsRepo: settingsRepo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await onboardingProv.acceptPolicy();
      expect(onboardingProv.isPolicyAccepted, isTrue);

      // Verify persisted in SQLite
      final persisted = await settingsRepo.getSetting('policy_accepted');
      expect(persisted, equals('true'));

      // New instance reads persisted agreement
      final secondInstance = OnboardingProvider(settingsRepo: settingsRepo);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(secondInstance.isPolicyAccepted, isTrue);
    });

    test('OP-03: Resetting policy updates state and database', () async {
      final onboardingProv = OnboardingProvider(settingsRepo: settingsRepo);
      await onboardingProv.acceptPolicy();
      expect(onboardingProv.isPolicyAccepted, isTrue);

      await onboardingProv.resetPolicy();
      expect(onboardingProv.isPolicyAccepted, isFalse);

      final persisted = await settingsRepo.getSetting('policy_accepted');
      expect(persisted, equals('false'));
    });
  });
}
