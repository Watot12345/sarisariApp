import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/services/product_image_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product.dart';
import '../../../shared/widgets/barcode_scanner_sheet.dart';
import '../../../shared/widgets/product_image_thumbnail.dart';
import '../providers/product_provider.dart';

/// Modal bottom sheet for adding or editing a product in inventory.
class AddEditProductSheet extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;

  const AddEditProductSheet({
    super.key,
    this.product,
    this.initialBarcode,
  });

  static Future<void> show(
    BuildContext context, {
    Product? product,
    String? initialBarcode,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditProductSheet(
        product: product,
        initialBarcode: initialBarcode,
      ),
    );
  }

  @override
  State<AddEditProductSheet> createState() => _AddEditProductSheetState();
}

class _AddEditProductSheetState extends State<AddEditProductSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _lowStockCtrl;
  late TextEditingController _newCategoryCtrl;
  late TextEditingController _piecesPerPackCtrl;

  String _selectedCategory = 'Noodles';
  bool _isCreatingNewCategory = false;
  bool _isTingiPack = false;
  int? _selectedPieceProductId;
  String? _barcodeError;
  bool _isSaving = false;
  String? _imagePath;
  String? _imageFileSize;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(
      text: p?.barcode ?? widget.initialBarcode ?? '',
    );
    _priceCtrl = TextEditingController(
      text: p != null ? (p.priceCents / 100.0).toStringAsFixed(2) : '',
    );
    _costCtrl = TextEditingController(
      text: p != null && p.costCents > 0
          ? (p.costCents / 100.0).toStringAsFixed(2)
          : '',
    );
    _stockCtrl = TextEditingController(text: p != null ? '${p.stockQty}' : '10');
    _lowStockCtrl =
        TextEditingController(text: p != null ? '${p.lowStockLevel}' : '5');
    _newCategoryCtrl = TextEditingController();
    _piecesPerPackCtrl = TextEditingController(
      text: p?.piecesPerPack != null ? '${p!.piecesPerPack}' : '20',
    );

    _imagePath = p?.imagePath;
    if (_imagePath != null) {
      ProductImageService.getFormattedFileSize(_imagePath).then((size) {
        if (mounted && size != null) setState(() => _imageFileSize = size);
      });
    }

    if (p != null) {
      _selectedCategory = p.categoryName.isNotEmpty ? p.categoryName : 'General';
      if (p.pieceProductId != null && (p.piecesPerPack ?? 0) > 0) {
        _isTingiPack = true;
        _selectedPieceProductId = p.pieceProductId;
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    HapticFeedback.selectionClick();
    final path = await ProductImageService.pickAndCompressImage(source: source);
    if (path != null) {
      final size = await ProductImageService.getFormattedFileSize(path);
      setState(() {
        _imagePath = path;
        _imageFileSize = size;
      });
    }
  }

  void _removePhoto() {
    HapticFeedback.lightImpact();
    setState(() {
      _imagePath = null;
      _imageFileSize = null;
    });
  }

  void _showPhotoOptions() {
    final theme = Theme.of(context);
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isTl ? 'Litrato ng Produkto' : 'Product Photo',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                isTl
                    ? 'Awtomatikong naka-compress (~30 KB) para magaan sa phone'
                    : 'Auto-compressed (~30 KB) to save phone storage',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFD1FAE5),
                  child: Icon(Icons.camera_alt_rounded, color: AppTheme.primaryGreen),
                ),
                title: Text(isTl ? 'Kunan gamit ang Camera' : 'Take with Camera'),
                subtitle: Text(
                  isTl
                      ? 'Kuhanan ng litrato ang paninda sa estante'
                      : 'Snap a picture of the product on shelf',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDBEAFE),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB)),
                ),
                title: Text(isTl ? 'Pumili sa Gallery / Photos' : 'Choose from Gallery / Photos'),
                subtitle: Text(
                  isTl
                      ? 'Pumili mula sa iyong nai-download o litrato'
                      : 'Select from your device photos or downloads',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (_imagePath != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEE2E2),
                    child: Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed),
                  ),
                  title: Text(
                    isTl ? 'Tanggalin ang Litrato' : 'Remove Photo',
                    style: const TextStyle(color: AppTheme.dangerRed),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _lowStockCtrl.dispose();
    _newCategoryCtrl.dispose();
    _piecesPerPackCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateBarcode(String barcode) async {
    if (barcode.trim().isEmpty) {
      if (mounted) setState(() => _barcodeError = null);
      return;
    }
    final prov = context.read<ProductProvider>();
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
    final isUnique = await prov.isBarcodeUnique(
      barcode.trim(),
      excludeProductId: widget.product?.id,
    );
    if (mounted) {
      setState(() {
        _barcodeError = isUnique
            ? null
            : (isTl ? 'Ginagamit na ang barcode na ito' : 'This barcode is already in use');
      });
    }
  }

  Future<void> _save() async {
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
    if (!_formKey.currentState!.validate() || _barcodeError != null) {
      return;
    }

    final priceCents = CurrencyFormatter.parsePesosToCentavos(_priceCtrl.text);
    if (priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTl ? 'Kailangang mas mataas sa zero ang presyo.' : 'Price must be greater than zero.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final prov = context.read<ProductProvider>();

    final costCents = CurrencyFormatter.parsePesosToCentavos(_costCtrl.text);
    final stockQty = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final lowStock = int.tryParse(_lowStockCtrl.text.trim()) ?? 5;
    final piecesPerPack = _isTingiPack
        ? int.tryParse(_piecesPerPackCtrl.text.trim())
        : null;

    final categoryToUse = _isCreatingNewCategory && _newCategoryCtrl.text.trim().isNotEmpty
        ? _newCategoryCtrl.text.trim()
        : _selectedCategory;

    final barcode = _barcodeCtrl.text.trim().isNotEmpty
        ? _barcodeCtrl.text.trim()
        : null;

    try {
      if (isEditing) {
        if (widget.product!.imagePath != null && widget.product!.imagePath != _imagePath) {
          ProductImageService.deleteImageFile(widget.product!.imagePath);
        }
        final updated = widget.product!.copyWith(
          name: _nameCtrl.text.trim(),
          barcode: barcode,
          categoryName: categoryToUse,
          priceCents: priceCents,
          costCents: costCents,
          stockQty: stockQty,
          lowStockLevel: lowStock,
          pieceProductId: _isTingiPack ? _selectedPieceProductId : null,
          piecesPerPack: piecesPerPack,
          imagePath: _imagePath,
          clearImagePath: _imagePath == null,
        );
        await prov.updateProduct(updated, categoryName: categoryToUse);
      } else {
        final newProd = Product(
          id: 0,
          name: _nameCtrl.text.trim(),
          barcode: barcode,
          categoryName: categoryToUse,
          priceCents: priceCents,
          costCents: costCents,
          stockQty: stockQty,
          lowStockLevel: lowStock,
          pieceProductId: _isTingiPack ? _selectedPieceProductId : null,
          piecesPerPack: piecesPerPack,
          imagePath: _imagePath,
        );
        await prov.addProduct(newProd, categoryName: categoryToUse);
      }

      HapticFeedback.mediumImpact();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? (isTl
                      ? 'Matagumpay na na-update si ${_nameCtrl.text.trim()}!'
                      : 'Successfully updated ${_nameCtrl.text.trim()}!')
                  : (isTl
                      ? 'Nai-dagdag na si ${_nameCtrl.text.trim()} sa imbentaryo!'
                      : 'Added ${_nameCtrl.text.trim()} to inventory!'),
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTl ? 'Error sa pag-save: $e' : 'Error saving: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productProv = context.watch<ProductProvider>();
    final langProv = context.watch<LanguageProvider?>();
    final isTl = langProv?.isTagalog ?? false;

    final availableCategories = {
      'Noodles',
      'Drinks',
      'Snacks',
      'Coffee',
      'Toiletries',
      'Household',
      'Cigarettes',
      'Condiments',
      'Canned Goods',
      'General',
      ...productProv.categories.where((c) => c != 'All'),
    }.toList();

    final pieceCandidates = productProv.allProducts
        .where((p) => p.id != widget.product?.id)
        .toList();

    // Profit margin calculation helper
    final priceCents = CurrencyFormatter.parsePesosToCentavos(_priceCtrl.text);
    final costCents = CurrencyFormatter.parsePesosToCentavos(_costCtrl.text);
    final profitCents = priceCents - costCents;
    final marginPercent = priceCents > 0 && costCents > 0
        ? ((profitCents / priceCents) * 100).toStringAsFixed(1)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2B) : Colors.white,
        borderRadius: AppConstants.borderRadiusTopSheet,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
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
                const SizedBox(height: 12),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isEditing
                            ? (isTl ? 'I-edit ang Produkto' : 'Edit Product')
                            : (isTl ? 'Magdagdag ng Produkto' : 'Add Product'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Optional Product Photo Picker Card
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _imagePath != null
                          ? AppTheme.primaryGreen.withOpacity(0.5)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: _imagePath != null
                      ? Row(
                          children: [
                            ProductImageThumbnail(
                              imagePath: _imagePath,
                              width: 60,
                              height: 60,
                              borderRadius: 10,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primaryGreen),
                                      const SizedBox(width: 4),
                                      Text(
                                        isTl
                                            ? 'May Litrato (${_imageFileSize ?? "Compressed"})'
                                            : 'With Photo (${_imageFileSize ?? "Compressed"})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isTl
                                        ? 'Ligtas na naka-store sa phone mo lamang.'
                                        : 'Safely stored on your device only.',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: isTl ? 'Palitan ang litrato' : 'Change photo',
                              onPressed: _showPhotoOptions,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.dangerRed),
                              tooltip: isTl ? 'Tanggalin' : 'Remove',
                              onPressed: _removePhoto,
                            ),
                          ],
                        )
                      : InkWell(
                          onTap: _showPhotoOptions,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppTheme.primaryGreen,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isTl ? 'Maglagay ng Litrato (Opsyonal)' : 'Add Product Photo (Optional)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isTl
                                            ? 'Kusang kinocompress (~30 KB) para tipid sa memory'
                                            : 'Auto-compressed (~30 KB) to save memory',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                ),

                // Product Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: isTl ? 'Pangalan ng Produkto *' : 'Product Name *',
                    hintText: isTl ? 'hal. Lucky Me Pancit Canton' : 'e.g., Lucky Me Pancit Canton',
                    prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? (isTl ? 'Kailangan ang pangalan.' : 'Name is required.') : null,
                ),
                const SizedBox(height: 14),

                // Barcode
                TextFormField(
                  controller: _barcodeCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: _validateBarcode,
                  decoration: InputDecoration(
                    labelText: isTl ? 'Barcode (Opsyonal)' : 'Barcode (Optional)',
                    hintText: isTl ? 'I-type o i-scan ang barcode' : 'Type or scan barcode',
                    prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                    suffixIcon: IconButton(
                      key: const Key('scan_barcode_in_form_btn'),
                      tooltip: isTl ? 'I-scan ang Barcode' : 'Scan Barcode',
                      icon: const Icon(Icons.center_focus_strong_rounded),
                      onPressed: () async {
                        final scanned = await BarcodeScannerSheet.show(
                          context,
                          title: isTl ? 'I-scan ang Barcode' : 'Scan Product Barcode',
                        );
                        if (scanned != null && scanned.isNotEmpty && mounted) {
                          _barcodeCtrl.text = scanned;
                          await _validateBarcode(scanned);
                        }
                      },
                    ),
                    errorText: _barcodeError,
                  ),
                ),
                const SizedBox(height: 14),

                // Category Selection & Verification Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTl ? 'Kategorya ng Produkto *' : 'Product Category *',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),

                    // Live Verified Category Card
                    Builder(
                      builder: (context) {
                        final effectiveCategory = _isCreatingNewCategory && _newCategoryCtrl.text.trim().isNotEmpty
                            ? _newCategoryCtrl.text.trim()
                            : _selectedCategory;
                        final (catColor, catIcon) = AppTheme.getCategoryStyle(effectiveCategory);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: catColor.withOpacity(0.4), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(catIcon, color: catColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isTl ? 'BERIPIKADONG KATEGORYA' : 'VERIFIED CATEGORY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        color: catColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      effectiveCategory,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.verified_rounded, color: catColor, size: 22),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Available Category Chips Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...availableCategories.map((cat) {
                          final isSelected = !_isCreatingNewCategory && _selectedCategory == cat;
                          final (catColor, catIcon) = AppTheme.getCategoryStyle(cat);
                          return ChoiceChip(
                            avatar: Icon(catIcon, size: 16, color: isSelected ? Colors.white : catColor),
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: catColor,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedCategory = cat;
                                _isCreatingNewCategory = false;
                              });
                            },
                          );
                        }),
                        ActionChip(
                          avatar: Icon(_isCreatingNewCategory ? Icons.check_circle : Icons.add_circle_outline, size: 16),
                          label: Text(_isCreatingNewCategory
                              ? (isTl ? 'Bagong Kategorya' : 'New Category')
                              : (isTl ? '+ Bago' : '+ New')),
                          backgroundColor: _isCreatingNewCategory ? AppTheme.accentPurple.withOpacity(0.15) : null,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isCreatingNewCategory = !_isCreatingNewCategory;
                            });
                          },
                        ),
                      ],
                    ),

                    if (_isCreatingNewCategory) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _newCategoryCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: isTl ? 'Pangalan ng Bagong Kategorya *' : 'New Category Name *',
                          hintText: isTl ? 'hal. Tinapay, Biskwit, o Ice Cream' : 'e.g., Bread, Biscuits, or Ice Cream',
                          prefixIcon: const Icon(Icons.new_label_rounded),
                        ),
                        validator: (v) {
                          if (_isCreatingNewCategory && (v == null || v.trim().isEmpty)) {
                            return isTl
                                ? 'Kailangan ang pangalan ng bagong kategorya'
                                : 'New category name is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Price and Cost Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: isTl ? 'Presyo (₱) *' : 'Price (₱) *',
                          hintText: '0.00',
                          prefixText: '₱ ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return isTl ? 'Kailangan ang presyo' : 'Price is required';
                          }
                          final cents = CurrencyFormatter.parsePesosToCentavos(v);
                          if (cents <= 0) return isTl ? 'Mas mataas sa 0' : 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: isTl ? 'Puhunan (₱)' : 'Cost (₱)',
                          hintText: '0.00',
                          prefixText: '₱ ',
                        ),
                      ),
                    ),
                  ],
                ),

                // Live Profit Indicator
                if (priceCents > 0 && costCents > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: profitCents >= 0
                          ? AppTheme.primaryGreen.withOpacity(0.12)
                          : AppTheme.dangerRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            profitCents >= 0
                                ? (isTl ? 'Tubo bawat piraso:' : 'Profit per item:')
                                : (isTl ? 'Lugi bawat piraso:' : 'Loss per item:'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: profitCents >= 0 ? AppTheme.primaryGreen : AppTheme.dangerRed,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${CurrencyFormatter.format(profitCents)} (${marginPercent ?? '0'}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: profitCents >= 0 ? AppTheme.primaryGreen : AppTheme.dangerRed,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Stock Quantity and Low-Stock Alert
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isTl ? 'Kasalukuyang Stock *' : 'Current Stock *',
                          hintText: '10',
                          prefixIcon: const Icon(Icons.inventory_2_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return isTl ? 'Lagyan ng bilang' : 'Enter stock quantity';
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 0) return isTl ? 'Hindi negative' : 'Cannot be negative';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lowStockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isTl ? 'Low Stock Alert' : 'Low Stock Alert',
                          hintText: '5',
                          prefixIcon: const Icon(Icons.warning_amber_rounded),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n != null && n < 0) return isTl ? 'Hindi negative' : 'Cannot be negative';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Tingi / Mother Pack Configuration
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A2438) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isTingiPack ? AppTheme.accentAmber : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            isTl ? 'Mother Pack (Tingi Support)' : 'Mother Pack (Retail Split)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            isTl
                                ? 'I-link ang pack na ito sa tingi piraso (hal. Pack ng Sigarilyo o Box ng Sabon)'
                                : 'Link this pack to retail piece (e.g. Cigarette Pack or Soap Bar Box)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          value: _isTingiPack,
                          activeColor: AppTheme.accentAmber,
                          onChanged: (val) {
                            setState(() {
                              _isTingiPack = val;
                            });
                          },
                        ),
                      if (_isTingiPack) ...[
                        const Divider(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedPieceProductId,
                          decoration: InputDecoration(
                            labelText: isTl
                                ? 'Piliin ang Tingi / Piraso na Produkto'
                                : 'Select Retail / Piece Product',
                            prefixIcon: const Icon(Icons.link_rounded),
                          ),
                          items: pieceCandidates
                              .map((p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      '${p.name} (${isTl ? 'Stock' : 'Stock'}: ${p.stockQty})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedPieceProductId = val);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _piecesPerPackCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isTl
                                ? 'Ilang piraso bawat 1 pack? (Pieces per pack)'
                                : 'Pieces per 1 pack',
                            hintText: isTl ? 'hal. 20' : 'e.g. 20',
                            prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                          ),
                          validator: (v) {
                            if (_isTingiPack) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n <= 1) {
                                return isTl ? 'Dapat higit sa 1 piraso' : 'Must be greater than 1 piece';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                  ),
                ),
                const SizedBox(height: 20),

                // Save button
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _isSaving
                        ? (isTl ? 'Sine-save...' : 'Saving...')
                        : isEditing
                            ? (isTl ? 'I-save ang Pagbabago' : 'Save Changes')
                            : (isTl ? 'Idagdag sa Tindahan' : 'Add to Inventory'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Delete Button (visible when editing existing product)
                if (isEditing) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _confirmDeleteFromSheet(context),
                    icon: Icon(Icons.delete_outline_rounded, color: AppTheme.dangerRed),
                    label: Text(
                      isTl ? 'I-delete ang Produktong Ito' : 'Delete This Product',
                      style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.dangerRed),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteFromSheet(BuildContext context) {
    final isTl = context.read<LanguageProvider?>()?.isTagalog ?? false;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isTl ? 'I-delete si ${widget.product!.name}?' : 'Delete ${widget.product!.name}?'),
        content: Text(
          isTl
              ? 'Hindi mabubura ang mga nakaraang benta sa ulat o resibo, ngunit itatago ito mula sa benta at imbentaryo.'
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
            ),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await context.read<ProductProvider>().deleteProduct(widget.product!.id);
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isTl
                        ? 'Nai-archive na si ${widget.product!.name}.'
                        : '${widget.product!.name} has been archived.',
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
}
