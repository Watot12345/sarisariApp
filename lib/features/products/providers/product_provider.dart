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
  bool _isLoading = false;
  String? _errorMessage;

  static const List<Product> _initialProducts = [
    Product(
      id: 1,
      name: 'Lucky Me Pancit Canton Kalamansi',
      barcode: '4800016644023',
      categoryName: 'Noodles',
      priceCents: 1500,
      costCents: 1250,
      stockQty: 24,
      lowStockLevel: 8,
    ),
    Product(
      id: 2,
      name: 'Lucky Me Pancit Canton Chilimansi',
      barcode: '4800016644030',
      categoryName: 'Noodles',
      priceCents: 1500,
      costCents: 1250,
      stockQty: 18,
      lowStockLevel: 8,
    ),
    Product(
      id: 3,
      name: 'Coca-Cola Mismo 290ml',
      barcode: '4801981110022',
      categoryName: 'Drinks',
      priceCents: 2000,
      costCents: 1650,
      stockQty: 32,
      lowStockLevel: 10,
    ),
    Product(
      id: 4,
      name: 'Sprite Mismo 290ml',
      barcode: '4801981110039',
      categoryName: 'Drinks',
      priceCents: 2000,
      costCents: 1650,
      stockQty: 4,
      lowStockLevel: 10,
    ),
    Product(
      id: 5,
      name: 'Piattos Cheese 85g',
      barcode: '4800016054112',
      categoryName: 'Snacks',
      priceCents: 3800,
      costCents: 3200,
      stockQty: 12,
      lowStockLevel: 5,
    ),
    Product(
      id: 6,
      name: 'Nissin Cup Noodles Seafood',
      categoryName: 'Noodles',
      priceCents: 2800,
      costCents: 2350,
      stockQty: 6,
      lowStockLevel: 5,
    ),
    Product(
      id: 7,
      name: 'Kopiko Blanca 3-in-1 Sachet',
      categoryName: 'Coffee',
      priceCents: 1400,
      costCents: 1100,
      stockQty: 45,
      lowStockLevel: 15,
    ),
    Product(
      id: 8,
      name: 'Great Taste White Coffee Sachet',
      categoryName: 'Coffee',
      priceCents: 1400,
      costCents: 1100,
      stockQty: 30,
      lowStockLevel: 15,
    ),
    Product(
      id: 9,
      name: 'Safeguard Pure White Soap 60g',
      categoryName: 'Toiletries',
      priceCents: 2600,
      costCents: 2150,
      stockQty: 8,
      lowStockLevel: 5,
    ),
    Product(
      id: 10,
      name: 'Tide Plus Detergent Powder Sachet',
      categoryName: 'Household',
      priceCents: 1600,
      costCents: 1300,
      stockQty: 3,
      lowStockLevel: 10,
    ),
    Product(
      id: 11,
      name: 'Skyflakes Crackers Single Pack',
      categoryName: 'Snacks',
      priceCents: 800,
      costCents: 625,
      stockQty: 25,
      lowStockLevel: 10,
    ),
    Product(
      id: 12,
      name: 'Marlboro Red (Stick - Tingi)',
      categoryName: 'Cigarettes',
      priceCents: 1000,
      costCents: 800,
      stockQty: 60,
      lowStockLevel: 20,
    ),
    Product(
      id: 13,
      name: 'Datu Puti Soy Sauce 200ml',
      categoryName: 'Condiments',
      priceCents: 1900,
      costCents: 1550,
      stockQty: 14,
      lowStockLevel: 6,
    ),
    Product(
      id: 14,
      name: 'Datu Puti Vinegar 200ml',
      categoryName: 'Condiments',
      priceCents: 1700,
      costCents: 1380,
      stockQty: 0,
      lowStockLevel: 6,
    ),
    Product(
      id: 15,
      name: 'Mega Sardines Red 155g',
      barcode: '4806502010014',
      categoryName: 'Canned Goods',
      priceCents: 2500,
      costCents: 2100,
      stockQty: 15,
      lowStockLevel: 6,
    ),
  ];

  List<Product> _products = List.of(_initialProducts);

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

  List<String> get categories {
    final set = {'All', ..._products.map((p) => p.categoryName)};
    return set.toList();
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

      return matchesQuery && matchesCategory && matchesLowStock;
    }).toList();
  }

  List<Product> get lowStockProducts {
    return _products.where((p) => p.isLowStock || p.isOutOfStock).toList();
  }

  /// Reloads products from SQLite database; keeps defaults if in web preview
  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dbProducts = await _productRepo.getProducts();
      if (dbProducts.isNotEmpty) {
        _products = dbProducts;
      }
    } catch (e) {
      // In web or fallback mode, initial products remain loaded
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
