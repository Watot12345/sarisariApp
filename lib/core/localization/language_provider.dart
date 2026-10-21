import 'package:flutter/material.dart';
import '../../data/repositories/settings_repository.dart';
import '../strings.dart';

enum AppLanguage { english, tagalog }

/// Manages bilingual support for English and Tagalog (Filipino) across Tindahan.
class LanguageProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  AppLanguage _language;

  LanguageProvider({
    AppLanguage initialLanguage = AppLanguage.english,
    SettingsRepository? settingsRepo,
  })  : _language = initialLanguage,
        _settingsRepo = settingsRepo ?? SettingsRepository() {
    _loadPersistedLanguage();
  }

  AppLanguage get language => _language;
  bool get isTagalog => _language == AppLanguage.tagalog;
  bool get isEnglish => _language == AppLanguage.english;

  String get languageCode => isTagalog ? 'TL' : 'EN';
  String get languageDisplayName =>
      isTagalog ? 'Tagalog (Filipino)' : 'English';

  Future<void> _loadPersistedLanguage() async {
    try {
      final saved = await _settingsRepo.getSetting('app_language');
      if (saved == 'tagalog' && _language != AppLanguage.tagalog) {
        _language = AppLanguage.tagalog;
        notifyListeners();
      } else if (saved == 'english' && _language != AppLanguage.english) {
        _language = AppLanguage.english;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    try {
      await _settingsRepo.setSetting('app_language', lang.name);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    final next =
        _language == AppLanguage.english ? AppLanguage.tagalog : AppLanguage.english;
    await setLanguage(next);
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

  // App Updates & Releases Labels
  String get updatesSectionTitle => tr('App Updates & Download Page', 'Mga Update at Download Page');
  String get checkForUpdates => tr('Check for Updates', 'Maghanap ng Update');
  String get checkUpdatesSubtitle => tr('Check GitHub for new features and bug fixes', 'Tingnan ang GitHub para sa mga bagong feature at ayos');
  String get appUpToDate => tr('App is up to date', 'Nasa pinakabagong bersyon ka na');
  String get updateAvailableTitle => tr('New Version Available!', 'May Bagong Bersyon!');
  String get downloadApkNow => tr('Download APK Update', 'I-download ang Bagong APK');
  String get visitLandingPage => tr('Visit Download Website', 'Buksan ang Website ng App');
  String get offlineUpdateNotice => tr(
        'Unable to check for updates offline. Please connect to Wi-Fi or mobile data.',
        'Hindi makapaghanap ng update offline. Mangyaring kumonekta sa internet.',
      );
}
