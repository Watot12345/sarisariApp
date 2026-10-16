import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/stock_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/barcode_scanner_sheet.dart';
import '../../products/providers/product_provider.dart';
import '../../products/widgets/add_edit_product_sheet.dart';
import '../../utang/providers/utang_provider.dart';
import '../providers/cart_provider.dart';

/// Point of Sale (POS) screen for high-speed counter checkout.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CartBottomSheetContent(),
    );
  }

  void _showSalesHistorySheet(BuildContext context) {
    context.read<CartProvider>().loadRecentSales();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SalesHistorySheetContent(),
    );
  }

  Future<void> _handleBarcodeScan(BuildContext context) async {
    final code = await BarcodeScannerSheet.show(context);
    if (code == null || code.trim().isEmpty || !context.mounted) return;

    final productProv = context.read<ProductProvider>();
    final cartProv = context.read<CartProvider>();
    final product = await productProv.findProductByBarcode(code);

    if (!context.mounted) return;

    if (product != null) {
      final added = cartProv.addToCart(product);
      if (added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${product.name} to cart'),
            backgroundColor: AppTheme.primaryGreen,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      } else if (cartProv.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cartProv.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Unregistered Barcode'),
          content: Text(
            'No product found with barcode "$code". Would you like to register it as a new product?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                AddEditProductSheet.show(context, initialBarcode: code);
              },
              child: const Text('Register Product'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productProv = context.watch<ProductProvider>();
    final cartProv = context.watch<CartProvider>();
    final products = productProv.filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navSell, style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Sales History',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showSalesHistorySheet(context);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: productProv.setSearchQuery,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchProductsHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                productProv.setSearchQuery('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.space8),
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  ),
                  child: IconButton(
                    key: const Key('sell_scan_barcode_btn'),
                    icon: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.primary),
                    tooltip: AppStrings.scanBarcode,
                    onPressed: () => _handleBarcodeScan(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: products.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No products match',
              description: 'Try searching another keyword or check category filters.',
              actionLabel: 'Clear Search',
              onAction: () {
                _searchCtrl.clear();
                productProv.setSearchQuery('');
              },
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.space16,
                AppConstants.space12,
                AppConstants.space16,
                100, // Extra space for floating cart bar
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppConstants.space12,
                mainAxisSpacing: AppConstants.space12,
                childAspectRatio: 0.95,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductGridTile(product: product);
              },
            ),
      bottomSheet: cartProv.items.isNotEmpty
          ? _FloatingCartBar(onTap: () => _showCartBottomSheet(context))
          : null,
    );
  }
}

class _ProductGridTile extends StatefulWidget {
  final dynamic product;

  const _ProductGridTile({required this.product});

  @override
  State<_ProductGridTile> createState() => _ProductGridTileState();
}

