import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/db/app_database.dart';
import '../../gamification/gamification_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../notifications/widgets/notifications_sheet.dart';
import '../../products/providers/product_provider.dart';
import '../../sell/providers/cart_provider.dart';
import '../../utang/providers/utang_provider.dart';
import '../../../core/services/update_service.dart';

import '../widgets/home_widget_preview_card.dart';

/// Settings screen for store profile, theme mode, language, gamification goals, PIN security, and offline backups.
class SettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  final ThemeMode currentThemeMode;

  const SettingsScreen({
    super.key,
    this.onThemeModeChanged,
    this.currentThemeMode = ThemeMode.system,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pinLockEnabled = false;
  String _storeName = 'SariMe Store';
  bool _checkingUpdate = false;
  final UpdateService _updateService = UpdateService();

  Future<void> _checkForUpdates(BuildContext context, LanguageProvider lang) async {
    setState(() => _checkingUpdate = true);
    try {
      final result = await _updateService.checkForUpdate();
      if (!context.mounted) return;

      if (result.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.offlineUpdateNotice),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
        return;
      }

      if (result.hasUpdate && result.latestRelease != null) {
        final release = result.latestRelease!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.system_update_rounded, color: AppTheme.primaryGreen, size: 44),
            title: Text(lang.updateAvailableTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lang.tr('Current version', 'Kasalukuyang bersyon')}: v${result.currentVersion}\n${lang.tr('Latest version', 'Bagong bersyon')}: v${release.version}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (release.changelog.isNotEmpty) ...[
                  Text(
                    lang.tr('What\'s new:', 'Mga pagbabago:'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Text(
                        release.changelog,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  lang.tr(
                    'Download the official APK file directly to install the update.',
                    'I-download ang bagong APK file upang mai-update ang app.',
                  ),
                  style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(lang.tr('Later', 'Mamaya')),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  UpdateService.downloadLatestApk(release.downloadUrl);
                },
                label: Text(lang.downloadApkNow),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${lang.appUpToDate} (v${AppConstants.appVersion})'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update check: $e')),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showEditStoreNameDialog(BuildContext context, LanguageProvider lang) {
    final ctrl = TextEditingController(text: _storeName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('Edit Store Name', 'Palitan ang Pangalan ng Tindahan')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: lang.tr('Store Name', 'Pangalan ng Tindahan'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.tr('Cancel', 'Kanselahin')),
          ),
          ElevatedButton(
            onPressed: () {
              final nextName = ctrl.text.trim();
              if (nextName.isNotEmpty) {
                setState(() => _storeName = nextName);
              }
              Navigator.pop(ctx);
            },
            child: Text(lang.tr('Save', 'I-save')),
          ),
        ],
      ),
    );
  }

  void _confirmResetAllData(BuildContext context, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('Reset All Store Data?', 'I-reset ang Lahat ng Data?')),
        content: Text(
          lang.tr(
            'This will permanently clear all products, customer utang ledgers, and sales records so your store starts completely fresh.',
            'Buburahin nito ang lahat ng paninda, listahan ng utang, at benta upang magsimula nang malinis ang iyong tindahan.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.tr('Cancel', 'Kanselahin')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AppDatabase.instance.resetAllData();
              if (!context.mounted) return;
              context.read<ProductProvider?>()?.clearAll();
              context.read<UtangProvider?>()?.clearAll();
              context.read<CartProvider?>()?.clearCart();
              context.read<NotificationProvider?>()?.clearAll();
              await context.read<HomeProvider?>()?.loadDashboard();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    lang.tr(
                      'All store data has been reset to a clean slate.',
                      'Na-reset na ang lahat ng data ng tindahan.',
                    ),
                  ),
                ),
              );
            },
            child: Text(lang.tr('Reset Data', 'I-reset')),
          ),
        ],
      ),
    );
  }

  String _getThemeName(ThemeMode mode, bool isTl) {
    switch (mode) {
      case ThemeMode.light:
        return isTl ? 'Maliwanag' : 'Light Mode';
      case ThemeMode.dark:
        return isTl ? 'Madilim' : 'Dark Mode';
      case ThemeMode.system:
        return isTl ? 'Kagustuhan ng Telepono' : 'System Default';
    }
  }

  void _showLanguageSelectorSheet(BuildContext context) {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.tr('Select Language', 'Piliin ang Wika'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildThemeOption(
                  ctx,
                  title: 'English',
                  subtitle: lang.tr(
                    'Standard English labels across the entire app',
                    'Pamantayang Ingles sa buong app',
                  ),
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF059669),
                  isSelected: lang.isEnglish,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    lang.setLanguage(AppLanguage.english);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 10),
                _buildThemeOption(
                  ctx,
                  title: 'Tagalog (Filipino)',
                  subtitle: lang.tr(
                    'Natural Filipino labels across the entire app',
                    'Likas na Tagalog para sa buong tindahan',
                  ),
                  icon: Icons.translate_rounded,
                  iconColor: const Color(0xFFD97706),
                  isSelected: lang.isTagalog,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    lang.setLanguage(AppLanguage.tagalog);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDailyGoalSheet(BuildContext context) {
    final gameProv = context.read<GamificationProvider>();
    final lang = context.read<LanguageProvider>();
    final options = [50000, 100000, 200000, 500000]; // ₱500, ₱1,000, ₱2,000, ₱5,000
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.tr('Daily Sales Goal', 'Target Benta Araw-araw'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...options.map((cents) {
                    final pesos = (cents / 100).toStringAsFixed(0);
                    final isSelected = gameProv.dailySalesGoalCents == cents;
                    return ListTile(
                      leading: Icon(
                        Icons.emoji_events_rounded,
                        color: isSelected ? const Color(0xFFD97706) : null,
                      ),
                      title: Text(
                        '₱$pesos / ${lang.tr("day", "araw")}',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF059669))
                          : null,
                      onTap: () {
                        gameProv.setDailySalesGoalCents(cents);
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThemeSelectorSheet(BuildContext context) {
    final themeProv = context.read<ThemeProvider>();
    final lang = context.read<LanguageProvider>();
    final isTl = lang.isTagalog;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final current = themeProv.themeMode;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.tr('Select Theme', 'Piliin ang Tema'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildThemeOption(
                  ctx,
                  title: isTl ? 'Maliwanag' : 'Light Mode',
                  subtitle: isTl
                      ? 'Maliwanag na kulay na may sariwang emerald green'
                      : 'Crisp porcelain surface with vivid emerald green',
                  icon: Icons.light_mode_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  isSelected: current == ThemeMode.light,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeProv.setThemeMode(ThemeMode.light);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 10),
                _buildThemeOption(
                  ctx,
                  title: isTl ? 'Madilim' : 'Dark Mode',
                  subtitle: isTl
                      ? 'Malalim na madilim na kulay, banayad sa mata sa gabi'
                      : 'Deep obsidian surfaces, easy on the eyes at night',
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFF818CF8),
                  isSelected: current == ThemeMode.dark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeProv.setThemeMode(ThemeMode.dark);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 10),
                _buildThemeOption(
                  ctx,
                  title: isTl ? 'Kagustuhan ng Telepono' : 'System Default',
                  subtitle: isTl
                      ? 'Awtomatikong susunod sa operating system ng device'
                      : 'Follows your device operating system theme automatically',
                  icon: Icons.brightness_auto_rounded,
                  iconColor: const Color(0xFF10B981),
                  isSelected: current == ThemeMode.system,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeProv.setThemeMode(ThemeMode.system);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? iconColor.withOpacity(0.12) : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? iconColor : theme.colorScheme.onSurface.withOpacity(0.08),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? iconColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProv = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final gameProv = context.watch<GamificationProvider>();
    final isTl = lang.isTagalog;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.navSettings, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.space16),
        children: [
          // Store Info Card
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.storefront_rounded, color: theme.colorScheme.primary),
              ),
              title: Text(_storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lang.tr('Neighborhood Sari-Sari Store', 'Tindahan sa Barangay')),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditStoreNameDialog(context, lang),
              ),
            ),
          ),

          const SizedBox(height: AppConstants.space20),

          // Preferences Header
          Text(
            lang.preferences,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(lang.languageLabel),
                  subtitle: Text(lang.languageSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showLanguageSelectorSheet(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.emoji_events_outlined),
                  title: Text(lang.dailyGoalTitle),
                  subtitle: Text('₱${(gameProv.dailySalesGoalCents / 100).toStringAsFixed(0)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showDailyGoalSheet(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      themeProv.isDark(context)
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      key: ValueKey<bool>(themeProv.isDark(context)),
                      color: themeProv.isDark(context)
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  title: Text(lang.themeModeLabel),
                  subtitle: Text(_getThemeName(themeProv.themeMode, isTl)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => RotationTransition(
                            turns: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Icon(
                            themeProv.isDark(context)
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            key: ValueKey<bool>(themeProv.isDark(context)),
                            color: themeProv.isDark(context)
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        tooltip: themeProv.isDark(context)
                            ? 'Switch to Light Mode'
                            : 'Switch to Dark Mode',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          themeProv.toggleTheme(context);
                        },
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showThemeSelectorSheet(context);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.lock_outline),
                  title: Text(lang.ownerPinLockLabel),
                  subtitle: Text(lang.ownerPinLockSub),
                  value: _pinLockEnabled,
                  onChanged: (val) {
                    setState(() => _pinLockEnabled = val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          val
                              ? lang.tr('PIN Lock enabled', 'Naka-enable na ang PIN Lock')
                              : lang.tr('PIN Lock disabled', 'Naka-disable na ang PIN Lock'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space20),

          // Android Home Screen Widget
          const HomeWidgetPreviewCard(),

          const SizedBox(height: AppConstants.space20),

          // Push Notifications & Alerts
          Text(
            lang.tr('Notifications & Alerts', 'Mga Alerto at Notipikasyon'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings_notifications_tile'),
                  leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF6366F1)),
                  title: Text(lang.tr('Store Notifications Center', 'Sentro ng mga Alerto')),
                  subtitle: Text(
                    lang.tr(
                      'View recent low stock alerts and sales milestones',
                      'Tingnan ang mga paalala sa paubos na paninda at target',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    NotificationsSheet.show(context);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space20),

          // Backup & Data
          Text(
            lang.tr('Data & Offline Backup', 'Data at Offline Backup'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Color(0xFF059669)),
                  title: Text(lang.tr('Export Backup (JSON)', 'Mag-export ng Backup (JSON)')),
                  subtitle: Text(
                    lang.tr(
                      'Save a copy to your phone or share via Bluetooth',
                      'Mag-save ng kopya sa telepono o ibahagi sa Bluetooth',
                    ),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang.tr(
                            'Full database export will be enabled soon!',
                            'Magiging available ang buong backup export sa susunod na release!',
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB)),
                  title: Text(lang.tr('Restore from Backup', 'Ibalik mula sa Backup')),
                  subtitle: Text(
                    lang.tr(
                      'Restore previous store inventory and ledger',
                      'Ibalik ang nakaraang imbentaryo at talaan ng tindahan',
                    ),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang.tr(
                            'Database restore will be enabled soon!',
                            'Magiging available ang database restore sa susunod na release!',
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('settings_reset_all_data_tile'),
                  leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.dangerRed),
                  title: Text(
                    lang.tr('Reset All Store Data', 'I-reset ang Lahat ng Data'),
                    style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    lang.tr(
                      'Clear all products, customer utang, and sales history',
                      'Burahin ang lahat ng paninda, listahan ng utang, at benta',
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _confirmResetAllData(context, lang);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space20),

          // App Updates & Download Page (Option 1 + Option 3)
          Text(
            lang.updatesSectionTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings_check_update_tile'),
                  leading: const Icon(Icons.system_update_rounded, color: Color(0xFF2563EB)),
                  title: Text(lang.checkForUpdates),
                  subtitle: Text(lang.checkUpdatesSubtitle),
                  trailing: _checkingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'v${AppConstants.appVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                  onTap: _checkingUpdate ? null : () => _checkForUpdates(context, lang),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('settings_landing_page_tile'),
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF059669)),
                  title: Text(lang.visitLandingPage),
                  subtitle: Text(
                    lang.tr(
                      'Download website for other store owners',
                      'Website para sa pag-download ng ibang tindera',
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    UpdateService.openLandingPage();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded, color: Color(0xFF6B7280)),
                  title: Text(lang.tr('GitHub Releases', 'GitHub Releases')),
                  subtitle: Text(
                    lang.tr(
                      'Direct APK downloads and release notes',
                      'Direktang APK download at tala ng release',
                    ),
                  ),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    UpdateService.openReleasesPage();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space20),

          // Privacy Policy & Legal Disclosures
          Text(
            lang.tr('Privacy & Permissions', 'Privacy at Pahintulot'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF059669)),
              title: Text(lang.tr('Privacy Policy', 'Patakaran sa Privacy')),
              subtitle: Text(
                lang.tr(
                  '100% Offline Guarantee, Camera, and Data Safety',
                  '100% Offline Guarantee, Camera, at Kaligtasan ng Data',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pushNamed('/policy');
              },
            ),
          ),
          const SizedBox(height: AppConstants.space20),
        ],
      ),
    );
  }
}
