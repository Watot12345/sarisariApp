ROLE
You are a senior Flutter developer and mobile UI/UX designer. Build a polished, interactive, production-quality UI for an OFFLINE sari-sari store management app for Filipino store owners.

PROJECT
- App name: "Tindahan" (placeholder, easy to rename)
- Platform: Android first (Android 8.0+, must run smoothly on low-end phones with 2 GB RAM)
- Framework: Flutter (Dart), Material 3
- Offline only: no internet permission, no network calls, no cloud services
- Local storage: SQLite via `sqflite` + `path`
- Barcode scanning: `mobile_scanner`
- State management: Provider (keep it simple and readable)
- Use clean folder structure: lib/core (theme, constants), lib/data (db, models, repositories), lib/features/<feature>/(screens, widgets, providers)

TARGET USER
A non-technical store owner, often serving customers at the same time. Use is one-handed, fast, and in bright or dim light. UI must be usable in 2 to 3 taps for the core task (making a sale).

DESIGN DIRECTION
- Style: clean, friendly, modern, high-contrast, warm. Not corporate or cluttered.
- Color palette (define in ThemeData, light and dark mode):
  - Primary: warm green (#2E7D32) for money, success, and the main actions
  - Accent: amber (#FFB300) for highlights and alerts
  - Danger: soft red (#D32F2F) for low stock and utang overdue
  - Background: off-white (#FAF7F2); dark mode: deep charcoal (#121212)
- Typography: Google-style rounded sans (use `Poppins` or `Nunito` via local asset fonts, NOT network fonts). Large numbers for prices and totals.
- Shapes: rounded corners (16 to 20 px), soft elevation, generous spacing (8-pt grid)
- Touch targets: minimum 48x48 dp, primary buttons full-width and tall (56 dp)
- Currency: Philippine peso, formatted as ₱1,250.50
- Language: English with all strings in one file, ready for Filipino (Tagalog) translation
- Iconography: Material Symbols Rounded, consistent weight
- Empty states with friendly illustrations/icons and a clear call to action (no blank screens)

NAVIGATION
Bottom navigation bar with 5 tabs: Home, Sell, Products, Utang, Reports. The Sell tab is emphasized (center, larger button).

SCREENS AND INTERACTIONS

1. Home (Store Dashboard)
   - Greeting and today's date
   - Summary cards: Today's Sales, Estimated Profit, Items Sold, Total Utang Unpaid
   - Animated count-up on numbers when the screen opens
   - "Low stock" horizontal list with a quick restock button
   - Quick actions: New Sale, Scan Item, Add Product, Record Payment
   - Mini bar chart of the last 7 days of sales (draw with CustomPainter or `fl_chart`)

2. Sell (Point of Sale), the most important screen
   - Top: search bar plus a barcode scan button (opens camera scanner as a bottom sheet with flashlight toggle and manual entry fallback)
   - Product grid (tiles with name, price, stock badge); tap to add, long-press for quantity input
   - Cart as a draggable bottom sheet showing items, quantity steppers (+/-), swipe-to-remove with undo snackbar
   - Large total at the bottom, "Charge" button
   - Payment sheet: Cash (quick-amount chips: exact, 20, 50, 100, 500, 1000, auto-computed change in big text) or "Utang" (choose or add customer)
   - Success animation (checkmark) with haptic feedback, then a clear "New Sale" action
   - Prevent selling more than available stock, with a friendly warning

3. Products (Inventory)
   - Searchable list with category filter chips and a low-stock filter
   - Each item: name, price, stock level bar (green/amber/red)
   - Add/Edit product form: name, barcode (scan button), price, cost, stock, low-stock alert level, category, "pieces per pack" for tingi support
   - Swipe actions: edit, restock; confirm before delete
   - Restock dialog: quantity added, optional new cost

4. Utang (Customer Credit)
   - Customer list sorted by balance, with a total owed header
   - Color-coded status chip per customer (Good / Watch / High risk), placeholder for a future risk score
   - Customer detail: balance, transaction timeline, "Record payment" button (partial or full), "Share statement" action (text format)
   - Add customer: name, phone

5. Reports
   - Tabs: Day / Week / Month
   - Sales and profit chart, best-sellers list, utang summary
   - Date picker for custom ranges

6. Settings
   - Store name, PIN lock, light/dark/system theme, low-stock default
   - Backup: export JSON/CSV file, restore from file
   - About

UX DETAILS
- Smooth transitions: Hero animation from product tile to detail, animated list insertions, subtle button press scale animations (150 to 250 ms)
- Haptic feedback on add-to-cart, success, and errors
- Undo (snackbar) for destructive actions
- Skeleton or shimmer placeholders while loading from the database
- Form validation with clear inline messages
- Always show clear feedback after an action (toast, snackbar, or animation)
- Accessibility: readable contrast (WCAG AA), scalable text, semantic labels
- Responsive for small screens (360 dp wide) up to tablets

DATA LAYER (support the UI, keep it minimal for now)
Tables: products(id, name, barcode UNIQUE, price, cost, stock, low_stock_level, category, pieces_per_pack), customers, sales, sale_items, utang_payments. Use database transactions for sales so stock and totals never go out of sync. Seed the database with 15 to 20 realistic sample Filipino sari-sari products (e.g., Lucky Me Pancit Canton, Coke Mismo, Piattos, 3-in-1 Coffee sachet, Safeguard) so the UI looks real on first run.

CONSTRAINTS
- No internet permission, no network packages, no network fonts
- Keep APK small and the app fast on low-end phones: use const widgets, ListView.builder, avoid heavy packages
- Write clean, commented, null-safe Dart with reusable widgets (PriceText, StockBadge, StatCard, EmptyState, etc.)

WORKFLOW
1. First, propose the folder structure, theme, and navigation plan, and WAIT for my approval.
2. Then build in this order, pausing after each for my review: (a) theme + navigation shell, (b) database + seed data, (c) Sell screen with cart and payment, (d) Products + barcode scanning, (e) Utang, (f) Home dashboard + Reports, (g) Settings + backup.
3. After each step, make sure the app runs without errors (`flutter analyze` clean) and summarize what changed.

DELIVERABLE
A running Flutter project with the full interactive UI working on real local data, ready to test on an Android phone.

VOICE INPUT (hands-free restock and product entry)

Goal: the owner should be able to restock and add products by speaking instead of typing. Fully offline.

Package: `speech_to_text`. Request the microphone permission only. Still no internet permission and no network calls.

Where the mic appears:
- Products screen: a mic button next to search and next to the scan button
- Restock dialog and Add/Edit product form: a mic icon on each text field (dictate into that field)
- Global "Voice command" button on the Products screen for full commands

Voice commands to support (English, Filipino, and Taglish):
1. Restock: "Add 10 Coke Mismo", "Dagdag sampung Piattos"
2. Multiple items: "Sampung Coke, lima Piattos, dalawang kape"
3. New product: "Bagong produkto, Lucky Me Pancit Canton, presyo 12, stock 20"
4. Search: "Hanap Safeguard"

Behavior rules:
- NEVER save directly from voice. Always show a Confirmation card/sheet with parsed rows: matched product, quantity, price. Every field editable, with Confirm and Cancel buttons.
- Parse on-device only. Write a `VoiceCommandParser` class (pure Dart, unit-testable) that: (a) converts English and Tagalog number words to digits (isa, dalawa, tatlo, apat, lima, anim, pito, walo, siyam, sampu, labindalawa, dalawampu, dosena, etc.), (b) detects the intent by keywords (dagdag/add/restock, bago/new, hanap/search), (c) fuzzy-matches product names against the local database and shows the top 3 candidates when confidence is low.
- Prefer on-device recognition. Check whether the locale (fil-PH, en-PH, en-US) is available offline; if not, show a friendly sheet explaining how to download the voice pack, and fall back to typing.
- Mic UI: large pulsing mic button while listening, live transcript text, auto-stop after silence, a clear "Didn't catch that, try again" state, and haptic feedback on start and finish.
- Handle permission denied, no mic, and unsupported device gracefully with typing as the fallback.
- Add a language toggle in Settings for the voice locale (Filipino / English).
- Include unit tests for the parser with at least 15 sample phrases, including Taglish.

Build order addition: after step (d) Products + barcode scanning, add step (d2) Voice input, and pause for my review.