import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/exceptions.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/utang_entry.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../../data/repositories/utang_repository.dart';
import '../../../domain/utang_ledger.dart';

/// Provider managing customer debtors, risk scores, and credit payments backed by SQLite.
class UtangProvider extends ChangeNotifier {
  final CustomerRepository _customerRepo;
  final UtangRepository _utangRepo;

  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  static const List<Customer> _initialCustomers = [
    Customer(
      id: 1,
      name: 'Elena Santos',
      nickname: 'Aling Nena',
      phone: '09171234567',
      creditLimitCents: 100000,
      balanceCents: 45000,
      riskScore: 22,
      riskLevel: 'low',
      notes: 'Pays every Friday payday',
    ),
    Customer(
      id: 2,
      name: 'Rodrigo Cruz',
      nickname: 'Mang Digong',
      phone: '09287654321',
      creditLimitCents: 50000,
      balanceCents: 48000,
      riskScore: 54,
      riskLevel: 'medium',
      notes: 'Remind before month end',
    ),
    Customer(
      id: 3,
      name: 'Jun-Jun Bautista',
      nickname: 'Tricycle Driver',
      creditLimitCents: 30000,
      balanceCents: 32000,
      riskScore: 78,
      riskLevel: 'high',
      notes: 'Overdue by 3 weeks; stop giving credit',
    ),
    Customer(
      id: 4,
      name: 'Teresa Reyes',
      nickname: 'Ate Tess',
      phone: '09051112233',
      creditLimitCents: 150000,
      balanceCents: 15000,
      riskScore: 15,
      riskLevel: 'low',
    ),
    Customer(
      id: 5,
      name: 'Michael Tan',
      nickname: 'Bagong Lipat',
      creditLimitCents: 20000,
      balanceCents: 0,
      riskScore: null,
      riskLevel: null,
      notes: 'New in neighborhood',
    ),
  ];

  List<Customer> _customers = List.of(_initialCustomers);

  UtangProvider({
    CustomerRepository? customerRepo,
    UtangRepository? utangRepo,
  })  : _customerRepo = customerRepo ?? CustomerRepository(),
        _utangRepo = utangRepo ?? UtangRepository() {
    loadCustomers();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Customer> get allCustomers => List.unmodifiable(_customers);
  String get searchQuery => _searchQuery;

  int get totalReceivablesCents =>
      _customers.fold(0, (sum, c) => sum + (c.isActive ? c.balanceCents : 0));

  List<Customer> get filteredCustomers {
    return _customers.where((c) {
      if (!c.isActive) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nameMatches = c.name.toLowerCase().contains(q);
      final nickMatches = c.nickname != null && c.nickname!.toLowerCase().contains(q);
      return nameMatches || nickMatches;
    }).toList();
  }

  /// Reloads all customers and their live utang balances from SQLite
  Future<void> loadCustomers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dbCustomers = await _customerRepo.getCustomers();
      if (dbCustomers.isNotEmpty) {
        _customers = dbCustomers;
      }
    } catch (e) {
      debugPrint('UtangProvider note: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Customer? customerById(int id) =>
      _customers.where((c) => c.id == id).firstOrNull;

  // ---------------- Ledger ----------------
  final Map<int, List<UtangEntry>> _ledgers = {};

  /// Cached ledger entries for a customer (oldest first). Call [loadLedger] to refresh.
  List<UtangEntry> ledgerFor(int customerId) =>
      List.unmodifiable(_ledgers[customerId] ?? const []);

  /// Loads the customer's ledger timeline from SQLite (voided-sale charges excluded).
  Future<List<UtangEntry>> loadLedger(int customerId) async {
    try {
      final entries = await _utangRepo.getEntriesForCustomer(customerId);
      _ledgers[customerId] = entries;
    } catch (e) {
      debugPrint('UtangProvider ledger note: $e');
      _ledgers.putIfAbsent(customerId, () => []);
    }
    notifyListeners();
    return ledgerFor(customerId);
  }

  /// Records a (partial or full) payment. Rule: 0 < amount ≤ current balance.
  /// Returns true on success; sets [errorMessage] on failure.
  Future<bool> recordPayment(int customerId, int paymentCents, {String? note}) async {
    _errorMessage = null;
    final customer = customerById(customerId);
    final balance = customer?.balanceCents ?? 0;
    final error = UtangLedger.validatePayment(
      amountCents: paymentCents,
      balanceCents: balance,
    );
    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return false;
    }

    try {
      await _utangRepo.recordPayment(customerId, paymentCents, note: note);
      await loadCustomers();
      if (_ledgers.containsKey(customerId)) await loadLedger(customerId);
      return true;
    } on ValidationException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      // Memory fallback (web preview)
      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        final old = _customers[index];
        _customers[index] = old.copyWith(balanceCents: old.balanceCents - paymentCents);
        notifyListeners();
      }
      return true;
    }
  }

  /// Registers a new customer. Returns the new id, or null if validation fails.
  Future<int?> addCustomer({
    required String name,
    String? nickname,
    String? phone,
    int creditLimitCents = 50000,
    String? notes,
  }) async {
    _errorMessage = null;
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      _errorMessage = 'Customer name is required';
      notifyListeners();
      return null;
    }
    if (creditLimitCents < 0) {
      _errorMessage = 'Credit limit cannot be negative';
      notifyListeners();
      return null;
    }

    final customer = Customer(
      id: 0,
      name: cleanName,
      nickname: (nickname?.trim().isEmpty ?? true) ? null : nickname!.trim(),
      phone: (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
      creditLimitCents: creditLimitCents,
      balanceCents: 0,
      notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
    );

    try {
      final id = await _customerRepo.insertCustomer(customer);
      await loadCustomers();
      return id;
    } catch (e) {
      final newId = _customers.isEmpty
          ? 1
          : _customers.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
      _customers.add(customer.copyWith(id: newId));
      notifyListeners();
      return newId;
    }
  }

  /// Updates customer details (name, nickname, phone, credit limit, notes).
  Future<bool> updateCustomer(Customer customer) async {
    _errorMessage = null;
    if (customer.name.trim().isEmpty) {
      _errorMessage = 'Customer name is required';
      notifyListeners();
      return false;
    }
    try {
      await _customerRepo.updateCustomer(customer);
      await loadCustomers();
    } catch (e) {
      final idx = _customers.indexWhere((c) => c.id == customer.id);
      if (idx != -1) _customers[idx] = customer;
      notifyListeners();
    }
    return true;
  }

  /// Plain-text statement: store name, customer, date, recent entries, balance.
  String buildStatement(int customerId, {String storeName = AppConstants.appName}) {
    final customer = customerById(customerId);
    if (customer == null) return '';
    return UtangLedger.buildStatement(
      storeName: storeName,
      customer: customer,
      entries: ledgerFor(customerId),
    );
  }

  /// Add utang charge to a customer (used in sell checkout)
  void addCharge(int customerId, int amountCents) {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final old = _customers[index];
      _customers[index] = old.copyWith(balanceCents: old.balanceCents + amountCents);
      notifyListeners();
    }
  }
}
