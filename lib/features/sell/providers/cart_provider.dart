import 'package:flutter/material.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/product.dart';
import '../../../data/models/sale.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../domain/sale_calculator.dart';
import '../../products/providers/product_provider.dart';
import '../../utang/providers/utang_provider.dart';

enum PaymentMode { cash, utang }

/// Cart Provider managing items, quantities, stock guards, transactional checkouts, and sales history/voiding.
class CartProvider extends ChangeNotifier {
  final SaleRepository _saleRepo;
  final List<CartItem> _items = [];
  List<Sale> _recentSales = [];

  PaymentMode _paymentMode = PaymentMode.cash;
  int _cashReceivedCents = 0;
  Customer? _selectedCustomer;
  String? _errorMessage;

  CartProvider({SaleRepository? saleRepo}) : _saleRepo = saleRepo ?? SaleRepository();

  // Getters
  List<CartItem> get items => List.unmodifiable(_items);
  List<Sale> get recentSales => List.unmodifiable(_recentSales);
  PaymentMode get paymentMode => _paymentMode;
  int get cashReceivedCents => _cashReceivedCents;
  Customer? get selectedCustomer => _selectedCustomer;
  String? get errorMessage => _errorMessage;

  int get itemCount => SaleCalculator.calculateItemCount(_items);

  int get totalCents => SaleCalculator.calculateTotalCents(_items);

  int get profitCents => SaleCalculator.calculateProfitCents(_items);

  int get changeCents => SaleCalculator.calculateChangeCents(
        totalCents: totalCents,
        cashReceivedCents: _cashReceivedCents,
        isUtang: _paymentMode == PaymentMode.utang,
      );

  bool get canCheckout => SaleCalculator.canCheckout(
        items: _items,
        isUtang: _paymentMode == PaymentMode.utang,
        cashReceivedCents: _cashReceivedCents,
        selectedCustomer: _selectedCustomer,
      );

  bool get exceedsCreditLimit => SaleCalculator.exceedsCreditLimit(
        customer: _selectedCustomer,
        saleTotalCents: totalCents,
      );

  // Cart Manipulations
  bool addToCart(Product product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);
    if (index != -1) {
      if (_items[index].qty >= product.stockQty) {
        _errorMessage = 'Hindi na maaaring lumampas sa available na stock (${product.stockQty}).';
        notifyListeners();
        return false;
      }
      _items[index].qty += 1;
    } else {
      if (product.stockQty <= 0) {
        _errorMessage = 'Out of stock ang produktong ito.';
        notifyListeners();
        return false;
      }
      _items.add(CartItem(product: product, qty: 1));
    }
    _cashReceivedCents = totalCents;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  bool incrementQty(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      final item = _items[index];
      if (item.qty >= item.product.stockQty) {
        _errorMessage = 'Hindi na maaaring lumampas sa available na stock.';
        notifyListeners();
        return false;
      }
      item.qty += 1;
      _cashReceivedCents = totalCents;
      _errorMessage = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  void decrementQty(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      if (_items[index].qty > 1) {
        _items[index].qty -= 1;
      } else {
        _items.removeAt(index);
      }
      _cashReceivedCents = totalCents;
      _errorMessage = null;
      notifyListeners();
    }
  }

  CartItem? removeItem(int productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      final removed = _items.removeAt(index);
      _cashReceivedCents = totalCents;
      notifyListeners();
      return removed;
    }
    return null;
  }

  void restoreItem(CartItem item) {
    _items.add(item);
    _cashReceivedCents = totalCents;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _cashReceivedCents = 0;
    _selectedCustomer = null;
    _errorMessage = null;
    _paymentMode = PaymentMode.cash;
    notifyListeners();
  }

  // Payment Setup
  void setPaymentMode(PaymentMode mode) {
    _paymentMode = mode;
    notifyListeners();
  }

  void setCashReceived(int centavos) {
    _cashReceivedCents = centavos;
    notifyListeners();
  }

  void setExactCash() {
    _cashReceivedCents = totalCents;
    notifyListeners();
  }

  void selectCustomer(Customer customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// Loads recent sales from SQLite for the POS Sales History sheet.
  Future<void> loadRecentSales() async {
    try {
      _recentSales = await _saleRepo.getRecentSales(limit: 50);
      notifyListeners();
    } catch (_) {}
  }

  /// Finalize sale in SQLite and update inventory & utang ledgers
  Future<bool> completeSale({
    required ProductProvider productProvider,
    UtangProvider? utangProvider,
  }) async {
    if (!canCheckout) return false;

    try {
      await _saleRepo.createSale(
        items: List.of(_items),
        paymentType: _paymentMode == PaymentMode.cash ? 'cash' : 'utang',
        cashReceivedCents: _cashReceivedCents,
        changeCents: changeCents,
        customerId: _selectedCustomer?.id,
      );

      // Refresh stores from SQLite
      await productProvider.loadProducts();
      if (_paymentMode == PaymentMode.utang && utangProvider != null) {
        await utangProvider.loadCustomers();
      }
      await loadRecentSales();

      clearCart();
      return true;
    } catch (e) {
      // Memory fallback when running in Web/test preview
      for (final item in _items) {
        productProvider.deductStock(item.product.id, item.qty);
      }
      if (_paymentMode == PaymentMode.utang && utangProvider != null && _selectedCustomer != null) {
        utangProvider.addCharge(_selectedCustomer!.id, totalCents);
      }
      clearCart();
      return true;
    }
  }

  /// Voids a completed sale in SQLite, restoring product stock and reversing utang balance.
  Future<bool> voidSale(
    int saleId, {
    required String reason,
    required ProductProvider productProvider,
    UtangProvider? utangProvider,
  }) async {
    try {
      await _saleRepo.voidSale(saleId, reason: reason);
      await productProvider.loadProducts();
      if (utangProvider != null) {
        await utangProvider.loadCustomers();
      }
      await loadRecentSales();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
