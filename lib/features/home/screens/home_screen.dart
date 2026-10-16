import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/stock_badge.dart';
import '../../gamification/gamification_provider.dart';
import '../../gamification/screens/store_avatar_screen.dart';
import '../../gamification/widgets/animated_store_avatar.dart';
import '../../navigation/navigation_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../utang/providers/utang_provider.dart';
import '../providers/home_provider.dart';

/// Home Dashboard screen showing sales summary, quick actions, 7-day chart, and low-stock alerts.
/// Features a compact animated Avatar Emoticon button in the AppBar that opens StoreAvatarScreen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting({required bool isTagalog}) {
    final hour = DateTime.now().hour;
    if (hour < 12) return isTagalog ? AppStrings.greetingMorning : 'Good Morning!';
    if (hour < 18) return isTagalog ? AppStrings.greetingAfternoon : 'Good Afternoon!';
    return isTagalog ? AppStrings.greetingEvening : 'Good Evening!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeProv = context.watch<HomeProvider>();
    final utangProv = context.watch<UtangProvider>();
    final productProv = context.watch<ProductProvider>();
    final navProv = context.read<NavigationProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final gameProv = context.watch<GamificationProvider?>() ?? GamificationProvider();
    final isTl = langProv?.isTagalog ?? false;

    final todayFormatted = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    final lowStockItems = productProv.lowStockProducts;
    final xp = gameProv.calculateTotalXp(
      todaySalesCents: homeProv.todaySalesCents,
      itemsSoldToday: homeProv.itemsSoldToday,
      lowStockCount: lowStockItems.length,
    );
    final storeLevel = gameProv.getLevelFromXp(xp);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(isTagalog: isTl),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              todayFormatted,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          // Animated Avatar Emoticon button -> opens dedicated StoreAvatarScreen
          StoreAvatarAppBarButton(
            level: storeLevel,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StoreAvatarScreen()),
              );
            },
          ),
          if (langProv != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  langProv.toggleLanguage();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.translate_rounded, size: 14, color: AppTheme.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        langProv.languageCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Consumer<ThemeProvider>(
            builder: (context, themeProv, _) {
              final isDark = themeProv.isDark(context);
              return IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey<bool>(isDark),
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF0F172A),
                  ),
                ),
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  themeProv.toggleTheme(context);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.navSettings,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.space16),
        children: [
          // 2x2 Metric Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppConstants.space12,
            mainAxisSpacing: AppConstants.space12,
            childAspectRatio: 1.45,
            children: [
              StatCard(
                title: isTl ? 'Benta Ngayon' : AppStrings.todaySales,
                value: homeProv.todaySalesCents,
                isMoney: true,
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF2E7D32),
                onTap: () => navProv.openReports(),
              ),
              StatCard(
                title: isTl ? 'Kita (Est.)' : AppStrings.estProfit,
                value: homeProv.todayProfitCents,
                isMoney: true,
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF1976D2),
                onTap: () => navProv.openReports(),
              ),
              StatCard(
                title: isTl ? 'Nabenta' : AppStrings.itemsSold,
                value: homeProv.itemsSoldToday,
                isMoney: false,
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFFFF9800),
                onTap: () => navProv.openReports(),
              ),
              StatCard(
                title: isTl ? 'Kabuuang Utang' : AppStrings.totalUtang,
                value: utangProv.totalReceivablesCents,
                isMoney: true,
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFFD32F2F),
                onTap: () => navProv.openUtang(),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.space20),

          // Quick Action Buttons
          Text(
            isTl ? 'Mabilisang Aksyon' : AppStrings.quickActions,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.point_of_sale_rounded,
                  label: isTl ? 'Bagong Benta' : AppStrings.actionNewSale,
                  color: const Color(0xFF2E7D32),
                  onTap: () => navProv.openSell(),
                ),
              ),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.qr_code_scanner_rounded,
                  label: isTl ? 'I-scan' : AppStrings.actionScanBarcode,
                  color: const Color(0xFF0288D1),
                  onTap: () => navProv.openSell(),
                ),
              ),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.add_box_rounded,
                  label: isTl ? 'Dagdag Paninda' : AppStrings.actionAddProduct,
                  color: const Color(0xFF7B1FA2),
                  onTap: () => navProv.openProducts(),
                ),
              ),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.how_to_reg_rounded,
                  label: isTl ? 'Bayad Utang' : AppStrings.actionRecordPayment,
                  color: const Color(0xFFC2185B),
                  onTap: () => navProv.openUtang(),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.space24),

          // 7-Day Mini Sales Bar Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isTl ? 'Benta sa Nakaraang 7 Araw' : AppStrings.salesTrends7d,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isTl ? '1 Linggo' : 'Past Week',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space16),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: homeProv.last7DaysSales.map((point) {
                        // Max sales scale
                        const maxVal = 500000;
                        final double ratio = (point.salesCents / maxVal).clamp(0.1, 1.0);
                        final isToday = point.dayName == 'Today';

                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 80 * ratio,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primary.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                point.dayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.space24),

          // Low Stock Alert Horizontal Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${isTl ? "Paubos na Paninda" : AppStrings.lowStockAlerts} (${lowStockItems.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => navProv.openProducts(),
                child: Text(isTl ? 'Tingnan Lahat' : 'View All'),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space8),
          if (lowStockItems.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.space16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
                    const SizedBox(width: AppConstants.space12),
                    Expanded(
                      child: Text(
                        isTl
                            ? 'Kumpleto at sapat ang lahat ng paninda!'
                            : 'All inventory stocks are healthy!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: lowStockItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppConstants.space12),
                itemBuilder: (context, index) {
                  final item = lowStockItems[index];
                  return Container(
                    width: 230,
                    padding: const EdgeInsets.all(AppConstants.space12),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PriceText(centavos: item.priceCents, fontSize: 13),
                            const SizedBox(width: 6),
                            Flexible(
                              child: StockBadge(
                                stockQty: item.stockQty,
                                lowStockLevel: item.lowStockLevel,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              productProv.quickRestock(item.id, 10);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Restocked 10 pcs of ${item.name}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Text(
                              isTl ? '+10 Piraso' : 'Add 10 Pcs',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedScale(
      scale: _isPressed ? 0.93 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withOpacity(isDark ? 0.25 : 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(isDark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