class _ProductGridTileState extends State<_ProductGridTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cartProv = context.watch<CartProvider>();
    final product = widget.product;

    // Check if item is already in cart
    final cartIndex = cartProv.items.indexWhere((it) => it.product.id == product.id);
    final inCartQty = cartIndex != -1 ? cartProv.items[cartIndex].qty : 0;
    final (catColor, catIcon) = AppTheme.getCategoryStyle(product.categoryName);
    final isOut = product.stockQty <= 0;

    return AnimatedScale(
      scale: _isPressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          final success = context.read<CartProvider>().addToCart(product);
          if (!success && cartProv.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(cartProv.errorMessage!),
                backgroundColor: theme.colorScheme.error,
                duration: const Duration(milliseconds: 1500),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: inCartQty > 0
                  ? AppTheme.primaryGreen
                  : isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
              width: inCartQty > 0 ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: inCartQty > 0
                    ? AppTheme.primaryGreen.withOpacity(0.12)
                    : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Category Chip
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: catColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // In-Cart Badge or Stock Badge
                    if (inCartQty > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'x$inCartQty',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      StockBadge(
                        stockQty: product.stockQty,
                        lowStockLevel: product.lowStockLevel,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isOut
                        ? theme.colorScheme.onSurface.withOpacity(0.5)
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: PriceText(centavos: product.priceCents, fontSize: 16),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isOut
                            ? theme.colorScheme.surfaceContainerHighest
                            : inCartQty > 0
                                ? AppTheme.primaryGreen
                                : theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        inCartQty > 0 ? Icons.check_rounded : Icons.add_rounded,
                        size: 16,
                        color: isOut
                            ? theme.colorScheme.onSurface.withOpacity(0.4)
                            : inCartQty > 0
                                ? Colors.white
                                : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingCartBar extends StatelessWidget {
  final VoidCallback onTap;

  const _FloatingCartBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cart = context.watch<CartProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.shopping_bag_rounded, color: AppTheme.primaryGreen, size: 22),
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${cart.items.length} uri ng paninda',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  PriceText(centavos: cart.totalCents, fontSize: 20),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(125, 46),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tingnan'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBottomSheetContent extends StatelessWidget {
  const _CartBottomSheetContent();

  void _openPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PaymentSheetContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartProv = context.watch<CartProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${AppStrings.cartTitle} (${cartProv.itemCount})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: cartProv.clearCart,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cartProv.items.isEmpty
                ? const EmptyState(
                    icon: Icons.remove_shopping_cart_outlined,
                    title: 'Your cart is empty',
                    description: 'Add products from the shelf grid to check out.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppConstants.space16),
                    itemCount: cartProv.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = cartProv.items[index];
                      return Dismissible(
                        key: ValueKey(item.product.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          final removed = cartProv.removeItem(item.product.id);
                          if (removed != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Removed ${removed.product.name}'),
                                action: SnackBarAction(
                                  label: AppStrings.undo,
                                  onPressed: () => cartProv.restoreItem(removed),
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${CurrencyFormatter.format(item.product.priceCents)} each',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                                  onPressed: () => cartProv.decrementQty(item.product.id),
                                ),
                                Text(
                                  '${item.qty}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 22),
                                  onPressed: () => cartProv.incrementQty(item.product.id),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            PriceText(centavos: item.subtotalCents, fontSize: 15),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(AppConstants.space16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        AppStrings.total,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      PriceText(centavos: cartProv.totalCents, fontSize: 22),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space16),
                  ElevatedButton(
                    onPressed: cartProv.items.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context); // Close cart sheet
                            _openPaymentSheet(context);
                          },
                    child: Text('${AppStrings.charge} (${CurrencyFormatter.format(cartProv.totalCents)})'),
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

class _PaymentSheetContent extends StatelessWidget {
  const _PaymentSheetContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartProv = context.watch<CartProvider>();
    final productProv = context.read<ProductProvider>();
    final utangProv = context.watch<UtangProvider>();

    return Container(
      padding: const EdgeInsets.all(AppConstants.space20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    AppStrings.paymentTitle,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.space12),

            // Segmented Cash vs Utang Mode
            SegmentedButton<PaymentMode>(
              segments: const [
                ButtonSegment(
                  value: PaymentMode.cash,
                  icon: Icon(Icons.payments_outlined),
                  label: Text(AppStrings.paymentCash),
                ),
                ButtonSegment(
                  value: PaymentMode.utang,
                  icon: Icon(Icons.menu_book_rounded),
                  label: Text(AppStrings.paymentUtang),
                ),
              ],
              selected: {cartProv.paymentMode},
              onSelectionChanged: (set) => cartProv.setPaymentMode(set.first),
            ),

            const SizedBox(height: AppConstants.space20),

            if (cartProv.paymentMode == PaymentMode.cash) ...[
              // Quick Cash Chips
              Text(
                AppStrings.cashTendered,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text(AppStrings.exactAmount),
                    backgroundColor: cartProv.cashReceivedCents == cartProv.totalCents
                        ? theme.colorScheme.primaryContainer
                        : null,
                    onPressed: cartProv.setExactCash,
                  ),
                  ...AppConstants.quickCashDenominations.map((cents) {
                    final isSelected = cartProv.cashReceivedCents == cents;
                    return ActionChip(
                      label: Text(CurrencyFormatter.formatCompact(cents)),
                      backgroundColor: isSelected ? theme.colorScheme.primaryContainer : null,
                      onPressed: () => cartProv.setCashReceived(cents),
                    );
                  }),
                ],
              ),
              const SizedBox(height: AppConstants.space20),

              // Change Calculation Box
              Container(
                padding: const EdgeInsets.all(AppConstants.space16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        AppStrings.change,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PriceText(
                      centavos: cartProv.changeCents,
                      fontSize: 24,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Utang Mode: Customer Selector
              Text(
                AppStrings.chooseCustomer,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: cartProv.selectedCustomer?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'Select registered customer',
                ),
                items: utangProv.allCustomers.map((cust) {
                  return DropdownMenuItem<int>(
                    value: cust.id,
                    child: Text(
                      '${cust.displayName} (Balance: ${CurrencyFormatter.format(cust.balanceCents)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    final cust = utangProv.allCustomers.firstWhere((c) => c.id == id);
                    cartProv.selectCustomer(cust);
                  }
                },
              ),
              if (cartProv.exceedsCreditLimit) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.warningOrange.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lampas sa credit limit ni ${cartProv.selectedCustomer?.displayName ?? "customer"}! Maaari pa ring ituloy ng may-ari.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warningOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppConstants.space24),

            ElevatedButton(
              onPressed: cartProv.canCheckout
                  ? () async {
                      final changeCents = cartProv.changeCents;
                      final isUtang = cartProv.paymentMode == PaymentMode.utang;
                      final customerName = cartProv.selectedCustomer?.displayName;

                      final success = await cartProv.completeSale(
                        productProvider: productProv,
                        utangProvider: utangProv,
                      );
                      if (context.mounted) {
                        if (success) {
                          Navigator.pop(context); // Close payment sheet
                          HapticFeedback.heavyImpact();
                          _showSaleSuccessDialog(
                            context,
                            changeCents: changeCents,
                            isUtang: isUtang,
                            customerName: customerName,
                          );
                        } else if (cartProv.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(cartProv.errorMessage!),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text(AppStrings.confirmSale),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaleSuccessDialog(
    BuildContext context, {
    required int changeCents,
    required bool isUtang,
    String? customerName,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Benta Matagumpay!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isUtang
                      ? 'Nai-record na sa utang ni $customerName'
                      : 'Nai-record na ang bayad sa sales.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                if (!isUtang && changeCents > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Sukli sa Mamimili:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PriceText(
                          centavos: changeCents,
                          fontSize: 26,
                          color: AppTheme.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kasunod na Mamimili (Next)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SalesHistorySheetContent extends StatelessWidget {
  const _SalesHistorySheetContent();

  void _confirmVoidSale(BuildContext context, int saleId, int totalCents) {
    final reasonCtrl = TextEditingController(text: 'Maling pindot / Kinansela');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('I-void ang Sale #$saleId?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ibabalik ang stock ng mga paninda at kakanselahin ang halagang ${CurrencyFormatter.format(totalCents)}.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Dahilan ng pag-void',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Huwag muna'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonCtrl.text.trim().isEmpty
                  ? 'Kinansela ng may-ari'
                  : reasonCtrl.text.trim();
              final cartProv = context.read<CartProvider>();
              final productProv = context.read<ProductProvider>();
              final utangProv = context.read<UtangProvider>();

              await cartProv.voidSale(
                saleId,
                reason: reason,
                productProvider: productProv,
                utangProvider: utangProv,
              );
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Na-void na ang Sale #$saleId at naibalik ang stock.'),
                  ),
                );
              }
            },
            child: const Text('Kumpirmahin ang Void'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartProv = context.watch<CartProvider>();
    final sales = cartProv.recentSales;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Kasaysayan ng Benta (Sales History)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sales.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Wala pang benta',
                    description: 'Makikita rito ang mga katatapos na benta.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sales.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      final isVoided = sale.isVoided;
                      return Row(
                        children: [
                          Icon(
                            isVoided
                                ? Icons.cancel_outlined
                                : sale.paymentType == 'utang'
                                    ? Icons.menu_book_rounded
                                    : Icons.payments_rounded,
                            color: isVoided
                                ? AppTheme.dangerRed
                                : sale.paymentType == 'utang'
                                    ? AppTheme.accentAmber
                                    : AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sale #${sale.id} • ${sale.paymentType.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isVoided ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                Text(
                                  isVoided
                                      ? 'VOIDED (${sale.voidReason ?? ""})'
                                      : CurrencyFormatter.format(sale.totalCents),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isVoided
                                        ? AppTheme.dangerRed
                                        : theme.colorScheme.onSurface.withOpacity(0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isVoided)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.dangerRed,
                              ),
                              onPressed: () => _confirmVoidSale(context, sale.id, sale.totalCents),
                              icon: const Icon(Icons.undo_rounded, size: 16),
                              label: const Text('I-void'),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
