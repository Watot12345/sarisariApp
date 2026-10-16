# 05 — Build Plan

Work one phase at a time. Post a plan first, wait for approval, then build. After each phase: `flutter analyze` clean, tests pass, runs in airplane mode, short summary, commit.

## Phase 0 — Project setup
- `flutter create` (Android only is fine), set package name, app name "Tindahan".
- Add the approved packages. Add bundled fonts (local assets).
- Remove `INTERNET` from the main manifest; add `CAMERA` and `RECORD_AUDIO` only.
- Create the folder structure from `01-architecture.md` and commit docs.
- **Done when:** the empty app runs; `flutter analyze` is clean.

## Phase 1 — Theme and navigation shell
- Light/dark Material 3 theme from `ui-ux-spec.md` (colors, type scale, shapes).
- Bottom navigation (5 tabs, Sell emphasized), placeholder screens, shared widgets (PriceText, StockBadge, StatCard, EmptyState).
- **Done when:** tabs navigate smoothly; theme switch works; widgets have a small demo.

## Phase 2 — Database and seed data
- `AppDatabase`, migration m001 from `schema.sql`, models, repositories (products, customers, sales, utang, stock, settings).
- Seed data on the first run.
- **Tests (sqflite_common_ffi, in-memory):** CRUD, unique barcode, stock never negative, transaction rollback on failure.
- **Done when:** repositories pass tests; seed products visible in a debug list.

## Phase 3 — Products and inventory
- List with search, category chips, low-stock filter; add/edit form with validation; restock; adjustment; soft delete with confirm; tingi link and "break pack".
- **Done when:** FR1–FR4 work; every stock change creates a `stock_movements` row.

## Phase 4 — Sell screen
- Product grid + search, cart bottom sheet, quantity steppers, swipe-remove with undo, stock guard.
- Payment sheet: cash with quick-amount chips and change; utang with customer picker.
- Transactional charge, success animation + haptics, void from sales history.
- **Tests:** `SaleCalculator`, sale transaction, void restores stock and balance.
- **Done when:** FR5–FR9 work end to end.

## Phase 5 — Barcode scanning
- Scan sheet with flashlight and manual fallback; wire into Sell, Products, and restock.
- **Done when:** known barcode adds to cart, unknown offers registration, duplicate barcode handled.

## Phase 6 — Utang and customers
- Customer list, detail with ledger timeline, add customer, record payment, share statement.
- **Tests:** balance math, partial payments, voided-sale reversal.
- **Done when:** FR10–FR13 work.

## Phase 7 — Home dashboard and Reports
- Summary cards with count-up animation, low-stock list, 7-day chart, quick actions.
- Reports: Day/Week/Month/custom range, profit, best sellers, utang summary.
- **Tests:** report queries against seeded sales.
- **Done when:** FR14–FR16 match hand-calculated numbers.

## Phase 8 — Voice input
- `VoiceCommandParser` + unit tests first (≥ 20 phrases), then the mic UI, locale check, offline-pack guidance, confirmation card.
- Wire into Products, the restock dialog, and the Add Product form.
- **Done when:** the voice commands in `04-smart-features.md` work and never save without confirmation.

## Phase 9 — Smart features
- `RiskScorer` (+ tests) → chips, reasons, warnings in Sell.
- `RestockAdvisor` (+ tests) → suggestions list and shopping list share.
- Expiry tracking.
- **Done when:** scores and suggestions match hand-calculated examples in the tests.

## Phase 10 — Settings, backup, PIN
- Store name, theme, defaults, voice locale, PIN lock.
- JSON export/restore (with validation and confirmation), CSV exports, backup reminder.
- **Tests:** export → restore round trip gives identical data; a corrupt file leaves data untouched.
- **Done when:** FR17–FR18 work.

## Phase 11 — Polish and release
- Empty/loading/error states audit, accessibility pass (contrast, text scale, semantics), small-screen check at 360 dp.
- Performance test with 1,000+ products and 10,000+ sales on a low-end device.
- Airplane-mode test of every feature; verify the release manifest has no `INTERNET`.
- `flutter build apk --release`; write a short user manual.

## Test checklist (cross-phase)
- [ ] Sale totals/change correct for cash and utang
- [ ] Stock can't go negative; failed transaction leaves no partial data
- [ ] Void restores stock and reverses utang
- [ ] Utang balance = charges − payments
- [ ] Backup → restore round trip is lossless
- [ ] Risk score and restock suggestions match worked examples
- [ ] Voice parser handles Tagalog numbers and Taglish
- [ ] App fully works in airplane mode
