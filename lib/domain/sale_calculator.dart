import '../data/models/cart_item.dart';
import '../data/models/customer.dart';

/// Pure business logic for Point-of-Sale (POS) calculations in integer centavos.
class SaleCalculator {
  const SaleCalculator._();

  /// Total quantity of items in cart.
  static int calculateItemCount(List<CartItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.qty);
  }

  /// Total sale amount in centavos: Σ (price_cents × qty).
  static int calculateTotalCents(List<CartItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.subtotalCents);
  }

  /// Estimated net profit in centavos: Σ ((price_cents - cost_cents) × qty).
  static int calculateProfitCents(List<CartItem> items) {
    return items.fold<int>(
      0,
      (sum, item) =>
          sum + ((item.product.priceCents - item.product.costCents) * item.qty),
    );
  }

  /// Change due to customer in centavos for cash payment. Returns 0 if utang or insufficient cash.
  static int calculateChangeCents({
    required int totalCents,
    required int cashReceivedCents,
    required bool isUtang,
  }) {
    if (isUtang) return 0;
    final diff = cashReceivedCents - totalCents;
    return diff > 0 ? diff : 0;
  }

  /// Validates whether checkout can proceed.
  static bool canCheckout({
    required List<CartItem> items,
    required bool isUtang,
    required int cashReceivedCents,
    required Customer? selectedCustomer,
  }) {
    if (items.isEmpty) return false;
    final total = calculateTotalCents(items);
    if (isUtang) {
      return selectedCustomer != null;
    }
    return cashReceivedCents >= total;
  }

  /// Checks whether an utang sale would exceed the customer's configured credit limit.
  /// Note: Owners may still override this warning per business rules.
  static bool exceedsCreditLimit({
    required Customer? customer,
    required int saleTotalCents,
  }) {
    if (customer == null) return false;
    final limit = customer.creditLimitCents;
    if (limit <= 0) return false;
    return (customer.balanceCents + saleTotalCents) > limit;
  }
}
