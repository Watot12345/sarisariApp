import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/language_provider.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/utang_provider.dart';
import '../widgets/add_edit_customer_sheet.dart';
import '../widgets/customer_detail_sheet.dart';
import '../widgets/record_payment_sheet.dart';

/// Customer Credit (Utang) screen showing receivables, risk badges, and payment recorder.
class UtangScreen extends StatefulWidget {
  const UtangScreen({super.key});

  @override
  State<UtangScreen> createState() => _UtangScreenState();
}

class _UtangScreenState extends State<UtangScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showPaymentBottomSheet(BuildContext context, dynamic customer) {
    RecordPaymentSheet.show(context, customer);
  }

  Widget _buildRiskChip(String? level, bool isTl) {
    Color bg;
    Color fg;
    String label;

    switch (level) {
      case 'low':
        bg = AppTheme.primaryGreen.withOpacity(0.12);
        fg = AppTheme.primaryGreen;
        label = isTl ? 'Maaasahan (Good)' : AppStrings.riskLow;
        break;
      case 'medium':
        bg = AppTheme.warningOrange.withOpacity(0.15);
        fg = AppTheme.warningOrange;
        label = isTl ? 'Katamtaman (Med)' : AppStrings.riskMedium;
        break;
      case 'high':
        bg = AppTheme.dangerRed.withOpacity(0.12);
        fg = AppTheme.dangerRed;
        label = isTl ? 'Mataas na Panganib' : AppStrings.riskHigh;
        break;
      default:
        bg = Colors.grey.withOpacity(0.15);
        fg = Colors.grey[700]!;
        label = isTl ? 'Bagong Suki' : AppStrings.riskNew;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final utangProv = context.watch<UtangProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;
    final customers = utangProv.filteredCustomers;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTl ? 'Talaan ng Utang' : AppStrings.utangTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Total Balance Header Card
          Container(
            margin: const EdgeInsets.all(AppConstants.space16),
            padding: const EdgeInsets.all(AppConstants.space20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.dangerRed,
                  AppTheme.dangerRed.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dangerRed.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTl ? 'Kabuuang Pautang' : AppStrings.totalReceivables,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PriceText(
                      centavos: utangProv.totalReceivablesCents,
                      fontSize: 24,
                      color: Colors.white,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: utangProv.setSearchQuery,
              decoration: InputDecoration(
                hintText: isTl ? 'Maghanap ng suki sa pangalan o alyas...' : AppStrings.searchCustomerHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          utangProv.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: AppConstants.space12),

          // Customer List
          Expanded(
            child: customers.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    title: isTl ? 'Walang nahanap na suki' : 'No customers found',
                    description: isTl
                        ? 'Maglista ng mga regular na kapitbahay para masubaybayan ang utang.'
                        : 'Add regular neighborhood customers to start tracking utang.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppConstants.space16),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppConstants.space8),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => CustomerDetailSheet.show(context, customer),
                          child: Padding(
                            padding: const EdgeInsets.all(AppConstants.space16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                                  child: Text(
                                    customer.name.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppConstants.space12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.displayName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildRiskChip(customer.riskLevel, isTl),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    PriceText(
                                      centavos: customer.balanceCents,
                                      fontSize: 16,
                                      color: customer.balanceCents > 0
                                          ? AppTheme.dangerRed
                                          : theme.colorScheme.onSurface,
                                    ),
                                    const SizedBox(height: 4),
                                    if (customer.balanceCents > 0)
                                      SizedBox(
                                        height: 30,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            minimumSize: Size.zero,
                                            backgroundColor: AppTheme.primaryGreen,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            _showPaymentBottomSheet(context, customer);
                                          },
                                          child: Text(
                                            isTl ? 'Bayad' : 'Pay',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddEditCustomerSheet.show(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(isTl ? 'Bagong Suki' : AppStrings.addCustomer),
      ),
    );
  }
}
