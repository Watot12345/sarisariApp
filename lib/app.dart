import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'core/services/home_widget_service.dart';
import 'core/services/update_service.dart';
import 'core/strings.dart';
import 'core/theme/app_theme.dart';
import 'features/home/providers/home_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/navigation/navigation_provider.dart';
import 'features/products/providers/product_provider.dart';
import 'features/products/screens/products_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/sell/providers/cart_provider.dart';
import 'features/sell/screens/sell_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/utang/providers/utang_provider.dart';
import 'features/utang/screens/utang_screen.dart';

import 'core/localization/language_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/gamification/gamification_provider.dart';
import 'features/gamification/screens/store_avatar_screen.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/onboarding/screens/policy_consent_screen.dart';

/// Root Application Widget with Provider injection and Theme configuration.
class TindahanApp extends StatelessWidget {
  const TindahanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => UtangProvider()),
      ],
      child: Builder(
        builder: (context) {
          final themeProv = context.watch<ThemeProvider>();
          final onboardingProv = context.watch<OnboardingProvider>();

          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProv.themeMode,
            scrollBehavior: const MobileAppScrollBehavior(),
            home: onboardingProv.isLoading
                ? const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : onboardingProv.isPolicyAccepted
                    ? const AppNavigationShell()
                    : const PolicyConsentScreen(),
            routes: {
              '/settings': (context) => const SettingsScreen(),
              '/policy': (context) => const PolicyConsentScreen(),
              '/gamification': (context) => const StoreAvatarScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Custom ScrollBehavior that completely suppresses desktop/web scrollbars
/// and enables mobile-style touch and drag scrolling with mouse/trackpad.
class MobileAppScrollBehavior extends MaterialScrollBehavior {
  const MobileAppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Return child unwrapped so no desktop/web scrollbar thumb or track is rendered
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

/// 5-Tab Navigation Shell with Prominent Center 'Sell' Action Button.
class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  StreamSubscription<Uri?>? _widgetSub;
  bool _isMaintenanceLocked = false;
  RemoteAppStatus? _remoteStatus;
  final Set<String> _dismissedAnnouncementIds = {};

  final List<Widget> _screens = const [
    HomeScreen(),
    ProductsScreen(),
    SellScreen(),
    UtangScreen(),
    ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    HomeWidgetService.getInitiallyLaunchedUri().then((uri) {
      if (mounted && uri != null) {
        context.read<NavigationProvider>().handleUri(uri);
      }
    });

    _widgetSub = HomeWidgetService.widgetClicked.listen((uri) {
      if (mounted && uri != null) {
        context.read<NavigationProvider>().handleUri(uri);
      }
    });

    // Initialize local push notification service
    NotificationService.instance.initialize();
    NotificationService.instance.requestPermissions();

    // Check remote GitHub status (maintenance mode, announcements, updates)
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkRemoteAppStatus();
      });
    }
  }

  Future<void> _checkRemoteAppStatus() async {
    try {
      final result = await UpdateService().checkForUpdate();
      if (!mounted) return;

      setState(() {
        _isMaintenanceLocked = result.maintenanceMode;
        _remoteStatus = result.remoteStatus;
      });

      if (result.maintenanceMode) return;

      final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;

      // 1. Show Update Dialog (blocking if forceUpdate == true)
      if (result.hasUpdate && result.latestRelease != null) {
        final release = result.latestRelease!;
        final force = result.forceUpdate;
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: !force,
          builder: (ctx) => PopScope(
            canPop: !force,
            child: AlertDialog(
              icon: const Icon(
                Icons.system_update_rounded,
                color: AppTheme.primaryGreen,
                size: 44,
              ),
              title: Text(
                force
                    ? (isTl ? 'Kailangang Mag-update' : 'Required Update Available')
                    : (isTl ? 'May Bagong Update!' : 'New Update Available!'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'v${result.currentVersion} → v${release.version}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (release.changelog.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: SingleChildScrollView(
                        child: Text(
                          release.changelog,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!force)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(isTl ? 'Mamaya' : 'Later'),
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(isTl ? 'I-download ang APK' : 'Download APK'),
                  onPressed: () {
                    UpdateService.downloadLatestApk(release.downloadUrl);
                    if (!force) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      }

      // 2. Show Remote Announcement if active
      final ann = result.remoteStatus?.announcement;
      if (mounted &&
          ann != null &&
          ann.active &&
          !_dismissedAnnouncementIds.contains(ann.id)) {
        _dismissedAnnouncementIds.add(ann.id);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(
              Icons.campaign_rounded,
              color: AppTheme.accentAmber,
              size: 42,
            ),
            title: Text(isTl ? ann.titleTl : ann.title),
            content: Text(isTl ? ann.messageTl : ann.message),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(isTl ? 'Sige, Salamat!' : 'Got It'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _widgetSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navProv = context.watch<NavigationProvider>();
    final cartProv = context.watch<CartProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;

    if (_isMaintenanceLocked) {
      final title = isTl
          ? (_remoteStatus?.maintenanceTitleTl ?? 'Pansamantalang Maintenance')
          : (_remoteStatus?.maintenanceTitle ?? 'Scheduled Maintenance');
      final msg = isTl
          ? (_remoteStatus?.maintenanceMessageTl ??
              'Pansamantalang naka-maintenance ang SariMe. Ligtas ang lahat ng data ng iyong tindahan sa iyong telepono.')
          : (_remoteStatus?.maintenanceMessage ??
              'SariMe is temporarily undergoing maintenance. All your store data on your phone remains 100% safe.');

      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.warningOrange.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.construction_rounded,
                      size: 56,
                      color: AppTheme.warningOrange,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _checkRemoteAppStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(isTl ? 'Subukan Muli' : 'Check Status Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: navProv.currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            height: 65,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedIndex: navProv.currentIndex,
            onDestinationSelected: (index) {
              HapticFeedback.selectionClick();
              navProv.setTab(index);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.storefront_outlined),
                selectedIcon: const Icon(Icons.storefront_rounded),
                label: isTl ? 'Tahanan' : AppStrings.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.inventory_2_outlined),
                selectedIcon: const Icon(Icons.inventory_2_rounded),
                label: isTl ? 'Paninda' : AppStrings.navProducts,
              ),
              // Center Emphasized Sell Tab with Glow Shadow
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cartProv.itemCount > 0,
                  label: Text('${cartProv.itemCount}'),
                  backgroundColor: AppTheme.dangerRed,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                label: isTl ? 'Benta' : AppStrings.navSell,
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: isTl ? 'Utang' : 'Credit',
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart_rounded),
                label: isTl ? 'Ulat' : AppStrings.navReports,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
