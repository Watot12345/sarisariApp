import 'package:sqflite/sqflite.dart';

/// Migration m001: Initial Tindahan database schema matching schema.sql
class M001Initial {
  static Future<void> create(Database db) async {
    // Categories table
    await db.execute('''
      CREATE TABLE categories (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT NOT NULL UNIQUE
      );
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        name                  TEXT    NOT NULL,
        barcode               TEXT    UNIQUE,
        category_id           INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        price_cents           INTEGER NOT NULL CHECK (price_cents >= 0),
        cost_cents            INTEGER NOT NULL DEFAULT 0 CHECK (cost_cents >= 0),
        stock_qty             INTEGER NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
        low_stock_level       INTEGER NOT NULL DEFAULT 5,
        piece_product_id      INTEGER REFERENCES products(id) ON DELETE SET NULL,
        pieces_per_pack       INTEGER CHECK (pieces_per_pack IS NULL OR pieces_per_pack > 1),
        expiry_date           TEXT,
        image_path            TEXT,
        is_active             INTEGER NOT NULL DEFAULT 1,
        created_at            TEXT NOT NULL,
        updated_at            TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name);');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode);');
    await db.execute('CREATE INDEX idx_products_active ON products(is_active);');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        name               TEXT NOT NULL,
        phone              TEXT,
        credit_limit_cents INTEGER NOT NULL DEFAULT 0,
        notes              TEXT,
        risk_score         INTEGER,
        risk_level         TEXT CHECK (risk_level IN ('low','medium','high')),
        is_active          INTEGER NOT NULL DEFAULT 1,
        created_at         TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_customers_name ON customers(name);');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        sold_at             TEXT NOT NULL,
        total_cents         INTEGER NOT NULL CHECK (total_cents >= 0),
        payment_type        TEXT NOT NULL CHECK (payment_type IN ('cash','utang')),
        cash_received_cents INTEGER,
        change_cents        INTEGER,
        customer_id         INTEGER REFERENCES customers(id),
        status              TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed','voided')),
        voided_at           TEXT,
        void_reason         TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_sales_sold_at ON sales(sold_at);');
    await db.execute('CREATE INDEX idx_sales_customer ON sales(customer_id);');

    // Sale items table
    await db.execute('''
      CREATE TABLE sale_items (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id             INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id          INTEGER NOT NULL REFERENCES products(id),
        product_name        TEXT    NOT NULL,
        qty                 INTEGER NOT NULL CHECK (qty > 0),
        unit_price_cents    INTEGER NOT NULL,
        unit_cost_cents     INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);');
    await db.execute('CREATE INDEX idx_sale_items_product ON sale_items(product_id);');

    // Utang entries ledger
    await db.execute('''
      CREATE TABLE utang_entries (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id   INTEGER NOT NULL REFERENCES customers(id),
        type          TEXT NOT NULL CHECK (type IN ('charge','payment')),
        amount_cents  INTEGER NOT NULL CHECK (amount_cents > 0),
        sale_id       INTEGER REFERENCES sales(id),
        due_date      TEXT,
        note          TEXT,
        created_at    TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_utang_customer ON utang_entries(customer_id, created_at);');

    // Stock movements audit log
    await db.execute('''
      CREATE TABLE stock_movements (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id      INTEGER NOT NULL REFERENCES products(id),
        type            TEXT NOT NULL CHECK (type IN
                          ('sale','void_return','restock','adjustment','pack_break_out','pack_break_in','expired')),
        qty_change      INTEGER NOT NULL,
        unit_cost_cents INTEGER,
        sale_id         INTEGER REFERENCES sales(id),
        note            TEXT,
        created_at      TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_movements_product ON stock_movements(product_id, created_at);');

    // Settings key-value
    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // Activity logs audit trail (v1.01)
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
}
