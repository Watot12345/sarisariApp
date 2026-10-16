import 'package:sqflite/sqflite.dart';
import '../../core/exceptions.dart';
import '../db/app_database.dart';
import '../models/utang_entry.dart';

class UtangRepository {
  final AppDatabase _appDb;
  UtangRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDb.database;

  /// Fetches chronological ledger entries for a specific customer, excluding voided sales.
  Future<List<UtangEntry>> getEntriesForCustomer(int customerId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT u.*
      FROM utang_entries u
      LEFT JOIN sales s ON u.sale_id = s.id
      WHERE u.customer_id = ?
        AND (s.id IS NULL OR s.status != 'voided')
      ORDER BY u.created_at ASC
    ''', [customerId]);

    return rows.map((r) => UtangEntry.fromMap(r)).toList();
  }

  /// Calculates net utang balance for a customer (Total Charges - Total Payments).
  Future<int> getCustomerBalance(int customerId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE 
          WHEN u.type = 'charge' THEN u.amount_cents 
          WHEN u.type = 'payment' THEN -u.amount_cents 
          ELSE 0 
        END
      ), 0) AS balance_cents
      FROM utang_entries u
      LEFT JOIN sales s ON u.sale_id = s.id
      WHERE u.customer_id = ?
        AND (s.id IS NULL OR s.status != 'voided')
    ''', [customerId]);

    if (rows.isEmpty) return 0;
    return (rows.first['balance_cents'] as int?) ?? 0;
  }

  /// Records an utang payment made by a customer.
  Future<int> recordPayment(
    int customerId,
    int amountCents, {
    String? note,
  }) async {
    if (amountCents <= 0) {
      throw const ValidationException('Kailangang mas mataas sa zero ang ibinayad.');
    }

    final balance = await getCustomerBalance(customerId);
    if (amountCents > balance) {
      throw const ValidationException('Hindi puwedeng lumampas sa utang ang bayad.');
    }

    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    return await db.insert('utang_entries', {
      'customer_id': customerId,
      'type': 'payment',
      'amount_cents': amountCents,
      'note': note ?? 'Payment received',
      'created_at': now,
    });
  }

  /// Records a manual utang charge (e.g. store credit outside POS).
  Future<int> recordCharge(
    int customerId,
    int amountCents, {
    String? note,
    String? dueDate,
  }) async {
    if (amountCents <= 0) {
      throw const ValidationException('Kailangang mas mataas sa zero ang utang charge.');
    }

    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    return await db.insert('utang_entries', {
      'customer_id': customerId,
      'type': 'charge',
      'amount_cents': amountCents,
      'due_date': dueDate,
      'note': note ?? 'Manual charge',
      'created_at': now,
    });
  }

  /// Total store-wide outstanding utang across all active customers.
  Future<int> getTotalOutstandingUtang() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE 
          WHEN u.type = 'charge' THEN u.amount_cents 
          WHEN u.type = 'payment' THEN -u.amount_cents 
          ELSE 0 
        END
      ), 0) AS total_utang
      FROM utang_entries u
      LEFT JOIN sales s ON u.sale_id = s.id
      JOIN customers c ON u.customer_id = c.id
      WHERE c.is_active = 1
        AND (s.id IS NULL OR s.status != 'voided')
    ''');

    if (rows.isEmpty) return 0;
    return (rows.first['total_utang'] as int?) ?? 0;
  }
}
