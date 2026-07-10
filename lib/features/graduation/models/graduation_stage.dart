import 'progression_criterion.dart';

class GraduationStage {
  final String id;

  final String name;
  final String beltName;
  final String? degreeName;
  final String? stripeColor;

  final int order;

  final ProgressionCriterion criterion;

  final int? requiredAttendances;
  final int? minimumDurationMonths;

  final String? nextStageId;

  const GraduationStage({
    required this.id,
    required this.name,
    required this.beltName,
    this.degreeName,
    this.stripeColor,
    required this.order,
    required this.criterion,
    this.requiredAttendances,
    this.minimumDurationMonths,
    this.nextStageId,
  });
}