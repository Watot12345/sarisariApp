-- Tindahan schema v1 (SQLite). Money = INTEGER centavos. Dates = ISO-8601 TEXT (UTC).
PRAGMA foreign_keys = ON;

CREATE TABLE categories (
  id    INTEGER PRIMARY KEY AUTOINCREMENT,
  name  TEXT NOT NULL UNIQUE
);

CREATE TABLE products (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  name                  TEXT    NOT NULL,
  barcode               TEXT    UNIQUE,                 -- nullable (loose items have none)
  category_id           INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  price_cents           INTEGER NOT NULL CHECK (price_cents >= 0),
  cost_cents            INTEGER NOT NULL DEFAULT 0 CHECK (cost_cents >= 0),
  stock_qty             INTEGER NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
  low_stock_level       INTEGER NOT NULL DEFAULT 5,
  -- Tingi: this (pack) product can be broken into pieces of another product
  piece_product_id      INTEGER REFERENCES products(id) ON DELETE SET NULL,
  pieces_per_pack       INTEGER CHECK (pieces_per_pack IS NULL OR pieces_per_pack > 1),
  expiry_date           TEXT,                           -- nullable, YYYY-MM-DD
  is_active             INTEGER NOT NULL DEFAULT 1,     -- soft delete
  created_at            TEXT NOT NULL,
  updated_at            TEXT NOT NULL
);
CREATE INDEX idx_products_name    ON products(name);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_active  ON products(is_active);

CREATE TABLE customers (
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  name               TEXT NOT NULL,
  phone              TEXT,
  credit_limit_cents INTEGER NOT NULL DEFAULT 0,        -- 0 = no limit set
  notes              TEXT,
  risk_score         INTEGER,                           -- 0-100, cached; NULL = unrated
  risk_level         TEXT CHECK (risk_level IN ('low','medium','high')),
  is_active          INTEGER NOT NULL DEFAULT 1,
  created_at         TEXT NOT NULL
);
CREATE INDEX idx_customers_name ON customers(name);

CREATE TABLE sales (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  sold_at             TEXT NOT NULL,
  total_cents         INTEGER NOT NULL CHECK (total_cents >= 0),
  payment_type        TEXT NOT NULL CHECK (payment_type IN ('cash','utang')),
  cash_received_cents INTEGER,                          -- cash sales only
  change_cents        INTEGER,                          -- cash sales only
  customer_id         INTEGER REFERENCES customers(id), -- required when payment_type = 'utang'
  status              TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed','voided')),
  voided_at           TEXT,
  void_reason         TEXT
);
CREATE INDEX idx_sales_sold_at  ON sales(sold_at);
CREATE INDEX idx_sales_customer ON sales(customer_id);

CREATE TABLE sale_items (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  sale_id             INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id          INTEGER NOT NULL REFERENCES products(id),
  product_name        TEXT    NOT NULL,                 -- snapshot, history stays correct if renamed
  qty                 INTEGER NOT NULL CHECK (qty > 0),
  unit_price_cents    INTEGER NOT NULL,                 -- snapshot
  unit_cost_cents     INTEGER NOT NULL                  -- snapshot, used for profit
);
CREATE INDEX idx_sale_items_sale    ON sale_items(sale_id);
CREATE INDEX idx_sale_items_product ON sale_items(product_id);

-- Utang ledger: balance = SUM(charge) - SUM(payment) per customer
CREATE TABLE utang_entries (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id   INTEGER NOT NULL REFERENCES customers(id),
  type          TEXT NOT NULL CHECK (type IN ('charge','payment')),
  amount_cents  INTEGER NOT NULL CHECK (amount_cents > 0),
  sale_id       INTEGER REFERENCES sales(id),           -- set for charges created by a sale
  due_date      TEXT,                                   -- optional, charges only
  note          TEXT,
  created_at    TEXT NOT NULL
);
CREATE INDEX idx_utang_customer ON utang_entries(customer_id, created_at);

-- Every stock change is logged (audit trail + feeds restock suggestions)
CREATE TABLE stock_movements (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id      INTEGER NOT NULL REFERENCES products(id),
  type            TEXT NOT NULL CHECK (type IN
                    ('sale','void_return','restock','adjustment','pack_break_out','pack_break_in','expired')),
  qty_change      INTEGER NOT NULL,                     -- negative = stock out
  unit_cost_cents INTEGER,                              -- restocks only
  sale_id         INTEGER REFERENCES sales(id),
  note            TEXT,
  created_at      TEXT NOT NULL
);
CREATE INDEX idx_movements_product ON stock_movements(product_id, created_at);

CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- keys: store_name, pin_hash, theme_mode, default_low_stock, voice_locale, schema_version_seen
