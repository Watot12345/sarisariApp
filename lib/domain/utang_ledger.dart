import '../core/utils/currency_formatter.dart';
import '../data/models/customer.dart';
import '../data/models/utang_entry.dart';

/// One row in a customer's ledger timeline with the balance right after that entry.
class LedgerLine {
  final UtangEntry entry;
  final int runningBalanceCents;

  const LedgerLine({required this.entry, required this.runningBalanceCents});
}

/// Pure Dart helpers for the Utang ledger (no Flutter / SQLite dependencies).
/// Balance rule: Σ charges − Σ payments.
class UtangLedger {
  UtangLedger._();

  /// Net balance from a list of entries.
  static int balanceOf(List<UtangEntry> entries) {
    var bal = 0;
    for (final e in entries) {
      if (e.isCharge) bal += e.amountCents;
      if (e.isPayment) bal -= e.amountCents;
    }
    return bal;
  }

  /// Builds chronological ledger lines (oldest first) with running balances.
  static List<LedgerLine> buildRunningLedger(List<UtangEntry> entries) {
    final sorted = List<UtangEntry>.of(entries)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    var running = 0;
    return sorted.map((e) {
      if (e.isCharge) running += e.amountCents;
      if (e.isPayment) running -= e.amountCents;
      return LedgerLine(entry: e, runningBalanceCents: running);
    }).toList();
  }

  /// Payment rule: amount > 0 and ≤ current balance (partial payments allowed).
  /// Returns an error message, or null when valid.
  static String? validatePayment({
    required int amountCents,
    required int balanceCents,
  }) {
    if (amountCents <= 0) return 'Payment must be greater than ₱0.00';
    if (balanceCents <= 0) return 'This customer has no outstanding utang';
    if (amountCents > balanceCents) {
      return 'Payment cannot exceed balance of ${CurrencyFormatter.format(balanceCents)}';
    }
    return null;
  }

  /// Plain-text statement for sharing (SMS / Messenger / Viber).
  static String buildStatement({
    required String storeName,
    required Customer customer,
    required List<UtangEntry> entries,
    DateTime? now,
    int maxEntries = 10,
  }) {
    final date = (now ?? DateTime.now());
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final lines = buildRunningLedger(entries);
    final recent = lines.length > maxEntries
        ? lines.sublist(lines.length - maxEntries)
        : lines;
    final balance = balanceOf(entries);

    final buf = StringBuffer()
      ..writeln('$storeName — Utang Statement')
      ..writeln('Customer: ${customer.displayName}')
      ..writeln('Date: $dateStr')
      ..writeln('------------------------------');

    if (recent.isEmpty) {
      buf.writeln('No utang entries yet.');
    } else {
      for (final l in recent) {
        final d = l.entry.createdAt.length >= 10
            ? l.entry.createdAt.substring(0, 10)
            : l.entry.createdAt;
        final sign = l.entry.isCharge ? '+' : '-';
        final label = l.entry.isCharge ? 'Utang' : 'Bayad';
        buf.writeln(
          '$d  $label  $sign${CurrencyFormatter.format(l.entry.amountCents)}',
        );
      }
    }

    buf
      ..writeln('------------------------------')
      ..writeln('Current Balance: ${CurrencyFormatter.format(balance)}')
      ..writeln('Salamat po!');
    return buf.toString();
  }
}
