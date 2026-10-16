import 'package:intl/intl.dart';

/// Handles formatting and parsing money strictly as integer centavos.
/// Hard constraint: ₱12.50 is stored as 1250 centavos. No floating-point math.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  /// Formats centavos to standard currency string (e.g. 1250 -> "₱12.50")
  static String format(int centavos) {
    final double pesos = centavos / 100.0;
    return _formatter.format(pesos);
  }

  /// Formats centavos without decimals when exactly zero cents (e.g. 5000 -> "₱50")
  static String formatCompact(int centavos) {
    if (centavos % 100 == 0) {
      return _compactFormatter.format(centavos ~/ 100);
    }
    return format(centavos);
  }

  /// Converts a peso decimal string (e.g. "12.50") to integer centavos (1250)
  static int parsePesosToCentavos(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return 0;

    final parts = cleaned.split('.');
    final pesos = int.tryParse(parts[0]) ?? 0;
    if (parts.length == 1) {
      return pesos * 100;
    }

    final centsPart = parts[1].padRight(2, '0').substring(0, 2);
    final cents = int.tryParse(centsPart) ?? 0;
    return (pesos * 100) + cents;
  }
}
