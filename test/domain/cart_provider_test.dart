import 'package:flutter_test/flutter_test.dart';
import 'package:tindahan/data/models/product.dart';
import 'package:tindahan/features/sell/providers/cart_provider.dart';

void main() {
  group('CartProvider POS state tests', () {
    late CartProvider cart;
    const testProduct = Product(
      id: 1,
      name: 'Lucky Me Pancit Canton',
      priceCents: 1500, // ₱15.00
      costCents: 1250,  // ₱12.50
      stockQty: 5,
    );

    setUp(() {
      cart = CartProvider();
    });

    test('Adding product adds to cart and sets exact cash default', () {
      final success = cart.addToCart(testProduct);
      expect(success, isTrue);
      expect(cart.items.length, 1);
      expect(cart.totalCents, 1500);
      expect(cart.cashReceivedCents, 1500);
      expect(cart.changeCents, 0);
    });

    test('Enforces stock limit guard: cannot exceed available stock', () {
      for (int i = 0; i < 5; i++) {
        expect(cart.addToCart(testProduct), isTrue);
      }
      expect(cart.items.first.qty, 5);

      // Attempt 6th addition should fail
      final sixthAdd = cart.addToCart(testProduct);
      expect(sixthAdd, isFalse);
      expect(cart.items.first.qty, 5);
      expect(cart.errorMessage, isNotNull);
    });

    test('Computes change accurately for cash tendered', () {
      cart.addToCart(testProduct); // ₱15.00
      cart.setCashReceived(5000);  // Customer gives ₱50.00
      expect(cart.changeCents, 3500); // Change should be ₱35.00 (3500 centavos)
    });
  });
}
