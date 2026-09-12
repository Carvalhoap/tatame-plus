class RecurringExpense {
  final String id;
  final String academyId;
  final String category;
  final String description;
  final int amountCents;
  final bool isActive;
  final DateTime? updatedAt;
  final String updatedBy;

  const RecurringExpense({
    required this.id,
    required this.academyId,
    required this.category,
    required this.description,
    required this.amountCents,
    required this.isActive,
    required this.updatedAt,
    required this.updatedBy,
  });

  double get amount => amountCents / 100;

  RecurringExpense copyWith({
    String? category,
    String? description,
    int? amountCents,
    bool? isActive,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return RecurringExpense(
      id: id,
      academyId: academyId,
      category: category ?? this.category,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
