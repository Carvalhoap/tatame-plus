class FinanceSettings {
  final String academyId;
  final int gympassCheckInValueCents;
  final int gympassMonthlyLimit;
  final int movingFitnessPercentage;
  final String instructorName;
  final int instructorFixedAmountCents;
  final int gracieBarraReservePercentage;
  final int remainingPartnersCount;
  final DateTime? updatedAt;
  final String updatedBy;

  const FinanceSettings({
    required this.academyId,
    required this.gympassCheckInValueCents,
    required this.gympassMonthlyLimit,
    required this.movingFitnessPercentage,
    required this.instructorName,
    required this.instructorFixedAmountCents,
    required this.gracieBarraReservePercentage,
    required this.remainingPartnersCount,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory FinanceSettings.defaults({required String academyId}) {
    return FinanceSettings(
      academyId: academyId,
      gympassCheckInValueCents: 1349,
      gympassMonthlyLimit: 12,
      movingFitnessPercentage: 50,
      instructorName: 'Professor Wagner',
      instructorFixedAmountCents: 80000,
      gracieBarraReservePercentage: 40,
      remainingPartnersCount: 2,
      updatedAt: null,
      updatedBy: '',
    );
  }

  double get gympassCheckInValue => gympassCheckInValueCents / 100;

  double get instructorFixedAmount => instructorFixedAmountCents / 100;
}
