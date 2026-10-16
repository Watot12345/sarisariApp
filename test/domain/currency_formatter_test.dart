import 'package:flutter_test/flutter_test.dart';
import 'package:tindahan/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter tests (Integer Centavos to Peso)', () {
    test('Formats centavos to standard Peso format with 2 decimals', () {
      expect(CurrencyFormatter.format(1250), '₱12.50');
      expect(CurrencyFormatter.format(100), '₱1.00');
      expect(CurrencyFormatter.format(0), '₱0.00');
      expect(CurrencyFormatter.format(125050), '₱1,250.50');
      expect(CurrencyFormatter.format(100000), '₱1,000.00');
    });

    test('Formats compact values when exactly zero cents', () {
      expect(CurrencyFormatter.formatCompact(5000), '₱50');
      expect(CurrencyFormatter.formatCompact(100000), '₱1,000');
      expect(CurrencyFormatter.formatCompact(1250), '₱12.50');
    });

    test('Parses peso string to integer centavos without float errors', () {
      expect(CurrencyFormatter.parsePesosToCentavos('12.50'), 1250);
      expect(CurrencyFormatter.parsePesosToCentavos('₱12.50'), 1250);
      expect(CurrencyFormatter.parsePesosToCentavos('1000'), 100000);
      expect(CurrencyFormatter.parsePesosToCentavos('0.75'), 75);
    });
  });
}
