import 'package:sqflite/sqflite.dart';

/// Initial seed data for first launch of Tindahan.
class DatabaseSeeder {
  static Future<void> seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM products'),
    ) ?? 0;

    if (count > 0) return; // Already seeded

    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // 1. Categories
      final categoryNames = [
        'Noodles',
        'Drinks',
        'Snacks',
        'Coffee',
        'Toiletries',
        'Household',
        'Cigarettes',
        'Condiments',
        'Canned Goods',
      ];

      final Map<String, int> catIds = {};
      for (final catName in categoryNames) {
        final id = await txn.insert('categories', {'name': catName});
        catIds[catName] = id;
      }

      // 2. Tingi Child Item: Marlboro Stick
      final stickId = await txn.insert('products', {
        'name': 'Marlboro Red (Stick - Tingi)',
        'barcode': null,
        'category_id': catIds['Cigarettes'],
        'price_cents': 1000, // ₱10.00
        'cost_cents': 800,   // ₱8.00
        'stock_qty': 60,
        'low_stock_level': 20,
        'piece_product_id': null,
        'pieces_per_pack': null,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // 3. Products
      final products = [
        {
          'name': 'Lucky Me Pancit Canton Kalamansi',
          'barcode': '4800016644023',
          'category_id': catIds['Noodles'],
          'price_cents': 1500, // ₱15.00
          'cost_cents': 1250,
          'stock_qty': 24,
          'low_stock_level': 8,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Lucky Me Pancit Canton Chilimansi',
          'barcode': '4800016644030',
          'category_id': catIds['Noodles'],
          'price_cents': 1500,
          'cost_cents': 1250,
          'stock_qty': 18,
          'low_stock_level': 8,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Coca-Cola Mismo 290ml',
          'barcode': '4801981110022',
          'category_id': catIds['Drinks'],
          'price_cents': 2000, // ₱20.00
          'cost_cents': 1650,
          'stock_qty': 32,
          'low_stock_level': 10,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Sprite Mismo 290ml',
          'barcode': '4801981110039',
          'category_id': catIds['Drinks'],
          'price_cents': 2000,
          'cost_cents': 1650,
          'stock_qty': 4, // Low stock
          'low_stock_level': 10,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Piattos Cheese 85g',
          'barcode': '4800016054112',
          'category_id': catIds['Snacks'],
          'price_cents': 3800, // ₱38.00
          'cost_cents': 3200,
          'stock_qty': 12,
          'low_stock_level': 5,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Nissin Cup Noodles Seafood',
          'barcode': null,
          'category_id': catIds['Noodles'],
          'price_cents': 2800,
          'cost_cents': 2350,
          'stock_qty': 6,
          'low_stock_level': 5,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Kopiko Blanca 3-in-1 Sachet',
          'barcode': null,
          'category_id': catIds['Coffee'],
          'price_cents': 1400, // ₱14.00
          'cost_cents': 1100,
          'stock_qty': 45,
          'low_stock_level': 15,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Great Taste White Coffee Sachet',
          'barcode': null,
          'category_id': catIds['Coffee'],
          'price_cents': 1400,
          'cost_cents': 1100,
          'stock_qty': 30,
          'low_stock_level': 15,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Safeguard Pure White Soap 60g',
          'barcode': null,
          'category_id': catIds['Toiletries'],
          'price_cents': 2600, // ₱26.00
          'cost_cents': 2150,
          'stock_qty': 8,
          'low_stock_level': 5,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Tide Plus Detergent Powder Sachet',
          'barcode': null,
          'category_id': catIds['Household'],
          'price_cents': 1600, // ₱16.00
          'cost_cents': 1300,
          'stock_qty': 3, // Low stock
          'low_stock_level': 10,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Skyflakes Crackers Single Pack',
          'barcode': null,
          'category_id': catIds['Snacks'],
          'price_cents': 800, // ₱8.00
          'cost_cents': 625,
          'stock_qty': 25,
          'low_stock_level': 10,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Marlboro Red (Pack - 20s)',
          'barcode': '4800888123456',
          'category_id': catIds['Cigarettes'],
          'price_cents': 19000, // ₱190.00
          'cost_cents': 16000,
          'stock_qty': 8,
          'low_stock_level': 3,
          'piece_product_id': stickId, // Links to Stick for Tingi breaking!
          'pieces_per_pack': 20,
        },
        {
          'name': 'Datu Puti Soy Sauce 200ml',
          'barcode': null,
          'category_id': catIds['Condiments'],
          'price_cents': 1900,
          'cost_cents': 1550,
          'stock_qty': 14,
          'low_stock_level': 6,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Datu Puti Vinegar 200ml',
          'barcode': null,
          'category_id': catIds['Condiments'],
          'price_cents': 1700,
          'cost_cents': 1380,
          'stock_qty': 0, // Out of stock
          'low_stock_level': 6,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
        {
          'name': 'Mega Sardines Red 155g',
          'barcode': '4806502010014',
          'category_id': catIds['Canned Goods'],
          'price_cents': 2500, // ₱25.00
          'cost_cents': 2100,
          'stock_qty': 15,
          'low_stock_level': 6,
          'piece_product_id': null,
          'pieces_per_pack': null,
        },
      ];

      for (final p in products) {
        await txn.insert('products', {
          ...p,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      // 4. Seed Customers
      final customers = [
        {
          'name': 'Elena Santos (Aling Nena)',
          'phone': '09171234567',
          'credit_limit_cents': 100000, // ₱1,000.00
          'notes': 'Pays every Friday payday',
          'risk_score': 22,
          'risk_level': 'low',
        },
        {
          'name': 'Rodrigo Cruz (Mang Digong)',
          'phone': '09287654321',
          'credit_limit_cents': 50000, // ₱500.00
          'notes': 'Remind before month end',
          'risk_score': 54,
          'risk_level': 'medium',
        },
        {
          'name': 'Jun-Jun Bautista (Tricycle Driver)',
          'phone': null,
          'credit_limit_cents': 30000,
          'notes': 'Overdue by 3 weeks; stop giving credit',
          'risk_score': 78,
          'risk_level': 'high',
        },
        {
          'name': 'Teresa Reyes (Ate Tess)',
          'phone': '09051112233',
          'credit_limit_cents': 150000,
          'notes': null,
          'risk_score': 15,
          'risk_level': 'low',
        },
        {
          'name': 'Michael Tan (Bagong Lipat)',
          'phone': null,
          'credit_limit_cents': 20000,
          'notes': 'New in neighborhood',
          'risk_score': null,
          'risk_level': null,
        },
      ];

      for (final c in customers) {
        final custId = await txn.insert('customers', {
          ...c,
          'is_active': 1,
          'created_at': now,
        });

        // Insert initial sample utang ledger entries so balances match
        if (c['risk_score'] == 22) {
          // Elena has ₱450.00 balance
          await txn.insert('utang_entries', {
            'customer_id': custId,
            'type': 'charge',
            'amount_cents': 45000,
            'note': 'Grocery credit balance',
            'created_at': now,
          });
        } else if (c['risk_score'] == 54) {
          // Rodrigo has ₱480.00 balance
          await txn.insert('utang_entries', {
            'customer_id': custId,
            'type': 'charge',
            'amount_cents': 48000,
            'note': 'Household items credit',
            'created_at': now,
          });
        } else if (c['risk_score'] == 78) {
          // Jun-Jun has ₱320.00 balance
          await txn.insert('utang_entries', {
            'customer_id': custId,
            'type': 'charge',
            'amount_cents': 32000,
            'note': 'Cigarettes and drinks utang',
            'created_at': now,
          });
        } else if (c['risk_score'] == 15) {
          // Teresa has ₱150.00 balance
          await txn.insert('utang_entries', {
            'customer_id': custId,
            'type': 'charge',
            'amount_cents': 15000,
            'note': 'Snacks credit',
            'created_at': now,
          });
        }
      }

      // 5. Default Settings
      await txn.insert('settings', {'key': 'store_name', 'value': 'SariMe'});
      await txn.insert('settings', {'key': 'default_low_stock', 'value': '5'});
      await txn.insert('settings', {'key': 'voice_locale', 'value': 'fil_PH'});
    });
  }
}
