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
import '../../../shared/widgets/slide_action_tile.dart';
import '../../../shared/widgets/store_header_title.dart';
import '../../reports/widgets/printable_restock_receipt_sheet.dart';
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
              title: Text(isTl ? 'Mabilisang Restock: ${product.name}' : 'Quick Restock: ${product.name}'),
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
                  child: Text(isTl ? 'I-kumpirma' : 'Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProduct(BuildContext context, Product product) {
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
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
              final sm = ScaffoldMessenger.of(context);
              final nav = Navigator.of(dialogCtx);
              await context.read<ProductProvider>().deleteProduct(product.id);
              nav.pop();
              sm.showSnackBar(
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
    final isTl = langProv?.isTagalog ?? false;
    final products = productProv.filteredProducts;

    TextStyle dropdownStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );

    final dropdownItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'All',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view_rounded, size: 16, color: AppTheme.primaryGreen),
            const SizedBox(width: 6),
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: dropdownStyle,
                  text: isTl
                      ? 'Lahat (${productProv.allProducts.length})'
                      : 'All (${productProv.allProducts.length})',
                ),
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'LowStock',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.dangerRed),
            const SizedBox(width: 6),
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: dropdownStyle,
                  text:
                      '${isTl ? "Mababang Stock" : "Low Stock"} (${productProv.lowStockProducts.length})',
                ),
              ),
            ),
          ],
        ),
      ),
      DropdownMenuItem(
        value: 'Expiry',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_rounded, size: 16, color: AppTheme.accentAmber),
            const SizedBox(width: 6),
            Flexible(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: dropdownStyle,
                  text:
                      '${isTl ? "Malapit Mag-expire" : "Near Expiry / Expired"} (${productProv.expiryProducts.length})',
                ),
              ),
            ),
          ],
        ),
      ),
      ...productProv.categories.where((c) => c != 'All').map((category) {
        final (catColor, catIcon) = AppTheme.getCategoryStyle(category);
        return DropdownMenuItem(
          value: category,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(catIcon, size: 16, color: catColor),
              const SizedBox(width: 6),
              Flexible(
                child: RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: dropdownStyle,
                    text: category,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: StoreHeaderTitle(
          sectionTitle: isTl ? 'Paninda' : 'Inventory',
        ),
        actions: [
          IconButton(
            key: const Key('products_restock_receipt_btn'),
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: isTl ? 'Listahan ng Pamimili (Resibo)' : 'Printable Restock List',
            onPressed: () {
              HapticFeedback.lightImpact();
              PrintableRestockReceiptSheet.show(context);
            },
          ),
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
          // Search & Unified Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space16,
              vertical: 8,
            ),
            child: Column(
              children: [
                Row(
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
                          Text('${isTl ? "Mababa" : "Low Stock"} (${productProv.lowStockProducts.length})'),
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
                const SizedBox(height: 8),
                // Unified Filter Dropdown (All, Low Stock, Expiry, Categories) + Slide Hint
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.25),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('inventory_filter_dropdown'),
                            value: dropdownItems.any((i) => i.value == productProv.activeDropdownFilter)
                                ? productProv.activeDropdownFilter
                                : 'All',
                            isExpanded: true,
                            isDense: true,
                            icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            items: dropdownItems,
                            onChanged: (val) {
                              if (val == null) return;
                              HapticFeedback.selectionClick();
                              productProv.applyDropdownFilter(val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isTl ? 'Diinan / i-slide pakaliwa para i-edit' : 'Hold/slide left to edit',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Product List with 4-inch (120px) Pull-to-Refresh and Long-Press/Slide-Left Actions
          Expanded(
            child: RefreshIndicator(
              displacement: 120.0,
              strokeWidth: 3.0,
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
                      physics: const AlwaysScrollableScrollPhysics(),
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

                        return SlideActionTile(
                          key: ValueKey('product_slide_${item.id}'),
                          editLabel: isTl ? 'I-edit' : 'Edit',
                          deleteLabel: isTl ? 'I-delete' : 'Delete',
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ProductDetailSheet.show(context, item);
                          },
                          onEdit: () {
                            HapticFeedback.lightImpact();
                            AddEditProductSheet.show(context, product: item);
                          },
                          onDelete: () {
                            HapticFeedback.lightImpact();
                            _confirmDeleteProduct(context, item);
                          },
                          child: Card(
                            clipBehavior: Clip.antiAlias,
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

                                  // Product Info (Maximized horizontal space)
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
                                            if (item.expiryDate != null && item.expiryDate!.trim().isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentAmber.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Exp: ${item.expiryDate!.split("T").first}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.accentAmber,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Price & Quick Restock Pill (Edit & Delete moved to Long-Press/Slide-Left)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      PriceText(centavos: item.priceCents, fontSize: 16),
                                      const SizedBox(height: 4),
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
        label: Text(isTl ? 'Bagong Paninda' : AppStrings.addProduct),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
  }
}
