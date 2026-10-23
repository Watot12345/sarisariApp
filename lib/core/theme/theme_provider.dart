import 'package:flutter/material.dart';
import '../../data/repositories/settings_repository.dart';

/// Provider managing active ThemeMode (Light, Dark, System), Customized Container Colors,
/// and Store / Owner Profile settings backed by SQLite persistence.
class ThemeProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepo;
  ThemeMode _themeMode = ThemeMode.system;
  String _containerColorPreset = 'default';
  String _storeName = 'SariMe Store';
  String _ownerName = '';
  String _ownerPhone = '';
  String _ownerEmail = '';
  String _storeAddress = '';
  String _storeLogoPath = '';
  String _subscriptionTier = 'free';

  ThemeProvider({SettingsRepository? settingsRepo})
      : _settingsRepo = settingsRepo ?? SettingsRepository() {
    _loadPersistedTheme();
  }

  ThemeMode get themeMode => _themeMode;
  String get containerColorPreset => _containerColorPreset;
  String get storeName => _storeName.trim().isEmpty ? 'SariMe Store' : _storeName;
  String get ownerName => _ownerName;
  String get ownerPhone => _ownerPhone;
  String get ownerEmail => _ownerEmail;
  String get storeAddress => _storeAddress;
  String get storeLogoPath => _storeLogoPath;
  String get subscriptionTier => _subscriptionTier;
  bool get isPro => _subscriptionTier == 'pro';

  bool isDark(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final saved = await _settingsRepo.getSetting('theme_mode');
      if (saved == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }

      final preset = await _settingsRepo.getSetting('container_color_hex');
      if (preset != null && preset.isNotEmpty) {
        _containerColorPreset = preset;
      }

      final sName = await _settingsRepo.getSetting('store_name');
      if (sName != null && sName.trim().isNotEmpty) {
        _storeName = sName.trim();
      }

      _ownerName = (await _settingsRepo.getSetting('owner_name')) ?? '';
      _ownerPhone = (await _settingsRepo.getSetting('owner_phone')) ?? '';
      _ownerEmail = (await _settingsRepo.getSetting('owner_email')) ?? '';
      _storeAddress = (await _settingsRepo.getSetting('store_address')) ?? '';
      _storeLogoPath = (await _settingsRepo.getSetting('store_logo_path')) ?? '';
      _subscriptionTier = (await _settingsRepo.getSetting('subscription_tier')) ?? 'free';

      notifyListeners();
    } catch (_) {}
  }

  /// Updates active theme and saves preference to SQLite
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      await _settingsRepo.setSetting('theme_mode', mode.name);
    } catch (_) {}
  }

  /// Updates customized container color preset ('default', 'emerald', 'blue', 'purple', 'amber', 'rose')
  Future<void> setContainerColorPreset(String preset) async {
    _containerColorPreset = preset;
    notifyListeners();
    try {
      await _settingsRepo.setSetting('container_color_hex', preset);
    } catch (_) {}
  }

  /// Updates store & owner profile details and persists to SQLite
  Future<void> updateStoreProfile({
    String? storeName,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    String? storeAddress,
    String? storeLogoPath,
    String? subscriptionTier,
  }) async {
    if (storeName != null && storeName.trim().isNotEmpty) {
      _storeName = storeName.trim();
      await _settingsRepo.setSetting('store_name', _storeName);
    }
    if (ownerName != null) {
      _ownerName = ownerName.trim();
      await _settingsRepo.setSetting('owner_name', _ownerName);
    }
    if (ownerPhone != null) {
      _ownerPhone = ownerPhone.trim();
      await _settingsRepo.setSetting('owner_phone', _ownerPhone);
    }
    if (ownerEmail != null) {
      _ownerEmail = ownerEmail.trim();
      await _settingsRepo.setSetting('owner_email', _ownerEmail);
    }
    if (storeAddress != null) {
      _storeAddress = storeAddress.trim();
      await _settingsRepo.setSetting('store_address', _storeAddress);
    }
    if (storeLogoPath != null) {
      _storeLogoPath = storeLogoPath.trim();
      await _settingsRepo.setSetting('store_logo_path', _storeLogoPath);
    }
    if (subscriptionTier != null) {
      _subscriptionTier = subscriptionTier.trim();
      await _settingsRepo.setSetting('subscription_tier', _subscriptionTier);
    }
    notifyListeners();
  }

  /// 1-tap toggle between Light and Dark mode
  Future<void> toggleTheme(BuildContext context) async {
    final isCurrentlyDark = isDark(context);
    final newMode = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}
