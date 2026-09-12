import 'finance_enums.dart';
import 'finance_period.dart';

class BillingCycle {
  final String id;
  final String academyId;
  final String studentId;
  final FinancePeriod period;
  final BillingMode billingMode;
  final int expectedAmountCents;
  final int paidAmountCents;
  final DateTime dueDate;
  final BillingStatus status;
  final PaymentMethod? paymentMethod;
  final RevenueDestination revenueDestination;
  final String? paymentProofId;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BillingCycle({
    required this.id,
    required this.academyId,
    required this.studentId,
    required this.period,
    required this.billingMode,
    required this.expectedAmountCents,
    required this.paidAmountCents,
    required this.dueDate,
    required this.status,
    required this.paymentMethod,
    this.revenueDestination = RevenueDestination.movingFitness,
    required this.paymentProofId,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get referenceKey => period.key;

  int get referenceYear => period.referenceYear;

  int get referenceMonth => period.referenceMonth;

  int get outstandingAmountCents {
    final outstanding = expectedAmountCents - paidAmountCents;

    return outstanding > 0 ? outstanding : 0;
  }

  double get expectedAmount => expectedAmountCents / 100;

  double get paidAmount => paidAmountCents / 100;

  double get outstandingAmount => outstandingAmountCents / 100;

  bool get isPaid => status == BillingStatus.paid;

  bool get isGympass => billingMode == BillingMode.gympass;

  bool get isSharedWithMoving {
    return revenueDestination == RevenueDestination.movingFitness;
  }
}
