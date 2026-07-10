import 'graduation_stage.dart';

enum GraduationAudience {
  kids,
  adult,
  custom,
}

class GraduationProgram {
  final String id;
  final String academyId;

  final String name;
  final GraduationAudience audience;

  final List<GraduationStage> stages;

  final bool isActive;

  const GraduationProgram({
    required this.id,
    required this.academyId,
    required this.name,
    required this.audience,
    required this.stages,
    this.isActive = true,
  });
}