import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/product.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/stock_badge.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/barcode_scanner_sheet.dart';
import '../../../shared/widgets/product_image_thumbnail.dart';
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
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
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
                  Text('${isTl ? "Kasalukuyang stock" : "Current stock"}: ${product.stockQty} pcs'),
                  const SizedBox(height: 16),
                  Text(
                    isTl ? 'Dami ng idadagdag:' : 'Quantity to add:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  child: Text(isTl ? 'Kanselahin' : 'Cancel'),
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
                        content: Text(
                          isTl
                              ? 'Nagdagdag ng $addQty pcs kay ${product.name}'
                              : 'Added $addQty pcs to ${product.name}',
                        ),
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
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? true;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isTl ? 'I-delete si ${product.name}?' : 'Delete ${product.name}?'),
        content: Text(
          isTl
              ? 'Hindi mabubura ang mga nakaraang benta sa ulat o resibo, ngunit itatago ito mula sa benta at imbentaryo.'
              : 'Previous sales records will be preserved, but this product will be hidden from inventory and sales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isTl ? 'Huwag muna' : 'Cancel'),
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
                  content: Text(
                    isTl
                        ? 'Nai-archive na si ${product.name}.'
                        : '${product.name} has been archived.',
                  ),
                  backgroundColor: AppTheme.dangerRed,
                ),
              );
            },
            child: Text(isTl ? 'Oo, I-delete' : 'Yes, Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productProv = context.watch<ProductProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? true;
    final products = productProv.filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isTl ? 'Paninda' : 'Inventory',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            key: const Key('products_scan_barcode_btn'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: isTl ? 'I-scan ang Barcode' : AppStrings.scanBarcode,
            onPressed: () => _handleBarcodeScan(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isTl ? 'I-refresh ang Imbentaryo' : 'Refresh Inventory',
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
                      hintText: isTl ? 'Maghanap ng paninda o barcode...' : AppStrings.searchProductsHint,
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
                  label: Text(category == 'All' ? (isTl ? 'Lahat' : 'All') : category),
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
                  ? EmptyState(
                      icon: Icons.inventory_outlined,
                      title: isTl ? 'Walang nahanap na paninda' : 'No products found',
                      description: isTl
                          ? 'Subukang baguhin ang filter o mag-search ng ibang pangalan.'
                          : 'Try changing your filter or searching for another item.',
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
                        final (catColor, catIcon) = AppTheme.getCategoryStyle(item.categoryName);
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
                                  const SizedBox(width: 8),

                                  // Product Thumbnail (Image with Category Icon fallback)
                                  ProductImageThumbnail(
                                    imagePath: item.imagePath,
                                    width: 44,
                                    height: 44,
                                    borderRadius: 8,
                                    fallback: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: catColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(catIcon, color: catColor, size: 22),
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
                                          Tooltip(
                                            message: isTl ? 'I-edit' : 'Edit',
                                            child: InkWell(
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
                                          ),
                                          const SizedBox(width: 6),

                                          // Direct Delete Button
                                          Tooltip(
                                            message: isTl ? 'I-delete' : 'Delete',
                                            child: InkWell(
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
