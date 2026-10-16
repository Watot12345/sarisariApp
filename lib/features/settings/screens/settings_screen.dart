import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../gamification/gamification_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../notifications/widgets/notifications_sheet.dart';

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
  final String _storeName = 'Aling Nena Tindahan';

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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        lang.tr(
                          'Store profile editing will connect soon!',
                          'Maa-update ang profile ng tindahan sa susunod na release!',
                        ),
                      ),
                    ),
                  );
                },
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
                const Divider(height: 1),
                ListTile(
                  key: const Key('settings_test_push_tile'),
                  leading: const Icon(Icons.cell_tower_rounded, color: AppTheme.primaryGreen),
                  title: Text(lang.tr('Test Push Notification', 'Subukan ang Push Notification')),
                  subtitle: Text(
                    lang.tr(
                      'Send test alert with custom icon to your phone status bar',
                      'Magpadala ng test alert na may icon sa status bar ng telepono',
                    ),
                  ),
                  trailing: ElevatedButton(
                    key: const Key('settings_quick_test_notif_btn'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      final notifProv = context.read<NotificationProvider?>();
                      await notifProv?.sendTestNotification(isTagalog: isTl);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              lang.tr(
                                'Test push notification dispatched!',
                                'Naipadala ang test alert sa iyong notification bar!',
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(isTl ? 'I-test' : 'Test'),
                  ),
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
