import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/localization/language_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

/// Animated startup splash gate that displays the branded SariMe background,
/// logo icon, logo name, and loading animation when opening the app.
class SariSplashGate extends StatefulWidget {
  final bool isLoadingData;
  final Widget child;

  const SariSplashGate({
    super.key,
    required this.isLoadingData,
    required this.child,
  });

  @override
  State<SariSplashGate> createState() => _SariSplashGateState();
}

class _SariSplashGateState extends State<SariSplashGate> {
  late bool _minimumSplashElapsed;
  Timer? _splashTimer;

  static bool get _isTestEnv {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isTestEnv) {
      _minimumSplashElapsed = true;
    } else {
      _minimumSplashElapsed = false;
      _splashTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _minimumSplashElapsed = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSplash = widget.isLoadingData || !_minimumSplashElapsed;
    if (_isTestEnv) {
      return showSplash ? const SariSplashScreen() : widget.child;
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: showSplash
          ? const SariSplashScreen(key: ValueKey('sari_splash_screen'))
          : KeyedSubtree(
              key: const ValueKey('sari_main_content'),
              child: widget.child,
            ),
    );
  }
}

/// Branded SariMe startup splash screen with emerald gradient background,
/// animated storefront logo icon, "SariMe" logo title, and loading bar.
class SariSplashScreen extends StatefulWidget {
  const SariSplashScreen({super.key});

  @override
  State<SariSplashScreen> createState() => _SariSplashScreenState();
}

class _SariSplashScreenState extends State<SariSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider?>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;
    final customStore = themeProv?.storeName.trim() ?? '';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF065F46),
              Color(0xFF064E3B),
              Color(0xFF022C22),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Subtle decorative ambient glow circles in background
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen.withOpacity(0.14),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -50,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentAmber.withOpacity(0.08),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),
                    // Animated Logo Icon Container
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF10B981),
                              Color(0xFF059669),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.28),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.45),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 52,
                            ),
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentAmber,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF064E3B),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Brand Logo Name + Store Subtitle
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          const Text(
                            AppConstants.appName,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            customStore.isNotEmpty &&
                                    customStore != AppConstants.defaultStoreName
                                ? customStore
                                : (isTl
                                    ? 'Tindahan Counter at Listahan ng Utang'
                                    : 'Smart Sari-Sari Store & Credit Ledger'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.82),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    // Animated Loading Bar & Status Text
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 160,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                backgroundColor: Colors.white.withOpacity(0.16),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF34D399),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isTl
                                ? 'Inihahanda ang iyong tindahan...'
                                : 'Loading your store counter...',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
