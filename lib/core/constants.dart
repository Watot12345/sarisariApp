import 'package:flutter/material.dart';

/// Core UI and design system constants for Tindahan.
class AppConstants {
  AppConstants._();

  // App Metadata
  static const String appName = 'SariMe';
  static const String appVersion = '1.0.0';

  // Distribution & Release URLs (100% Free via GitHub Releases & GitHub Pages)
  static const String githubRepo = 'Watot12345/sarisariApp';
  static const String githubReleasesApiUrl = 'https://api.github.com/repos/Watot12345/sarisariApp/releases/latest';
  static const String latestApkDownloadUrl = 'https://github.com/Watot12345/sarisariApp/releases/latest/download/app-release.apk';
  static const String githubReleasesPageUrl = 'https://github.com/Watot12345/sarisariApp/releases';
  static const String landingPageUrl = 'https://watot12345.github.io/sarisariApp/';
  static const String remoteStatusUrl = 'https://watot12345.github.io/sarisariApp/status.json';
  static const String privacyPolicyUrl = 'https://watot12345.github.io/sarisariApp/privacy.html';

  // Sizing & Spacing (8-pt grid system)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Touch Targets (ergonomic for fast-paced store counters)
  static const double minTouchTarget = 48.0;
  static const double primaryButtonHeight = 56.0;

  // Shapes & Border Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;
  static const double radiusExtraLarge = 28.0;

  static const BorderRadius borderRadiusSmall = BorderRadius.all(Radius.circular(radiusSmall));
  static const BorderRadius borderRadiusMedium = BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius borderRadiusLarge = BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius borderRadiusTopSheet = BorderRadius.vertical(top: Radius.circular(radiusLarge));

  // Animation Durations
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animStandard = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);

  // Quick Cash Denominations (in centavos)
  static const List<int> quickCashDenominations = [
    2000,   // ₱20
    5000,   // ₱50
    10000,  // ₱100
    20000,  // ₱200
    50000,  // ₱500
    100000, // ₱1,000
  ];
}
