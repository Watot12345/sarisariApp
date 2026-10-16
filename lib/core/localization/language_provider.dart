import 'package:flutter/material.dart';
import '../strings.dart';

enum AppLanguage { english, tagalog }

/// Manages bilingual support for English and Tagalog (Filipino) across Tindahan.
class LanguageProvider extends ChangeNotifier {
  AppLanguage _language;

  LanguageProvider({AppLanguage initialLanguage = AppLanguage.english})
      : _language = initialLanguage;

  AppLanguage get language => _language;
  bool get isTagalog => _language == AppLanguage.tagalog;
  bool get isEnglish => _language == AppLanguage.english;

  String get languageCode => isTagalog ? 'TL' : 'EN';
  String get languageDisplayName =>
      isTagalog ? 'Tagalog (Filipino)' : 'English';

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
  }

  void toggleLanguage() {
    _language =
        _language == AppLanguage.english ? AppLanguage.tagalog : AppLanguage.english;
    notifyListeners();
  }

  /// Translates between English and Tagalog strings based on active language.
  String tr(String en, String tl) => isTagalog ? tl : en;

  // Navigation & Common Labels
  String get navHome => tr(AppStrings.navHome, 'Tahanan');
  String get navSell => tr(AppStrings.navSell, 'Benta');
  String get navProducts => tr(AppStrings.navProducts, 'Paninda');
  String get navUtang => tr(AppStrings.navUtang, 'Utang');
  String get navReports => tr(AppStrings.navReports, 'Ulat');
  String get navSettings => tr(AppStrings.navSettings, 'Settings');

  // Home Dashboard Labels
  String get todaysSales => tr(AppStrings.todaySales, 'Benta Ngayon');
  String get estimatedProfit => tr(AppStrings.estProfit, 'Kita (Est.)');
  String get totalUtang => tr(AppStrings.totalUtang, 'Kabuuang Utang');
  String get itemsSold => tr(AppStrings.itemsSold, 'Nabentang Piraso');

  // Reports Labels
  String get reportsTitle => tr(AppStrings.reportsTitle, 'Ulat ng Negosyo');
  String get tabDay => tr(AppStrings.tabDay, 'Ngayon');
  String get tabWeek => tr(AppStrings.tabWeek, 'Linggo');
  String get tabMonth => tr(AppStrings.tabMonth, 'Buwan');
  String get grossRevenue => tr(AppStrings.grossRevenue, 'Kabuuang Benta');
  String get netProfit => tr(AppStrings.netProfit, 'Malinis na Kita (Est.)');
  String get topSellers => tr(AppStrings.topSellers, 'Pinakamabentang Paninda');

  // Settings Labels
  String get preferences => tr('Preferences', 'Kagustuhan');
  String get languageLabel => tr('Language', 'Wika (Language)');
  String get languageSubtitle => languageDisplayName;
  String get dailyGoalTitle => tr('Daily Sales Goal', 'Target Benta Ngayon');
  String get themeModeLabel => tr('Theme Mode', 'Tema (Theme Mode)');
  String get ownerPinLockLabel => tr('Owner PIN Lock', 'PIN Lock ng May-ari');
  String get ownerPinLockSub => tr(
        'Protect profit and cost prices from helpers',
        'Itago ang puhunan at kita mula sa bantay',
      );

  // Gamification Level Titles (plain text without emoji for clean assertions)
  String levelTitle(int level) {
    switch (level) {
      case 1:
        return tr('Starter Storekeeper', 'Baguhang Tindera');
      case 2:
        return tr('Hardworking Store', 'Masipag na Tindahan');
      case 3:
        return tr('Suki Favorite', 'Suki Magnet');
      case 4:
        return tr('Barangay Boss', 'Barangay Boss');
      default:
        return tr('Sari-Sari Legend', 'Alamat ng Sari-Sari');
    }
  }
}
