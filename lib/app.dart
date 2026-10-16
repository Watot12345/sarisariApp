import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
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
import 'core/theme/theme_provider.dart';
import 'features/gamification/gamification_provider.dart';
import 'features/gamification/screens/store_avatar_screen.dart';
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

/// 5-Tab Navigation Shell with Prominent Center 'Sell' Action Button.
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({super.key});

  final List<Widget> _screens = const [
    HomeScreen(),
    ProductsScreen(),
    SellScreen(),
    UtangScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navProv = context.watch<NavigationProvider>();
    final cartProv = context.watch<CartProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;

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
                label: AppStrings.navUtang,
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
