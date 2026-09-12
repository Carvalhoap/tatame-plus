class CheckInProvider {
  final String id;
  final String academyId;
  final String name;
  final int checkInValueCents;
  final int monthlyLimit;
  final bool sharesWithMoving;
  final bool isActive;
  final DateTime? updatedAt;
  final String updatedBy;

  const CheckInProvider({
    required this.id,
    required this.academyId,
    required this.name,
    required this.checkInValueCents,
    required this.monthlyLimit,
    required this.sharesWithMoving,
    required this.isActive,
    required this.updatedAt,
    required this.updatedBy,
  });

  double get checkInValue => checkInValueCents / 100;

  CheckInProvider copyWith({
    String? name,
    int? checkInValueCents,
    int? monthlyLimit,
    bool? sharesWithMoving,
    bool? isActive,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CheckInProvider(
      id: id,
      academyId: academyId,
      name: name ?? this.name,
      checkInValueCents: checkInValueCents ?? this.checkInValueCents,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      sharesWithMoving: sharesWithMoving ?? this.sharesWithMoving,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
