import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../shared/widgets/price_text.dart';
import '../../../shared/widgets/stock_badge.dart';
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
              title: Text('Restock: ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kasalukuyang stock: ${product.stockQty} pcs'),
                  const SizedBox(height: 16),
                  const Text('Pumili ng dami:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    decoration: const InputDecoration(
                      labelText: 'Bagong Puhunan bawat piraso (Opsyonal)',
                      hintText: '0.00',
                      prefixText: '₱ ',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Kanselahin'),
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
                            'Matagumpay na nagdagdag ng $addQty pcs kay ${product.name}!'),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  },
                  child: const Text('I-kumpirma ang Restock'),
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
    String reason = 'Recount (Aktwal na bilang)';
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('I-adjust ang Stock: ${product.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Itakda ang totoong bilang sa tindahan:'),
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
                    decoration: const InputDecoration(labelText: 'Dahilan'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Recount (Aktwal na bilang)',
                          child: Text('Recount (Aktwal na bilang)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: 'Damaged (Nasira / Nabutas)',
                          child: Text('Damaged (Nasira / Nabutas)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: 'Expired (Lumipas na petsa)',
                          child: Text('Expired (Lumipas na petsa)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(
                          value: 'Personal Use (Kinuha ng may-ari)',
                          child: Text('Personal Use (Kinuha ng may-ari)', overflow: TextOverflow.ellipsis)),
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
                  child: const Text('Kanselahin'),
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
                            'Na-adjust ang stock ni ${product.name} sa $targetQty pcs!'),
                        backgroundColor: AppTheme.accentAmber,
                      ),
                    );
                  },
                  child: const Text('I-save ang Adjustment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('I-delete si ${product.name}?'),
        content: const Text(
          'Hindi mabubura ang mga nakaraang benta sa ulat o resibo, ngunit itatago ito mula sa benta at listahan ng imbentaryo.',
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
              minimumSize: const Size(0, 42),
            ),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await context.read<ProductProvider>().deleteProduct(product.id);
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nai-archive na si ${product.name}.'),
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
    final isDark = theme.brightness == Brightness.dark;
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

            // Product Name
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
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
                        const Text('Presyo ng Benta',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 2),
                        PriceText(centavos: product.priceCents, fontSize: 20),
                        if (product.costCents > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Puhunan: ${CurrencyFormatter.format(product.costCents)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                          if (marginPercent != null)
                            Text(
                              '+${CurrencyFormatter.format(profitCents)} ($marginPercent% tubo)',
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
                      const Text('Kasalukuyang Stock',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                          const Text(
                            'Tingi Pack Available',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.accentAmber,
                            ),
                          ),
                          Text(
                            'Ang 1 pack ay naglalaman ng ${product.piecesPerPack} piraso.',
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
                                      'Binuksan ang 1 pack! Nadagdagan ng ${product.piecesPerPack} pcs ang tingi stock.'),
                                  backgroundColor: AppTheme.primaryGreen,
                                ),
                              );
                            },
                      child: const Text('Buksan (Break)',
                          style: TextStyle(
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
                    label: const Text('I-adjust',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                    label: const Text('I-edit ang Detalye'),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                  ),
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('I-delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
