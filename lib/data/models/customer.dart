/// Customer data model for utang credit ledger with risk assessment fields.
class Customer {
  final int id;
  final String name;
  final String? nickname;
  final String? phone;
  final int creditLimitCents; // e.g. 50000 = ₱500.00
  final int balanceCents;     // Derived: charges - payments from utang_entries
  final int? riskScore;       // 0-100
  final String? riskLevel;    // 'low', 'medium', 'high', null = 'new'
  final String? notes;
  final bool isActive;
  final String? createdAt;

  const Customer({
    required this.id,
    required this.name,
    this.nickname,
    this.phone,
    this.creditLimitCents = 0,
    this.balanceCents = 0,
    this.riskScore,
    this.riskLevel,
    this.notes,
    this.isActive = true,
    this.createdAt,
  });

  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) {
      return '$name ($nickname)';
    }
    return name;
  }

  factory Customer.fromMap(Map<String, dynamic> map, {int balanceCents = 0}) {
    final rawName = map['name'] as String;
    String name = rawName;
    String? nickname;

    // Extract nickname if stored formatted as "Name (Nickname)"
    final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(rawName);
    if (match != null) {
      name = match.group(1)?.trim() ?? rawName;
      nickname = match.group(2)?.trim();
    }

    return Customer(
      id: map['id'] as int,
      name: name,
      nickname: nickname,
      phone: map['phone'] as String?,
      creditLimitCents: (map['credit_limit_cents'] as int?) ?? 0,
      balanceCents: (map['balance_cents'] as int?) ?? balanceCents,
      riskScore: map['risk_score'] as int?,
      riskLevel: map['risk_level'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toUtc().toIso8601String();
    final storedName = (nickname != null && nickname!.isNotEmpty && !name.contains('('))
        ? '$name ($nickname)'
        : name;

    return {
      if (id > 0) 'id': id,
      'name': storedName,
      'phone': phone,
      'credit_limit_cents': creditLimitCents,
      'notes': notes,
      'risk_score': riskScore,
      'risk_level': riskLevel,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt ?? now,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? nickname,
    String? phone,
    int? creditLimitCents,
    int? balanceCents,
    int? riskScore,
    String? riskLevel,
    String? notes,
    bool? isActive,
    String? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      phone: phone ?? this.phone,
      creditLimitCents: creditLimitCents ?? this.creditLimitCents,
      balanceCents: balanceCents ?? this.balanceCents,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
