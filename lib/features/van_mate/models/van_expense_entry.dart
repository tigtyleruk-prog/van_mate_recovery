class VanExpenseEntry {
  const VanExpenseEntry({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.supplier = '',
    this.notes = '',
    this.receiptPath,
    this.receiptName,
  });

  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String supplier;
  final String notes;
  final String? receiptPath;
  final String? receiptName;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasReceipt => receiptPath?.trim().isNotEmpty == true;
  bool get hasNotes => notes.trim().isNotEmpty == true;
  bool get hasSupplier => supplier.trim().isNotEmpty == true;
  String get description => supplier;
  bool get hasDescription => hasSupplier;

  VanExpenseEntry copyWith({
    String? id,
    double? amount,
    String? category,
    DateTime? date,
    String? supplier,
    String? notes,
    String? receiptPath,
    String? receiptName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VanExpenseEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      supplier: supplier ?? this.supplier,
      notes: notes ?? this.notes,
      receiptPath: receiptPath ?? this.receiptPath,
      receiptName: receiptName ?? this.receiptName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'supplier': supplier,
      'notes': notes,
      'receiptPath': receiptPath,
      'receiptName': receiptName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory VanExpenseEntry.fromJson(Map<String, dynamic> json) {
    DateTime readDate(String key, {DateTime? fallback}) {
      final raw = json[key]?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return fallback ?? DateTime.now();
      }
      return DateTime.tryParse(raw) ?? (fallback ?? DateTime.now());
    }

    String readText(String key) {
      return (json[key]?.toString().trim() ?? '');
    }

    final amount = double.tryParse(json['amount']?.toString() ?? '') ?? 0;

    return VanExpenseEntry(
      id: readText('id').isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : readText('id'),
      amount: amount,
      category: readText('category').isEmpty ? 'Other' : readText('category'),
      date: readDate('date'),
      supplier: readText('supplier'),
      notes: readText('notes'),
      receiptPath: readText('receiptPath').isEmpty
          ? null
          : readText('receiptPath'),
      receiptName: readText('receiptName').isEmpty
          ? null
          : readText('receiptName'),
      createdAt: readDate('createdAt', fallback: readDate('date')),
      updatedAt: readDate('updatedAt', fallback: readDate('date')),
    );
  }
}
