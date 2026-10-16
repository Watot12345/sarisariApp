import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../gamification/gamification_provider.dart';

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

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light (Maliwanag)';
      case ThemeMode.dark:
        return 'Dark (Madilim)';
      case ThemeMode.system:
        return 'System Default (Awtomatiko)';
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
                  subtitle: 'Standard English labels for store management',
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
                  subtitle: 'Tagalog para sa pang-araw-araw na tindahan',
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
                    const Text(
                      'Piliin ang Tema (Theme)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  title: 'Maliwanag (Light Mode)',
                  subtitle: 'Crisp porcelain surface with vivid emerald green',
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
                  title: 'Madilim (Dark Mode)',
                  subtitle: 'Deep obsidian surfaces, easy on the eyes at night',
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
                  title: 'Kagustuhan ng Telepono (System Default)',
                  subtitle: 'Awtomatikong susunod sa operating system ng device',
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
              subtitle: const Text('Barangay 12, Caloocan City'),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store profile editing will connect in Phase 10!')),
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
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(lang.themeModeLabel),
                  subtitle: Text(_getThemeName(themeProv.themeMode)),
                  trailing: const Icon(Icons.chevron_right),
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
                      SnackBar(content: Text(val ? 'PIN Lock enabled' : 'PIN Lock disabled')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space20),

          // Backup & Data
          Text(
            'Data & Offline Backup',
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
                  title: const Text('Export Backup (JSON)'),
                  subtitle: const Text('Save a copy to your phone or share via Bluetooth'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Full database export will be enabled in Phase 10!')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Restore from Backup'),
                  subtitle: const Text('Restore previous store inventory and ledger'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Database restore will be enabled in Phase 10!')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space20),

          // Privacy Policy & Legal Disclosures
          Text(
            'Privacy & Permissions',
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
              title: const Text('Patakaran sa Privacy (Privacy Policy)'),
              subtitle: const Text('100% Offline Guarantee, Camera, Mic, at Data Safety'),
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
