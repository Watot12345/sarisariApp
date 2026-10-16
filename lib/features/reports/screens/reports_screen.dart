import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../home/providers/home_provider.dart';
import '../../utang/providers/utang_provider.dart';

enum ReportTimeframe { day, week, month }

/// Reports & Business Analytics screen.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportTimeframe _timeframe = ReportTimeframe.day;

  final List<Map<String, dynamic>> _defaultTopSellers = const [
    {'name': 'Lucky Me Pancit Canton Kalamansi', 'qty': 42, 'revenueCents': 63000},
    {'name': 'Coca-Cola Mismo 290ml', 'qty': 38, 'revenueCents': 76000},
    {'name': 'Marlboro Red (Stick)', 'qty': 35, 'revenueCents': 35000},
    {'name': 'Kopiko Blanca 3-in-1', 'qty': 29, 'revenueCents': 40600},
    {'name': 'Piattos Cheese 85g', 'qty': 18, 'revenueCents': 68400},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeProv = context.watch<HomeProvider>();
    final utangProv = context.watch<UtangProvider>();
    final lang = context.watch<LanguageProvider>();
    final topSellers = homeProv.topSellers.isNotEmpty
        ? homeProv.topSellers
            .map((t) => {'name': t.name, 'qty': t.qty, 'revenueCents': t.revenueCents})
            .toList()
        : _defaultTopSellers;

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.reportsTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.space16),
        children: [
          // Timeframe Filter
          SegmentedButton<ReportTimeframe>(
            segments: [
              ButtonSegment(
                value: ReportTimeframe.day,
                label: Text(lang.tabDay),
              ),
              ButtonSegment(
                value: ReportTimeframe.week,
                label: Text(lang.tabWeek),
              ),
              ButtonSegment(
                value: ReportTimeframe.month,
                label: Text(lang.tabMonth),
              ),
            ],
            selected: {_timeframe},
            onSelectionChanged: (set) => setState(() => _timeframe = set.first),
          ),

          const SizedBox(height: AppConstants.space20),

          // Revenue & Profit Cards
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: lang.grossRevenue,
                  value: _timeframe == ReportTimeframe.day
                      ? homeProv.todaySalesCents
                      : _timeframe == ReportTimeframe.week
                          ? homeProv.weekSalesCents
                          : homeProv.monthSalesCents,
                  isMoney: true,
                  icon: Icons.attach_money_rounded,
                  iconColor: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: AppConstants.space12),
              Expanded(
                child: StatCard(
                  title: lang.netProfit,
                  value: _timeframe == ReportTimeframe.day
                      ? homeProv.todayProfitCents
                      : _timeframe == ReportTimeframe.week
                          ? homeProv.weekProfitCents
                          : homeProv.monthProfitCents,
                  isMoney: true,
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF1976D2),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.space24),

          // Best Sellers Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.topSellers,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space12),
                  const Divider(height: 1),
                  ...topSellers.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rank == 1
                                  ? Colors.amber.withOpacity(0.2)
                                  : theme.colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: rank == 1 ? Colors.amber[900] : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item['qty']} units sold',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PriceText(
                            centavos: item['revenueCents'] as int,
                            fontSize: 14,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppConstants.space16),

          // Utang Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.space16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: AppTheme.dangerRed),
                  ),
                  const SizedBox(width: AppConstants.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.unpaidCredit,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        PriceText(
                          centavos: utangProv.totalReceivablesCents,
                          fontSize: 18,
                          color: AppTheme.dangerRed,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
