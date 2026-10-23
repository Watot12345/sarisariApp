import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';

/// First-launch Privacy Policy, Permission Disclosures, and Terms of Use screen.
/// Defaults to English with a built-in English/Tagalog (EN/TL) language switch.
class PolicyConsentScreen extends StatefulWidget {
  const PolicyConsentScreen({super.key});

  @override
  State<PolicyConsentScreen> createState() => _PolicyConsentScreenState();
}

class _PolicyConsentScreenState extends State<PolicyConsentScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfAlreadyAtBottom();
    });
  }

  void _checkIfAlreadyAtBottom() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 20) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _hasScrolledToBottom) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 24) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _showFullPolicyDialog(BuildContext context, {required bool isTl}) {
    final dialogScrollCtrl = ScrollController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.policy_rounded, color: Color(0xFF059669)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isTl ? 'Patakaran sa Privacy' : 'Privacy Policy & Offline Terms',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          controller: dialogScrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Local Data Ownership & Privacy (RA 10173 / GDPR)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                isTl
                    ? 'Lahat ng detalye ng iyong tindahan, paninda, benta, at listahan ng utang ay naka-save lamang sa lokal na SQLite database sa iyong telepono. Walang personal o pinansyal na data ng tindahan ang kinokolekta o ipinapadala sa anumang server.'
                    : 'All store inventory, sales transactions, profit reports, and customer credit ledger records are stored locally in an on-device SQLite database. Zero store or customer data is collected or transmitted to external servers.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                '2. Camera Access (android.permission.CAMERA)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                isTl
                    ? 'Ginagamit lamang ang camera sa live viewfinder para basahin ang mga barcode ng paninda. Hindi ito nag-a-upload ng litrato o video sa labas ng iyong telepono.'
                    : 'The camera is used strictly in the live viewfinder to scan product barcodes and attach local product images. No photos or videos leave your device.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                '3. Update & Status Check (android.permission.INTERNET)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                isTl
                    ? 'Ginagamit lamang ang internet kapag nagche-check ng bagong APK update o status mula sa opisyal na GitHub Releases.'
                    : 'Internet access is used strictly to check GitHub Releases and GitHub Pages for APK version updates, announcements, and maintenance status.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                '4. User Data Deletion & Local Backup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                isTl
                    ? 'Ikaw ang 100% na may-ari ng iyong data. Maaari kang mag-export ng backup o magbura ng lahat ng data anumang oras sa Settings > Reset All Store Data.'
                    : 'You own 100% of your data. You can export a backup or permanently erase all records anytime via Settings > Reset All Store Data.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                '5. As-Is Software & Non-BIR Fiscal Logbook Disclaimer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                isTl
                    ? 'Ang SariMe ay ibinibigay nang "AS IS" bilang digital logbook helper para sa maliliit na tindahan at hindi kapalit ng BIR-accredited fiscal POS machine.'
                    : 'SariMe is provided "AS IS" as a digital logbook aid for micro-retailers and does not replace official BIR-accredited fiscal POS machines where required by law.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (mounted) setState(() => _hasScrolledToBottom = true);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(isTl ? 'Naiintindihan Ko' : 'I Understand'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onboardingProv = context.read<OnboardingProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Language Toggle Row (EN / TL)
              if (langProv != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      langProv.toggleLanguage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate_rounded, size: 14, color: AppTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Text(
                            isTl ? 'Tagalog (TL)' : 'English (EN)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // App Icon & Brand Emblem
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 46,
                      color: AppTheme.accentAmber,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title
              const Center(
                child: Text(
                  'SariMe',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.offline_bolt_rounded, size: 14, color: AppTheme.primaryGreen),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '100% Offline POS & Utang Ledger',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: Text(
                  isTl
                      ? 'Bago simulan ang pagpapatakbo ng tindahan, mangyaring basahin at kumpirmahin ang patakaran sa privacy at mga gagamiting pahintulot ng iyong telepono:'
                      : 'Before starting your store, please review and confirm our offline privacy policy and device permission disclosures:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 1. Zero Internet Guarantee Card
              _buildTrustCard(
                context,
                icon: Icons.shield_rounded,
                iconColor: AppTheme.primaryGreen,
                title: isTl
                    ? '100% Offline & Pribado (Zero Internet)'
                    : '100% Offline & Private (Zero Internet)',
                subtitle: isTl
                    ? 'Walang internet permission ang app na ito. Ang iyong benta, kita, at listahan ng utang ay LIGTAS na nananatili sa loob lamang ng iyong telepono. Walang cloud o server.'
                    : 'This app has zero internet permissions. Your sales, profit, and utang records stay safely on your phone with no cloud or external servers.',
              ),

              const SizedBox(height: 10),

              // 2. Camera Card
              _buildTrustCard(
                context,
                icon: Icons.qr_code_scanner_rounded,
                iconColor: AppTheme.accentAmber,
                title: isTl
                    ? 'Kamera (Camera Access)'
                    : 'Camera Access (Barcode Scanner)',
                subtitle: isTl
                    ? 'Ginagamit lamang para i-scan ang mga barcode ng paninda (gamit ang mobile_scanner). Hinding-hindi kumukuha, nagse-save, o nag-a-upload ng litrato o video.'
                    : 'Used strictly for scanning product barcodes live. It never captures, saves, or uploads photos or videos.',
              ),

              const SizedBox(height: 10),

              // 3. Microphone Card
              _buildTrustCard(
                context,
                icon: Icons.mic_rounded,
                iconColor: const Color(0xFF0284C7),
                title: isTl
                    ? 'Mikropono (Microphone Access)'
                    : 'Microphone Access (Voice Restock)',
                subtitle: isTl
                    ? 'Ginagamit lamang para sa mabilis na boses o voice restock (hal. "Dagdag 10 Coke"). Pinoproseso ang boses nang lokal sa phone at hindi inirerekord o ipinapadala saanman.'
                    : 'Used only for on-device voice commands (e.g., "Add 10 Coke"). Voice audio is processed locally on your phone and never recorded or transmitted.',
              ),

              const SizedBox(height: 10),

              // 4. Storage Card
              _buildTrustCard(
                context,
                icon: Icons.save_alt_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: isTl
                    ? 'Lokal na Storage at Backup'
                    : 'Local Storage & Backup',
                subtitle: isTl
                    ? 'Ikaw ang buong may-ari ng iyong tindahan. Maaari kang mag-export ng backup file sa iyong sariling SD card o telepono anumang oras.'
                    : 'You own 100% of your store data. You can export or restore a backup file on your phone anytime.',
              ),

              const SizedBox(height: 16),

              // Link to read full policy
              Center(
                child: TextButton.icon(
                  onPressed: () => _showFullPolicyDialog(context, isTl: isTl),
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: Text(
                    isTl
                        ? 'Basahin ang Buong Patakaran sa Privacy'
                        : 'Read Full Privacy Policy',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Scroll-down prompt if not yet at bottom
              if (!_hasScrolledToBottom && !_agreed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                        );
                      }
                      setState(() => _hasScrolledToBottom = true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.accentAmber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isTl
                                  ? 'Mag-scroll pababa hanggang dulo para ma-check ang pagsang-ayon.'
                                  : 'Scroll down to the bottom first to enable the agreement checkbox.',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Agreement Checkbox (Disabled before scroll-to-bottom AND locked/disabled after checking)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2438) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _agreed ? AppTheme.primaryGreen : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    value: _agreed,
                    activeColor: AppTheme.primaryGreen,
                    title: Text(
                      isTl
                          ? 'Nauunawaan at tinatanggap ko ang Patakaran sa Privacy at Offline Terms ng SariMe.'
                          : 'I understand and accept the SariMe Privacy Policy and Offline Terms.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (!_hasScrolledToBottom && !_agreed)
                            ? theme.colorScheme.onSurface.withOpacity(0.45)
                            : null,
                      ),
                    ),
                    subtitle: _agreed
                        ? Text(
                            isTl ? '✓ Nakumpirma at naka-lock na ang pagsang-ayon' : '✓ Agreement confirmed & locked',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          )
                        : null,
                    // Disabled before scrolling to bottom, and locked/disabled once checked!
                    onChanged: (!_hasScrolledToBottom || _agreed)
                        ? null
                        : (val) {
                            HapticFeedback.selectionClick();
                            if (val == true) {
                              setState(() => _agreed = true);
                            }
                          },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Accept Button
              ElevatedButton.icon(
                onPressed: !_agreed
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await onboardingProv.acceptPolicy();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isTl
                                    ? 'Maligayang pagdating sa SariMe! Handa na ang iyong tindahan.'
                                    : 'Welcome to SariMe! Your store is ready.',
                              ),
                              backgroundColor: AppTheme.primaryGreen,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  isTl ? 'Sumasang-ayon Ako at Magsimula' : 'I Agree & Start Store',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF263345) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.65),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
