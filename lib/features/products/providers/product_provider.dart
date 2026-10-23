import 'package:flutter/material.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/stock_repository.dart';

/// Provider managing product list, search filtering, category tabs, and SQLite persistence.
class ProductProvider extends ChangeNotifier {
  final ProductRepository _productRepo;
  final StockRepository _stockRepo;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _filterLowStockOnly = false;
  bool _filterExpiryOnly = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<Product> _products = [];

  ProductProvider({
    ProductRepository? productRepo,
    StockRepository? stockRepo,
  })  : _productRepo = productRepo ?? ProductRepository(),
        _stockRepo = stockRepo ?? StockRepository() {
    loadProducts();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Product> get allProducts => List.unmodifiable(_products);
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get filterLowStockOnly => _filterLowStockOnly;
  bool get filterExpiryOnly => _filterExpiryOnly;

  List<String> get categories {
    final set = {'All', ..._products.map((p) => p.categoryName)};
    return set.toList();
  }

  bool _isNearOrPastExpiry(Product p) {
    final exp = p.expiryDate?.trim();
    if (exp == null || exp.isEmpty) return false;
    final parsed = DateTime.tryParse(exp);
    if (parsed == null) return true;
    final threshold = DateTime.now().add(const Duration(days: 30));
    return !parsed.isAfter(threshold);
  }

  List<Product> get filteredProducts {
    return _products.where((p) {
      if (!p.isActive) return false;
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.barcode != null && p.barcode!.contains(_searchQuery));
      final matchesCategory =
          _selectedCategory == 'All' || p.categoryName == _selectedCategory;
      final matchesLowStock = !_filterLowStockOnly || p.isLowStock || p.isOutOfStock;
      final matchesExpiry = !_filterExpiryOnly || _isNearOrPastExpiry(p);

      return matchesQuery && matchesCategory && matchesLowStock && matchesExpiry;
    }).toList();
  }

  List<Product> get lowStockProducts {
    return _products.where((p) => p.isLowStock || p.isOutOfStock).toList();
  }

  List<Product> get expiryProducts {
    return _products.where((p) => p.isActive && _isNearOrPastExpiry(p)).toList();
  }

  /// Current unified dropdown filter key ('All', 'LowStock', 'Expiry', or category name)
  String get activeDropdownFilter {
    if (_filterLowStockOnly) return 'LowStock';
    if (_filterExpiryOnly) return 'Expiry';
    return _selectedCategory;
  }

  /// Clears all in-memory products (used when resetting store data).
  void clearAll() {
    _products = [];
    _searchQuery = '';
    _selectedCategory = 'All';
    _filterLowStockOnly = false;
    _filterExpiryOnly = false;
    notifyListeners();
  }

