<div align="center">
  <img src="docs/app_icon.png" alt="SariMe Logo" width="110" height="110" style="border-radius: 24px;" />

  # SariMe (Tindahan POS)
  **Offline-First Mobile Point of Sale (POS) & Digital *Utang* Credit Ledger for Filipino Sari-Sari Stores**

  [![Release](https://img.shields.io/github/v/release/Watot12345/sarisariApp?color=059669&label=Latest%20Release&style=for-the-badge)](https://github.com/Watot12345/sarisariApp/releases/latest)
  [![Build Status](https://img.shields.io/github/actions/workflow/status/Watot12345/sarisariApp/release.yml?label=APK%20Release%20CI&style=for-the-badge)](https://github.com/Watot12345/sarisariApp/actions)
  [![Platform](https://img.shields.io/badge/Platform-Android%208.0%2B-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/Watot12345/sarisariApp/releases/latest/download/app-release.apk)
  [![Flutter](https://img.shields.io/badge/Built%20With-Flutter%203-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![License](https://img.shields.io/badge/License-MIT-f59e0b?style=for-the-badge)](LICENSE)

  <p align="center">
    <a href="https://watot12345.github.io/sarisariApp/"><strong>🌐 Official Website & Landing Page</strong></a> •
    <a href="https://github.com/Watot12345/sarisariApp/releases/latest/download/app-release.apk"><strong>📥 Download Latest APK</strong></a> •
    <a href="https://github.com/Watot12345/sarisariApp/releases"><strong>📦 All Releases</strong></a> •
    <a href="https://watot12345.github.io/sarisariApp/privacy.html"><strong>🔒 Privacy Policy</strong></a>
  </p>
</div>

---

## 📖 Overview

**SariMe** is a purpose-built, offline-first Android application engineered for Filipino micro-retailers and *sari-sari* store owners. It replaces torn paper logbooks (*listahan ng utang*) and manual calculators with a fast, zero-latency mobile Point of Sale, camera barcode scanner, customer credit ledger, and real-time net profit tracker—operating **100% offline** without requiring Wi-Fi, mobile data, or monthly cloud subscriptions.

---

## ✨ Key Features

| Module | Capabilities |
| :--- | :--- |
| **🛒 Fast Point of Sale (Sell)** | • Instant camera barcode scanning (`mobile_scanner`) with flashlight toggle & manual barcode fallback<br>• Quick-cash denomination buttons (`₱20`, `₱50`, `₱100`, `₱200`, `₱500`, `₱1,000`) with automatic change (*sukli*) calculation<br>• Supports both **Cash** and **Customer Credit (*Utang*)** checkout in a single atomic SQLite transaction<br>• Recent sales history with stock-restoring **Sale Void** confirmation |
| **📦 Inventory & Stock Control** | • Full product catalog with cost price (*puhunan*), selling price, category filters, and low-stock thresholds<br>• Barcode uniqueness enforcement & instant **Scan-to-Restock / Scan-to-Add** workflow<br>• Complete stock movement audit trail (`sale`, `restock`, `adjustment`, `void`) |
| **📒 Digital *Utang* Credit Ledger** | • Dedicated customer profiles with contact details, credit limits, and optional due dates<br>• Chronological ledger of credit charges and partial/full payments (*hulog / bayad*)<br>• Overdue and near-due customer alerts |
| **📊 Financial & Profit Reports** | • Real-time daily, weekly, and monthly revenue vs. net profit breakdown<br>• Top-selling products ranking and inventory valuation metrics<br>• **Owner PIN Lock** to protect sensitive profit margins when a store helper (*bantay*) operates the counter |
| **📱 Android Home Screen Widget** | • Native Android Glance/AppWidget displaying Today's Sales, Goal Progress, and Quick-Sell / Quick-Scan deep links (`tindahan://sell`, `tindahan://scan`)<br>• 1-tap **"Add to Phone"** widget pinning directly from the app |
| **🌏 Bilingual & Gamified UX** | • Seamless 1-tap switching between **English (EN)** and conversational **Tagalog (TL)**<br>• Storekeeper progression system (Levels 1–5 from *Starter Storekeeper* to *Sari-Sari Legend*), daily sales goal tracker, and achievement badges<br>• Native mobile scroll physics with Light & Dark Mode support |
| **🔄 Remote Status & Updates** | • Built-in GitHub Releases update checker (*Settings → Check for Updates*)<br>• Remote configuration via `docs/status.json` supporting broadcast announcements, required updates, and remote maintenance mode |

---

## 📥 Installation (End Users)

1. Visit the official landing page at **[https://watot12345.github.io/sarisariApp/](https://watot12345.github.io/sarisariApp/)** or download **[`app-release.apk`](https://github.com/Watot12345/sarisariApp/releases/latest/download/app-release.apk)** directly from [GitHub Releases](https://github.com/Watot12345/sarisariApp/releases).
2. Open the downloaded `.apk` file on your Android device (Android 8.0 / API 26 or newer).
3. If prompted by Android, allow **Install Unknown Apps** for your browser or file manager.
4. Tap **Install**, open **SariMe**, review and accept the offline privacy disclosures, and start managing your store.

---

## 🏗️ System Architecture & Tech Stack

SariMe follows a layered **Clean Feature Architecture** using `Provider` state management and an ACID-compliant local SQLite database (`sqflite`):

```text
lib/
├── app.dart                  # Root MaterialApp, MultiProvider, NavigationShell & Remote Status Gate
├── main.dart                 # Application entry point
├── core/
│   ├── constants.dart        # Design tokens, spacing, and GitHub release/status endpoints
│   ├── localization/         # Bilingual English (EN) & Tagalog (TL) LanguageProvider
│   ├── services/             # NotificationService, HomeWidgetService, UpdateService
│   ├── theme/                # Material 3 Light/Dark themes & MobileAppScrollBehavior
│   └── utils/                # Centavo-precise currency formatters (avoids floating-point drift)
├── data/
│   ├── db/                   # AppDatabase singleton, schema migrations (m001_initial), seeder
│   ├── models/               # Immutable domain models (Product, Sale, Customer, UtangEntry, etc.)
│   └── repositories/         # SQLite repositories (Product, Stock, Sale, Customer, Utang, Reports)
└── features/
    ├── home/                 # Dashboard KPIs, low-stock banners, and quick actions
    ├── products/             # Inventory catalog, category filtering, and restock sheets
    ├── sell/                 # POS cart, barcode scanning integration, cash/utang checkout
    ├── utang/                # Customer credit ledger, payment recording, and credit limits
    ├── reports/              # Revenue/profit analytics and top-seller charts (fl_chart)
    ├── gamification/         # Store avatar progression, XP levels, and daily sales goals
    ├── notifications/        # In-app & system local push notifications
    ├── onboarding/           # First-launch Privacy Policy & Permission Consent screen
    └── settings/             # Store profile, PIN lock, JSON backup/reset, and update checker
```

### Monetary Precision Guarantee
All monetary values (`cost_cents`, `price_cents`, `total_cents`, `balance_cents`) are stored and computed strictly as **64-bit integers in centavos** (`₱1.00 = 100 centavos`), eliminating IEEE 754 floating-point rounding errors across all sales and credit calculations.

---

## 🛠️ Local Development & Testing

### Prerequisites
- **Flutter SDK**: `>=3.0.0 <4.0.0` (Stable channel)
- **Java JDK**: `17`
- **SQLite3 Shared Library** (for running desktop FFI unit/widget tests on Linux):
  ```bash
  sudo apt-get update && sudo apt-get install -y libsqlite3-0 libsqlite3-dev
  ```

### Setup & Run
```bash
# 1. Clone the repository
git clone https://github.com/Watot12345/sarisariApp.git
cd sarisariApp

# 2. Fetch Flutter packages
flutter pub get

# 3. Run the application on a connected Android device or emulator
flutter run
```

### Running the Automated Test Suite
The repository includes **106 automated unit, database, provider, and widget tests** covering database constraints, atomic sales/voids, barcode scanning, credit ledgers, bilingual switching, and remote status parsing:
```bash
flutter test --concurrency=1
```

### Building the Production APK Locally
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🚀 Automated CI/CD & Remote Operations

### Publishing a New Release via GitHub Actions
The workflow in [`.github/workflows/release.yml`](.github/workflows/release.yml) automatically runs the full test suite, compiles the release APK, and publishes `app-release.apk` and `SariMe-<version>.apk` to GitHub Releases whenever a version tag is pushed:

```bash
git tag v1.0.1
git push origin v1.0.1
```

### Remote Maintenance Mode & Broadcast Announcements
Administrators can remotely manage active clients via [`docs/status.json`](docs/status.json) hosted on GitHub Pages:
- **Maintenance Mode**: Set `"maintenance_mode": true` in `docs/status.json` (or include `[MAINTENANCE]` in the latest GitHub Release notes) to display a full-screen maintenance lock screen on connected devices.
- **Force Update**: Set `"force_update": true` or bump `"min_required_version"` in `docs/status.json` to require users to download the latest APK.
- **In-App Announcement**: Set `"announcement.active": true` with a unique `"id"` in `docs/status.json` to display a bilingual broadcast modal on app launch.

---

## 🔒 Privacy, Legal Compliance & License

- **Local-First Data Privacy (RA 10173 & GDPR)**: All store inventory, sales, and customer credit records reside strictly in the user's on-device SQLite database. No personal or financial store data is transmitted to external servers.
- **Non-Fiscal Bookkeeping Disclaimer**: SariMe is provided *"AS IS"* as an internal digital logbook helper for micro-retailers and does not replace official BIR-accredited fiscal POS machines where required by law.
- Full policy details are available in [`docs/privacy.html`](docs/privacy.html) and inside the app under **Settings → Privacy Policy**.
- Licensed under the **[MIT License](LICENSE)**.
