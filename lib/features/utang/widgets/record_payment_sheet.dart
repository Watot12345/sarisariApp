import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/customer.dart';
import '../../../domain/utang_ledger.dart';
import '../../../shared/widgets/price_text.dart';
import '../providers/utang_provider.dart';

/// Bottom sheet to record a full or partial utang payment.
/// Rule: amount must be > 0 and ≤ the customer's current balance.
class RecordPaymentSheet extends StatefulWidget {
  final Customer customer;

  const RecordPaymentSheet({super.key, required this.customer});

  static Future<bool?> show(BuildContext context, Customer customer) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordPaymentSheet(customer: customer),
    );
  }

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final TextEditingController _amountCtrl;
  String? _error;
  bool _saving = false;

  int get _balance => widget.customer.balanceCents;
  int get _payCents => CurrencyFormatter.parsePesosToCentavos(_amountCtrl.text);

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: (_balance / 100).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _setAmount(int cents) {
    setState(() {
      _amountCtrl.text = (cents / 100).toStringAsFixed(2);
      _error = null;
    });
  }

  Future<void> _confirm() async {
    final pay = _payCents;
    final err = UtangLedger.validatePayment(amountCents: pay, balanceCents: _balance);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() => _saving = true);
    final prov = context.read<UtangProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await prov.recordPayment(widget.customer.id, pay);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Payment of ${CurrencyFormatter.format(pay)} recorded for ${widget.customer.name}',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } else {
      setState(() => _error = prov.errorMessage ?? 'Could not record payment');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (_balance - _payCents).clamp(0, _balance);

    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.space20,
        right: AppConstants.space20,
        top: AppConstants.space20,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppConstants.space20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pay Utang: ${widget.customer.displayName}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Current Balance:')),
                  PriceText(centavos: _balance, fontSize: 18, color: AppTheme.dangerRed),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Quick Payment Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Full Balance'),
                    onPressed: () => _setAmount(_balance),
                  ),
                  for (final c in [5000, 10000, 20000])
                    if (c < _balance)
                      ActionChip(
                        label: Text(CurrencyFormatter.formatCompact(c)),
                        onPressed: () => _setAmount(c),
                      ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('payment_amount_field'),
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _error = null),
                decoration: InputDecoration(
                  labelText: 'Amount Paid (₱)',
                  prefixText: '₱ ',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Amount to Pay: ${CurrencyFormatter.format(_payCents)}  •  Remaining: ${CurrencyFormatter.format(remaining)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _confirm,
                child: const Text('Confirm Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