  /// Reloads products from SQLite database.
  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dbProducts = await _productRepo.getProducts();
      _products = dbProducts;
    } catch (e) {
      debugPrint('ProductProvider note: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Filter Actions
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleLowStockFilter() {
    _filterLowStockOnly = !_filterLowStockOnly;
    if (_filterLowStockOnly) _filterExpiryOnly = false;
    notifyListeners();
  }

  void toggleExpiryFilter() {
    _filterExpiryOnly = !_filterExpiryOnly;
    if (_filterExpiryOnly) _filterLowStockOnly = false;
    notifyListeners();
  }

  void applyDropdownFilter(String value) {
    if (value == 'All') {
      _selectedCategory = 'All';
      _filterLowStockOnly = false;
      _filterExpiryOnly = false;
    } else if (value == 'LowStock') {
      _selectedCategory = 'All';
      _filterLowStockOnly = true;
      _filterExpiryOnly = false;
    } else if (value == 'Expiry') {
      _selectedCategory = 'All';
      _filterLowStockOnly = false;
      _filterExpiryOnly = true;
    } else {
      _selectedCategory = value;
      _filterLowStockOnly = false;
      _filterExpiryOnly = false;
    }
    notifyListeners();
  }

  /// Checks if a barcode is unique (or belongs to the currently edited product)
  Future<bool> isBarcodeUnique(String barcode, {int? excludeProductId}) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return true;

    try {
      final existing = await _productRepo.getProductByBarcode(clean);
      if (existing == null) return true;
      return existing.id == excludeProductId;
    } catch (_) {
      final match = _products.where((p) => p.barcode == clean && p.isActive).firstOrNull;
      if (match == null) return true;
      return match.id == excludeProductId;
    }
  }

  /// Looks up an active product by exact barcode match.
  Future<Product?> findProductByBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;

    final inMemory = _products.where((p) => p.isActive && p.barcode == clean).firstOrNull;
    if (inMemory != null) return inMemory;

    try {
      return await _productRepo.getProductByBarcode(clean);
    } catch (_) {
      return null;
    }
  }

  /// Inserts a new product into SQLite or in-memory fallback
  Future<void> addProduct(Product product, {String? categoryName}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      int? catId = product.categoryId;
      final targetCat = (categoryName ?? product.categoryName).trim();
      if (targetCat.isNotEmpty && targetCat != 'All') {
        catId = await _productRepo.getOrCreateCategory(targetCat);
      }
      final newProduct = product.copyWith(
        categoryId: catId,
        categoryName: targetCat.isEmpty ? 'General' : targetCat,
      );
      await _productRepo.insertProduct(newProduct);
      await loadProducts();
    } catch (e) {
      // Memory fallback for offline/preview
      final newId = _products.isEmpty ? 1 : (_products.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1);
      final fallbackProd = product.copyWith(
        id: newId,
        categoryName: (categoryName ?? product.categoryName).trim().isEmpty
            ? 'General'
            : (categoryName ?? product.categoryName).trim(),
      );
      _products.insert(0, fallbackProd);
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates an existing product in SQLite or memory
  Future<void> updateProduct(Product product, {String? categoryName}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      int? catId = product.categoryId;
      final targetCat = (categoryName ?? product.categoryName).trim();
      if (targetCat.isNotEmpty && targetCat != 'All') {
        catId = await _productRepo.getOrCreateCategory(targetCat);
      }
      final updated = product.copyWith(
        categoryId: catId,
        categoryName: targetCat.isEmpty ? 'General' : targetCat,
      );
      await _productRepo.updateProduct(updated);
      await loadProducts();
    } catch (e) {
      final idx = _products.indexWhere((p) => p.id == product.id);
      if (idx != -1) {
        _products[idx] = product.copyWith(
          categoryName: (categoryName ?? product.categoryName).trim().isEmpty
              ? 'General'
              : (categoryName ?? product.categoryName).trim(),
        );
        notifyListeners();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Soft deletes a product (sets is_active = 0)
  Future<void> deleteProduct(int productId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _productRepo.softDeleteProduct(productId);
      await loadProducts();
    } catch (e) {
      final idx = _products.indexWhere((p) => p.id == productId);
      if (idx != -1) {
        _products.removeAt(idx);
        notifyListeners();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restocks a product and writes to stock_movements
  Future<void> restockProduct(
    int productId,
    int addQty, {
    int? unitCostCents,
    String? note,
  }) async {
    try {
      await _stockRepo.restock(
        productId,
        addQty,
        unitCostCents: unitCostCents,
        note: note,
      );
      await loadProducts();
    } catch (e) {
      final idx = _products.indexWhere((p) => p.id == productId);
      if (idx != -1) {
        final old = _products[idx];
        _products[idx] = old.copyWith(
          stockQty: old.stockQty + addQty,
          costCents: unitCostCents ?? old.costCents,
        );
        notifyListeners();
      }
    }
  }

  /// Quick restock helper (compat)
  Future<void> quickRestock(int productId, int addQty) async {
    await restockProduct(productId, addQty, note: 'Quick Restock');
  }

  /// Manual stock adjustment (recount, damaged, expired)
  Future<void> adjustStock(int productId, int targetQty, {String? reason}) async {
    try {
      await _stockRepo.adjustStock(productId, targetQty, note: reason);
      await loadProducts();
    } catch (e) {
      final idx = _products.indexWhere((p) => p.id == productId);
      if (idx != -1) {
        final old = _products[idx];
        _products[idx] = old.copyWith(stockQty: targetQty.clamp(0, 999999));
        notifyListeners();
      }
    }
  }

  /// Decrement stock in memory (used during active cart)
  void deductStock(int productId, int qty) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final old = _products[index];
      final newQty = (old.stockQty - qty).clamp(0, 999999);
      _products[index] = old.copyWith(stockQty: newQty);
      notifyListeners();
    }
  }

  /// Break mother pack into tingi units
  Future<void> breakPack(int packProductId) async {
    try {
      await _stockRepo.breakPack(packProductId);
      await loadProducts();
    } catch (e) {
      // Memory fallback for preview
      final packIdx = _products.indexWhere((p) => p.id == packProductId);
      if (packIdx != -1) {
        final pack = _products[packIdx];
        if (pack.stockQty > 0 &&
            pack.pieceProductId != null &&
            (pack.piecesPerPack ?? 0) > 0) {
          final pieceIdx =
              _products.indexWhere((p) => p.id == pack.pieceProductId);
          if (pieceIdx != -1) {
            final piece = _products[pieceIdx];
            _products[packIdx] = pack.copyWith(stockQty: pack.stockQty - 1);
            _products[pieceIdx] = piece.copyWith(
                stockQty: piece.stockQty + (pack.piecesPerPack ?? 0));
            notifyListeners();
            return;
          }
        }
      }
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
