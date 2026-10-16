import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/stock_badge.dart';
import '../../../shared/widgets/product_image_thumbnail.dart';
import '../../../core/localization/language_provider.dart';
import '../providers/product_provider.dart';
import 'add_edit_product_sheet.dart';

/// Interactive Product Detail & Inventory Management Sheet.
class ProductDetailSheet extends StatelessWidget {
  final Product product;

  const ProductDetailSheet({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductDetailSheet(product: product),
    );
  }

  void _showRestockDialog(BuildContext context) {
    int addQty = 10;
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? true;
    final costCtrl = TextEditingController(
      text: product.costCents > 0
          ? (product.costCents / 100.0).toStringAsFixed(2)
          : '',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isTl ? 'Restock: ${product.name}' : 'Restock: ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isTl
                      ? 'Kasalukuyang stock: ${product.stockQty} pcs'
                      : 'Current stock: ${product.stockQty} pcs'),
                  const SizedBox(height: 16),
                  Text(
                    isTl ? 'Pumili ng dami:' : 'Select quantity:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [5, 10, 20, 50].map((qty) {
                      final isSelected = addQty == qty;
                      return ChoiceChip(
                        label: Text('+$qty'),
                        selected: isSelected,
                        onSelected: (_) => setDialogState(() => addQty = qty),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: costCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isTl
                          ? 'Bagong Puhunan bawat piraso (Opsyonal)'
                          : 'New Cost per unit (Optional)',
                      hintText: '0.00',
                      prefixText: '₱ ',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(isTl ? 'Kanselahin' : 'Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final newCost = costCtrl.text.isNotEmpty
                        ? CurrencyFormatter.parsePesosToCentavos(costCtrl.text)
                        : null;
                    HapticFeedback.mediumImpact();
                    await context.read<ProductProvider>().restockProduct(
                          product.id,
                          addQty,
                          unitCostCents: newCost,
                          note: 'Counter Restock +$addQty',
                        );
                    Navigator.pop(dialogCtx);
                    Navigator.pop(context); // close sheet to refresh
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isTl
                              ? 'Matagumpay na nagdagdag ng $addQty pcs kay ${product.name}!'
                              : 'Successfully added $addQty pcs to ${product.name}!',
                        ),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  },
                  child: Text(isTl ? 'I-kumpirma ang Restock' : 'Confirm Restock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdjustDialog(BuildContext context) {
    int targetQty = product.stockQty;
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? true;
    String reason = isTl ? 'Recount (Aktwal na bilang)' : 'Recount (Physical Count)';
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isTl ? 'I-adjust ang Stock: ${product.name}' : 'Adjust Stock: ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isTl ? 'Itakda ang totoong bilang sa tindahan:' : 'Set shop physical inventory count:'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove),
                        onPressed: targetQty > 0
                            ? () => setDialogState(() => targetQty--)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '$targetQty',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add),
                        onPressed: () => setDialogState(() => targetQty++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: reason,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: isTl ? 'Dahilan' : 'Reason'),
                    items: [
                      DropdownMenuItem(
                          value: isTl ? 'Recount (Aktwal na bilang)' : 'Recount (Physical Count)',
                          child: Text(isTl ? 'Recount (Aktwal na bilang)' : 'Recount (Physical Count)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: isTl ? 'Damaged (Nasira / Nabutas)' : 'Damaged (Spoiled / Broken)',
                          child: Text(isTl ? 'Damaged (Nasira / Nabutas)' : 'Damaged (Spoiled / Broken)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: isTl ? 'Expired (Lumipas na petsa)' : 'Expired (Past Shelf Life)',
                          child: Text(isTl ? 'Expired (Lumipas na petsa)' : 'Expired (Past Shelf Life)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: isTl ? 'Personal Use (Kinuha ng may-ari)' : 'Personal Use (Owner Consumed)',
                          child: Text(isTl ? 'Personal Use (Kinuha ng may-ari)' : 'Personal Use (Owner Consumed)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => reason = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(isTl ? 'Kanselahin' : 'Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    await context.read<ProductProvider>().adjustStock(
                          product.id,
                          targetQty,
                          reason: reason,
                        );
                    Navigator.pop(dialogCtx);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isTl
                              ? 'Na-adjust ang stock ni ${product.name} sa $targetQty pcs!'
                              : 'Adjusted stock for ${product.name} to $targetQty pcs!',
                        ),
                        backgroundColor: AppTheme.accentAmber,
                      ),
                    );
                  },
                  child: Text(isTl ? 'I-save ang Adjustment' : 'Save Adjustment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isTl ? 'I-delete si ${product.name}?' : 'Delete ${product.name}?'),
        content: Text(
          isTl
              ? 'Hindi mabubura ang mga nakaraang benta sa ulat o resibo, ngunit itatago ito mula sa benta at listahan ng imbentaryo.'
              : 'Past sales in reports and receipts will remain intact, but this item will be hidden from sales and inventory.',
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
              minimumSize: const Size(0, 42),
            ),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await context.read<ProductProvider>().deleteProduct(product.id);
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isTl
                        ? 'Nai-archive na si ${product.name}.'
                        : '${product.name} has been archived.',
                  ),
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
    final isDark = theme.brightness == Brightness.dark;
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? true;
    final (catColor, catIcon) = AppTheme.getCategoryStyle(product.categoryName);

    final profitCents = product.priceCents - product.costCents;
    final marginPercent = product.priceCents > 0 && product.costCents > 0
        ? ((profitCents / product.priceCents) * 100).toStringAsFixed(1)
        : null;

    final isTingiMother = product.pieceProductId != null &&
        (product.piecesPerPack ?? 0) > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2B) : Colors.white,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      padding: const EdgeInsets.all(AppConstants.space20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category & Barcode pill
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(catIcon, size: 14, color: catColor),
                      const SizedBox(width: 4),
                      Text(
                        product.categoryName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: catColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (product.barcode != null && product.barcode!.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_rounded,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          product.barcode!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Photo & Name Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductImageThumbnail(
                  imagePath: product.imagePath,
                  width: 58,
                  height: 58,
                  borderRadius: 12,
                  fallback: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(catIcon, color: catColor, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (product.imagePath != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.photo_camera_rounded, size: 12, color: AppTheme.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              isTl ? 'May Litrato' : 'Offline Photo Attached',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Price, Cost, and Stock Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2438) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF263345) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isTl ? 'Presyo ng Benta' : 'Selling Price',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        PriceText(centavos: product.priceCents, fontSize: 20),
                        if (product.costCents > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${isTl ? 'Puhunan' : 'Cost'}: ${CurrencyFormatter.format(product.costCents)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                          if (marginPercent != null)
                            Text(
                              '+${CurrencyFormatter.format(profitCents)} ($marginPercent% ${isTl ? 'tubo' : 'profit'})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.grey.withOpacity(0.2),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(isTl ? 'Kasalukuyang Stock' : 'Current Stock',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${product.stockQty} pcs',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StockBadge(
                        stockQty: product.stockQty,
                        lowStockLevel: product.lowStockLevel,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tingi (Break Pack) Action if this product is a mother pack
            if (isTingiMother) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentAmber.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_rounded,
                        color: AppTheme.accentAmber, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTl ? 'Tingi Pack Available' : 'Retail Split Available',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.accentAmber,
                            ),
                          ),
                          Text(
                            isTl
                                ? 'Ang 1 pack ay naglalaman ng ${product.piecesPerPack} piraso.'
                                : 'Each 1 pack contains ${product.piecesPerPack} retail pieces.',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentAmber,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: product.stockQty <= 0
                          ? null
                          : () async {
                              HapticFeedback.heavyImpact();
                              await context
                                  .read<ProductProvider>()
                                  .breakPack(product.id);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isTl
                                        ? 'Binuksan ang 1 pack! Nadagdagan ng ${product.piecesPerPack} pcs ang tingi stock.'
                                        : 'Broke 1 pack! Added ${product.piecesPerPack} pcs to retail stock.',
                                  ),
                                  backgroundColor: AppTheme.primaryGreen,
                                ),
                              );
                            },
                      child: Text(isTl ? 'Buksan (Break)' : 'Break Pack',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showRestockDialog(context),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('Restock',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showAdjustDialog(context),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(isTl ? 'I-adjust' : 'Adjust',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      AddEditProductSheet.show(context, product: product);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(isTl ? 'I-edit ang Detalye' : 'Edit Details'),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                  ),
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(isTl ? 'I-delete' : 'Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
