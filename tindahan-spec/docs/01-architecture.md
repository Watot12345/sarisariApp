# 01 — Architecture

## Layers (nothing leaves the device)
```
UI (screens/widgets)
   ↓ calls / listens
State (Provider ChangeNotifiers, one per feature)
   ↓ calls
Repositories (lib/data/repositories) — only place that runs SQL
   ↓
SQLite via sqflite (lib/data/db)
   
Domain (lib/domain) — pure Dart business rules, no Flutter, no SQL
Device services: camera (mobile_scanner), microphone (speech_to_text), file system (backup)
```

## Folder structure
```
lib/
  main.dart
  app.dart                      # MaterialApp, theme, routes, bottom nav shell
  core/
    theme/                      # light + dark ThemeData, colors, text styles
    strings.dart                # all UI strings
    constants.dart
    utils/                      # money formatter, date helpers, debouncer
  data/
    db/
      app_database.dart         # open, onCreate, onUpgrade (migrations)
      migrations/               # m001_initial.dart, m002_...
      seed.dart                 # 15-20 sample Filipino products
    models/                     # Product, Customer, Sale, SaleItem, UtangEntry, StockMovement
    repositories/               # product_repo, sale_repo, customer_repo, utang_repo, report_repo, backup_repo, settings_repo
  domain/
    sale_calculator.dart        # totals, change
    risk_scorer.dart            # utang risk score
    restock_advisor.dart        # restock suggestions
    voice_command_parser.dart   # intents, number words, fuzzy match
  features/
    home/        (screens, widgets, home_provider.dart)
    sell/        (screens, widgets, cart_provider.dart)
    products/
    utang/
    reports/
    settings/
    voice/       (voice_sheet, confirmation card)
    scanner/     (scan_sheet)
  shared/
    widgets/                    # PriceText, StockBadge, StatCard, EmptyState, ConfirmSheet
test/
  domain/                       # unit tests for every file in lib/domain
  data/                         # repository tests using sqflite_common_ffi (in-memory DB)
```

## State management
- `provider` with `ChangeNotifier`. One provider per feature; providers receive repositories through constructors (easy to test).
- Providers expose immutable lists and simple `isLoading` / `error` fields.
- Cart state (`CartProvider`) lives only in memory until the sale is charged.

## Navigation
Bottom navigation with 5 tabs: Home, Sell (center, emphasized), Products, Utang, Reports. Settings opens from the Home app bar. Use named routes or `go_router` only if approved.

## Error handling
- Repositories throw typed exceptions (`OutOfStockException`, `DuplicateBarcodeException`, `ValidationException`).
- Providers catch them and expose a user-friendly message; the UI shows a snackbar or inline error. Never show raw exceptions.

## Database lifecycle
- Single `AppDatabase` instance, opened once at startup.
- `PRAGMA foreign_keys = ON` at every open.
- Versioned migrations in `onUpgrade`; never edit an old migration after release.
- Seed data inserted only on the first run and only if the products table is empty.

## Permissions
- `CAMERA` (scanner), `RECORD_AUDIO` (voice). No `INTERNET`, no storage permissions (use the system file picker/share sheet for backup).
