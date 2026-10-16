import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/customer.dart';

class CustomerRepository {
  final AppDatabase _appDb;
  CustomerRepository([AppDatabase? appDb]) : _appDb = appDb ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDb.database;

  /// Fetches all active customers with their live calculated utang balance.
  Future<List<Customer>> getCustomers({String? searchQuery}) async {
    final db = await _db;

    String sql = '''
      SELECT 
        c.*,
        COALESCE((
          SELECT SUM(
            CASE 
              WHEN u.type = 'charge' THEN u.amount_cents 
              WHEN u.type = 'payment' THEN -u.amount_cents 
              ELSE 0 
            END
          )
          FROM utang_entries u
          LEFT JOIN sales s ON u.sale_id = s.id
          WHERE u.customer_id = c.id
            AND (s.id IS NULL OR s.status != 'voided')
        ), 0) AS balance_cents
      FROM customers c
      WHERE c.is_active = 1
    ''';
    final List<dynamic> args = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      sql += ' AND (c.name LIKE ? OR c.phone LIKE ?)';
      args.addAll([term, term]);
    }

    sql += ' ORDER BY c.name ASC';

    final rows = await db.rawQuery(sql, args);
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT 
        c.*,
        COALESCE((
          SELECT SUM(
            CASE 
              WHEN u.type = 'charge' THEN u.amount_cents 
              WHEN u.type = 'payment' THEN -u.amount_cents 
              ELSE 0 
            END
          )
          FROM utang_entries u
          LEFT JOIN sales s ON u.sale_id = s.id
          WHERE u.customer_id = c.id
            AND (s.id IS NULL OR s.status != 'voided')
        ), 0) AS balance_cents
      FROM customers c
      WHERE c.id = ? AND c.is_active = 1
    ''', [id]);

    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await _db;
    return await db.insert('customers', customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await _db;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> updateRiskScore(int customerId, int? score, String? level) async {
    final db = await _db;
    await db.update(
      'customers',
      {'risk_score': score, 'risk_level': level},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  Future<void> softDeleteCustomer(int id) async {
    final db = await _db;
    await db.update(
      'customers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
