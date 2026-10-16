import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/product.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/stock_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/barcode_scanner_sheet.dart';
import '../providers/product_provider.dart';
import '../widgets/add_edit_product_sheet.dart';
import '../widgets/product_detail_sheet.dart';

/// Products & Inventory screen with category filtering, search, quick restock, and full management.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeScan(BuildContext context) async {
    final code = await BarcodeScannerSheet.show(context);
    if (code == null || code.trim().isEmpty || !context.mounted) return;

    final productProv = context.read<ProductProvider>();
    final product = await productProv.findProductByBarcode(code);

    if (!context.mounted) return;

    if (product != null) {
      _showQuickRestock(context, product);
    } else {
      AddEditProductSheet.show(context, initialBarcode: code);
    }
  }

  void _showQuickRestock(BuildContext context, Product product) {
    int addQty = 10;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Quick Restock: ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kasalukuyang stock: ${product.stockQty} pcs'),
                  const SizedBox(height: 16),
                  const Text('Dami ng idadagdag:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 20, 50].map((qty) {
                      final isSelected = addQty == qty;
                      return ChoiceChip(
                        label: Text('+$qty'),
                        selected: isSelected,
                        onSelected: (_) => setDialogState(() => addQty = qty),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context
                        .read<ProductProvider>()
                        .restockProduct(product.id, addQty, note: 'List quick restock');
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Nagdagdag ng $addQty pcs kay ${product.name}'),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  },
                  child: const Text('I-kumpirma'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('I-delete si ${product.name}?'),
        content: const Text(
          'Hindi mabubura ang mga nakaraang benta sa ulat o resibo, ngunit itatago ito mula sa benta at imbentaryo.',
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
              HapticFeedback.heavyImpact();
              await context.read<ProductProvider>().deleteProduct(product.id);
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nai-archive na si ${product.name}.'),
                  backgroundColor: AppTheme.dangerRed,
                ),
              );
            },
            child: const Text('Oo, I-delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productProv = context.watch<ProductProvider>();
    final products = productProv.filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppStrings.productsTitle,
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            key: const Key('products_scan_barcode_btn'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: AppStrings.scanBarcode,
            onPressed: () => _handleBarcodeScan(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'I-refresh ang Imbentaryo',
            onPressed: () async {
              HapticFeedback.lightImpact();
              await productProv.loadProducts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Low Stock Toggle
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space16,
              vertical: 8,
            ),
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
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text('Mababa (${productProv.lowStockProducts.length})'),
                    ],
                  ),
                  selected: productProv.filterLowStockOnly,
                  selectedColor: AppTheme.dangerRed.withOpacity(0.18),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    productProv.toggleLowStockFilter();
                  },
                ),
              ],
            ),
          ),

          // Categories Horizontal Scroll
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.space16),
              itemCount: productProv.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = productProv.categories[index];
                final isSelected = productProv.selectedCategory == category;
                final (catColor, catIcon) = category == 'All'
                    ? (AppTheme.primaryGreen, Icons.grid_view_rounded)
                    : AppTheme.getCategoryStyle(category);

                return ChoiceChip(
                  avatar: Icon(catIcon, size: 16, color: isSelected ? Colors.white : catColor),
                  label: Text(category),
                  selected: isSelected,
                  selectedColor: catColor,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    productProv.setCategory(category);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Product List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => productProv.loadProducts(),
              child: products.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_outlined,
                      title: 'Walang nahanap na produkto',
                      description: 'Subukang baguhin ang filter o mag-search ng ibang pangalan.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(
                        left: AppConstants.space16,
                        right: AppConstants.space16,
                        top: 8,
                        bottom: 90,
                      ),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppConstants.space8),
                      itemBuilder: (context, index) {
                        final item = products[index];
                        final (catColor, _) = AppTheme.getCategoryStyle(item.categoryName);
                        final isTingiMother = item.pieceProductId != null && (item.piecesPerPack ?? 0) > 0;

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ProductDetailSheet.show(context, item);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  // Category accent vertical bar
                                  Container(
                                    width: 4,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: catColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Product Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isTingiMother)
                                              Container(
                                                margin: const EdgeInsets.only(left: 6),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentAmber.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'PACK',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppTheme.accentAmber,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              item.categoryName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            StockBadge(
                                              stockQty: item.stockQty,
                                              lowStockLevel: item.lowStockLevel,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Price & Actions (Restock, Edit, Delete)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      PriceText(centavos: item.priceCents, fontSize: 16),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Quick Restock Pill
                                          GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              _showQuickRestock(context, item);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryGreen.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.add_shopping_cart_rounded,
                                                    size: 13,
                                                    color: AppTheme.primaryGreen,
                                                  ),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'Restock',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryGreen,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // Direct Edit Button
                                          InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              AddEditProductSheet.show(context, product: item);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.accentBlue.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.edit_outlined,
                                                size: 14,
                                                color: AppTheme.accentBlue,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // Direct Delete Button
                                          InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              _confirmDeleteProduct(context, item);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.dangerRed.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 14,
                                                color: AppTheme.dangerRed,
                                              ),
                                            ),
                                          ),
                                        ],
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          AddEditProductSheet.show(context);
        },
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addProduct),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}
