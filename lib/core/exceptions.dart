/// Custom typed exceptions for Tindahan domain and repository layer.
class TindahanException implements Exception {
  final String message;
  const TindahanException(this.message);

  @override
  String toString() => message;
}

class OutOfStockException extends TindahanException {
  final String productName;
  final int availableQty;
  final int requestedQty;

  const OutOfStockException({
    required this.productName,
    required this.availableQty,
    required this.requestedQty,
  }) : super('Hindi sapat ang stock para sa $productName (Available: $availableQty, Needed: $requestedQty)');
}

class DuplicateBarcodeException extends TindahanException {
  final String barcode;
  const DuplicateBarcodeException(this.barcode)
      : super('May produkto nang may parehong barcode: $barcode');
}

class ValidationException extends TindahanException {
  const ValidationException(super.message);
}
