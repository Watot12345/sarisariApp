import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/customer.dart';
import '../providers/utang_provider.dart';

/// Bottom sheet form to add a new customer or edit an existing one.
class AddEditCustomerSheet extends StatefulWidget {
  final Customer? customer;

  const AddEditCustomerSheet({super.key, this.customer});

  static Future<void> show(BuildContext context, {Customer? customer}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditCustomerSheet(customer: customer),
    );
  }

  @override
  State<AddEditCustomerSheet> createState() => _AddEditCustomerSheetState();
}

class _AddEditCustomerSheetState extends State<AddEditCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nickCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _limitCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  bool get _isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _nickCtrl = TextEditingController(text: c?.nickname ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _limitCtrl = TextEditingController(
      text: ((c?.creditLimitCents ?? 50000) / 100).toStringAsFixed(2),
    );
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nickCtrl.dispose();
    _phoneCtrl.dispose();
    _limitCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final prov = context.read<UtangProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final limitCents = CurrencyFormatter.parsePesosToCentavos(_limitCtrl.text);

    bool ok;
    if (_isEditing) {
      ok = await prov.updateCustomer(
        widget.customer!.copyWith(
          name: _nameCtrl.text.trim(),
          nickname: _nickCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          creditLimitCents: limitCents,
          notes: _notesCtrl.text.trim(),
        ),
      );
    } else {
      final id = await prov.addCustomer(
        name: _nameCtrl.text,
        nickname: _nickCtrl.text,
        phone: _phoneCtrl.text,
        creditLimitCents: limitCents,
        notes: _notesCtrl.text,
      );
      ok = id != null;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Updated ${_nameCtrl.text.trim()}'
                : 'Added ${_nameCtrl.text.trim()} to customers',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } else if (prov.errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(prov.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Customer' : 'New Customer',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('customer_name_field'),
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('customer_nickname_field'),
                  controller: _nickCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alias / Nickname (e.g. Aling Nena)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('customer_phone_field'),
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('customer_limit_field'),
                  controller: _limitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Credit Limit (₱)',
                    prefixText: '₱ ',
                    helperText: 'A warning shows in Sell when this is exceeded',
                  ),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return null;
                    if (double.tryParse(t) == null) return 'Enter a valid amount';
                    if (double.parse(t) < 0) return 'Cannot be negative';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (e.g. pays every Friday)',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  key: const Key('save_customer_btn'),
                  onPressed: _saving ? null : _save,
                  child: Text(_isEditing ? 'Save Changes' : 'Save Customer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
