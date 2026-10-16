# 03 — Business Rules

Exact behavior the code must implement. Pure calculations live in `lib/domain/`; multi-table writes live in repositories inside transactions.

## Making a sale
1. Cart holds (product, qty). Qty must be ≥ 1 and ≤ current `stock_qty`; otherwise show a warning and block.
2. `total = Σ price_cents × qty`.
3. **Cash:** `cash_received ≥ total` required; `change = cash_received − total`.
4. **Utang:** a customer is required. If a `credit_limit_cents` is set and `balance + total` exceeds it, show a warning (owner may override).
5. In ONE transaction: insert `sales`, insert `sale_items` (with price/cost/name snapshots), decrement `products.stock_qty`, insert `stock_movements(type='sale', qty_change=−qty)`, and for utang insert `utang_entries(type='charge', sale_id=…)`.
6. After commit: recompute that customer's risk score (if utang), then show the success state.
7. If any step fails, roll back everything and show a friendly error.

## Voiding a sale
- Only `completed` sales can be voided. Ask for confirmation and an optional reason.
- In ONE transaction: set `status='voided'`, `voided_at`, `void_reason`; restore stock; insert `stock_movements(type='void_return', qty_change=+qty)`; if utang, insert a matching `payment` entry labeled "Void of sale #id" so the balance is reversed (keep the ledger append-only, never delete entries).
- Voided sales are excluded from reports, best-sellers, and profit.

## Stock rules
- `stock_qty` can never go below 0 (CHECK constraint + repository validation).
- **Restock:** add qty, log `restock` with optional new cost. If a new cost is given, update `products.cost_cents` (latest cost wins).
- **Adjustment:** manual correction (e.g., recount, damaged). Requires a note. Logged as `adjustment`.
- **Expired:** removes qty, logged as `expired`.
- **Low stock:** `stock_qty <= low_stock_level` triggers badges, the Home low-stock list, and restock suggestions.

## Tingi (pack → piece)
- A pack product may link to a piece product via `piece_product_id` and `pieces_per_pack`.
- "Break pack" action: in ONE transaction, pack stock −1 (`pack_break_out`), piece stock + `pieces_per_pack` (`pack_break_in`).
- If a piece sale would exceed piece stock but a pack is available, offer: "Break 1 pack?" before blocking.
- Cost per piece = `pack cost / pieces_per_pack` (rounded, set when the piece product is created or edited; owner can override).

## Barcode rules
- Barcode is UNIQUE. Scanning a known barcode in Sell adds it to the cart (repeat scans increase qty by 1).
- Unknown barcode in Sell → offer "Register this product" with the barcode prefilled.
- Unknown barcode in Products → open the Add Product form with the barcode prefilled.
- Duplicate barcode on save → inline error offering to open the existing product.

## Utang
- Balance per customer = Σ charges − Σ payments.
- **Payment:** any amount > 0 and ≤ current balance. Partial allowed. Insert `payment` entry, recompute risk.
- A customer with a balance cannot be deleted (only deactivated after the balance is 0).
- Optional `due_date` on charges (default: none). Overdue = unpaid charge older than its due date, or older than the `default_due_days` setting (default 15) when no due date is set.
- "Share statement" produces plain text: store name, customer, date, itemized recent entries, current balance.

## Reports
- Day/Week/Month boundaries use the phone's local time.
- Sales total = Σ completed sales `total_cents`. Profit = Σ (price − cost) × qty. Utang unpaid = Σ all customer balances.
- Best sellers = top 10 products by quantity in the period.

## Backup and restore
- **Export:** one JSON file containing all tables + `schema_version` + export timestamp. Share via the system share sheet (`share_plus`). Also offer CSV exports of products and sales.
- **Restore:** pick a file, validate `schema_version` and structure, show a summary ("42 products, 318 sales"), require explicit confirmation ("This replaces all current data"), then replace everything inside ONE transaction. On any error, keep the current data untouched.
- Remind the owner to back up if the last backup is older than 7 days (a soft banner on Home).

## PIN lock
- Optional 4-digit PIN stored as a salted hash in `settings`. Ask on app open and when resuming after 1+ minute in the background. Forgot PIN: explain that data can only be recovered from a backup (no server).
