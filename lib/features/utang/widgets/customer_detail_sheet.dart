import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/localization/language_provider.dart';
import '../../../data/models/customer.dart';
import '../../../domain/utang_ledger.dart';
import '../../../shared/widgets/price_text.dart';
import '../providers/utang_provider.dart';
import 'add_edit_customer_sheet.dart';
import 'record_payment_sheet.dart';

/// Bottom sheet displaying customer profile, risk level, credit limit,
/// action buttons (Bayad, Share Statement, Edit), and chronological ledger timeline.
class CustomerDetailSheet extends StatefulWidget {
  final Customer customer;

  const CustomerDetailSheet({super.key, required this.customer});

  static Future<void> show(BuildContext context, Customer customer) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerDetailSheet(customer: customer),
    );
  }

  @override
  State<CustomerDetailSheet> createState() => _CustomerDetailSheetState();
}

class _CustomerDetailSheetState extends State<CustomerDetailSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UtangProvider>().loadLedger(widget.customer.id);
      }
    });
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

  Future<void> _shareStatement(BuildContext context, Customer customer) async {
    final prov = context.read<UtangProvider>();
    final statement = prov.buildStatement(customer.id);

    try {
      await Share.share(statement, subject: '${customer.name} - Utang Statement');
    } catch (_) {
      // Fallback for widget tests / environments without platform share plugin
      await Clipboard.setData(ClipboardData(text: statement));
      if (context.mounted) {
        final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTl ? 'Nakopya ang talaan sa clipboard!' : 'Statement copied to clipboard!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final utangProv = context.watch<UtangProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;
    final customer = utangProv.customerById(widget.customer.id) ?? widget.customer;
    final entries = utangProv.ledgerFor(customer.id);
    final ledgerLines = UtangLedger.buildRunningLedger(entries);

    final availableCredit = customer.creditLimitCents > 0
        ? (customer.creditLimitCents - customer.balanceCents).clamp(0, customer.creditLimitCents)
        : 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Drag handle & top bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    child: Text(
                      customer.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (customer.phone != null && customer.phone!.isNotEmpty)
                          Text(
                            customer.phone!,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  _buildRiskChip(customer.riskLevel, isTl),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: isTl ? 'I-edit ang Suki' : 'Edit Customer',
                    onPressed: () {
                      Navigator.pop(context);
                      AddEditCustomerSheet.show(context, customer: customer);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Balance & Credit Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(isTl ? 'Kasalukuyang Utang:' : 'Current Balance (Utang):', style: const TextStyle(fontSize: 13)),
                            ),
                            PriceText(
                              centavos: customer.balanceCents,
                              fontSize: 18,
                              color: customer.balanceCents > 0
                                  ? AppTheme.dangerRed
                                  : AppTheme.primaryGreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(isTl ? 'Limit sa Utang:' : 'Credit Limit:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                            Text(
                              CurrencyFormatter.format(customer.creditLimitCents),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (customer.creditLimitCents > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(isTl ? 'Natitirang Pwedeng Utangin:' : 'Available Credit:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                              Text(
                                CurrencyFormatter.format(availableCredit),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: availableCredit > 0 ? AppTheme.primaryGreen : AppTheme.dangerRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sticky_note_2_outlined, size: 16, color: Colors.amber),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    customer.notes!,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons: Bayad & Share Statement
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const Key('customer_detail_bayad_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.payment, size: 18),
                          label: Text(isTl ? 'Bayad Utang' : 'Pay Utang'),
                          onPressed: customer.balanceCents <= 0
                              ? null
                              : () => RecordPaymentSheet.show(context, customer),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('customer_detail_share_btn'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: Text(isTl ? 'Ibahagi ang Talaan' : 'Share Statement'),
                          onPressed: () => _shareStatement(context, customer),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Ledger Timeline Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTl ? 'Kasaysayan ng Talaan' : 'Ledger History',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        isTl
                            ? '${ledgerLines.length} transaksyon'
                            : '${ledgerLines.length} transaction${ledgerLines.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Timeline Entries
                  if (ledgerLines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            isTl ? 'Walang utang history' : 'No credit history',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ledgerLines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        // Reverse chronological display so newest is on top
                        final line = ledgerLines[ledgerLines.length - 1 - index];
                        final entry = line.entry;
                        final isCharge = entry.isCharge;
                        final dateStr = entry.createdAt.length >= 16
                            ? entry.createdAt.substring(0, 16).replaceAll('T', ' ')
                            : entry.createdAt;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: (isCharge ? AppTheme.dangerRed : AppTheme.primaryGreen)
                                      .withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCharge ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                  color: isCharge ? AppTheme.dangerRed : AppTheme.primaryGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCharge
                                          ? (isTl ? 'Bagong Utang' : 'Utang Charge')
                                          : (isTl ? 'Bayad' : 'Payment'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (entry.note != null && entry.note!.isNotEmpty)
                                      Text(
                                        entry.note!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    Text(
                                      dateStr,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isCharge ? '+' : '-'}${CurrencyFormatter.format(entry.amountCents)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isCharge ? AppTheme.dangerRed : AppTheme.primaryGreen,
                                    ),
                                  ),
                                  Text(
                                    'Bal: ${CurrencyFormatter.format(line.runningBalanceCents)}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
