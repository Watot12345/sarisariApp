# AGENTS.md — Tindahan (offline sari-sari store app)

Read this file first, then everything in `docs/`, before writing any code.

## What we are building
An OFFLINE Android-first mobile app (Flutter) that helps a Filipino sari-sari store owner manage products, sales, stock, and utang (credit). It works with no internet at all. Headline innovations: barcode scanning, voice input (Filipino/English) for restock and product entry, utang risk scoring, and smart restock suggestions.

## Hard constraints (never break these)
1. **Offline only.** No network calls, no network packages, no network fonts, no cloud services. The main `AndroidManifest.xml` must NOT declare `INTERNET`. (Flutter's debug/profile manifests add it for hot reload; that is fine. Verify the release build has none.)
2. **Money is stored as INTEGER centavos** (₱12.50 = 1250). Never use floating point for money. Format only at the UI layer.
3. **Every write that touches more than one table runs inside a single SQLite transaction** (sales, voids, restocks, pack breaking, utang payments).
4. **Stock never goes negative.** Enforce in the repository layer and show a friendly UI message.
5. **Voice and scan results never save directly.** Always show an editable confirmation step first.
6. **Target low-end Android** (Android 8.0+, 2 GB RAM). Use `const` widgets, `ListView.builder`, avoid heavy packages.

## Tech stack (do not add packages without asking)
Flutter (Dart, null-safe, Material 3), `sqflite` + `path`, `provider`, `mobile_scanner`, `speech_to_text`, `intl`, `fl_chart` (charts, optional), `share_plus` + `file_picker` + `path_provider` (backup/export). Fonts are bundled as local assets.

## Working agreement
1. Work **one phase at a time** from `docs/05-build-plan.md`. Do not start the next phase until I approve.
2. At the start of each phase, post a short plan (files to create/change). **Wait for my approval** before structural changes: new packages, folder changes, schema changes.
3. Any schema change must update `docs/02-database-schema.md` and `schema.sql` and add a numbered migration.
4. At the end of each phase: `flutter analyze` is clean, tests pass, the app runs, and you give me a short summary of what changed and anything uncertain.
5. If a requirement is unclear or two docs conflict, ask. Do not guess silently.
6. Commit after each phase with a clear message (`feat: phase 3 sell screen`).

## Code conventions
- Folder layout is defined in `docs/01-architecture.md`. Follow it exactly.
- UI never talks to SQLite directly: UI → Provider → Repository → Database.
- Business rules live in `lib/domain/` as pure Dart (easy to unit test): sale totals, risk score, restock suggestion, voice parser.
- Reusable widgets go in `lib/shared/widgets/` (PriceText, StockBadge, StatCard, EmptyState, etc.).
- All user-facing strings live in one place (`lib/core/strings.dart`) so Filipino translation can be added later.
- Comment the "why", not the "what". Keep functions small.

## Definition of done (every phase)
- Works in airplane mode.
- `flutter analyze` has zero issues.
- Unit tests for the rules touched in that phase pass.
- Empty, loading, and error states exist for every screen.
- Matches `docs/ui-ux-spec.md`.

## Docs index
- `docs/requirements.md` — business, functional, and non-functional requirements (owner-provided)
- `docs/ui-ux-spec.md` — screens, interactions, design system (owner-provided)
- `docs/01-architecture.md` — layers, folders, state management
- `docs/02-database-schema.md` + `schema.sql` — tables, relationships, indexes
- `docs/03-business-rules.md` — exact behavior of sales, stock, utang, tingi, voids, backup
- `docs/04-smart-features.md` — scanner, voice parser, risk score, restock suggestions
- `docs/05-build-plan.md` — phases, tasks, acceptance criteria, tests
