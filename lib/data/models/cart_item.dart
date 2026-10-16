import 'product.dart';

/// Item in the active shopping cart before checkout.
class CartItem {
  final Product product;
  int qty;

  CartItem({
    required this.product,
    this.qty = 1,
  });

  int get subtotalCents => product.priceCents * qty;
  int get profitCents => (product.priceCents - product.costCents) * qty;
}
