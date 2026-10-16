# 02 — Database Schema

Source of truth for SQL: `schema.sql`. This doc explains the design.

## Entity relationships
```
categories 1───* products
products   1───* sale_items *───1 sales *───0..1 customers
customers  1───* utang_entries *───0..1 sales
products   1───* stock_movements *───0..1 sales
products   0..1───1 products   (pack → piece, for tingi)
settings   (key/value)
```

## Design decisions
- **Money as integer centavos.** Avoids floating point errors. ₱12.50 = 1250.
- **Snapshots in `sale_items`** (name, price, cost). Editing a product later never rewrites history or profit.
- **Soft delete** (`is_active = 0`) for products and customers so old sales still reference them.
- **Utang is a ledger**, not a single balance column. Balance is always `SUM(charge) − SUM(payment)`. This makes payment history, due dates, and risk scoring possible.
- **`stock_movements` logs every change.** `products.stock_qty` is the fast-read value; the movements table is the audit trail and the data source for restock suggestions. They must always agree.
- **Voids** mark the sale `voided`, add `void_return` movements, and add a negative-effect utang entry if the sale was on credit (see business rules).
- **Cached risk score** on `customers` is recomputed after each utang charge/payment and on app start.

## Derived values (compute in repositories, do not store)
- Customer balance = charges − payments (ignore entries tied to voided sales).
- Sale profit = Σ (unit_price − unit_cost) × qty over non-voided sales.
- Low stock = `stock_qty <= low_stock_level`.

## Migrations
- `schema_version` uses sqflite's `version`. v1 = this file. New columns/tables go in `m002_*.dart`, etc.
- Never edit an old migration after it ships.

## Seed data (first run only)
15–20 realistic products with barcodes left null unless known: Lucky Me Pancit Canton, Coke Mismo, Piattos, 3-in-1 Coffee sachet, Safeguard, Great Taste White, Skyflakes, Marlboro (pack) + Marlboro (stick) as a tingi example, Tide sachet, Datu Puti Suka, etc., with sensible categories (Noodles, Drinks, Snacks, Coffee, Toiletries, Cigarettes, Condiments).
