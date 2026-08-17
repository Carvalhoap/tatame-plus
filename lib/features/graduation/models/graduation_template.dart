import 'belt_color.dart';
import 'martial_art_modality.dart';
import 'progression_criterion.dart';

enum GraduationTemplateAudience { adult, juvenile, kids, custom }

enum GraduationTemplateSource { official, academy, custom }

class GraduationTemplateStage {
  final String id;
  final String name;
  final BeltColor beltColor;
  final String beltName;
  final String? degreeName;
  final String? stripeColor;

  final int order;

  final ProgressionCriterion criterion;
  final int? requiredAttendances;
  final int? minimumDurationMonths;

  final String? nextStageId;

  const GraduationTemplateStage({
    required this.id,
    required this.name,
    required this.beltColor,
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

class GraduationTemplate {
  final String id;

  final MartialArtModality modality;

  final String organizationId;
  final String organizationName;

  final GraduationTemplateAudience audience;

  final String name;
  final String version;

  final GraduationTemplateSource source;

  final List<GraduationTemplateStage> stages;

  final bool isActive;

  const GraduationTemplate({
    required this.id,
    required this.modality,
    required this.organizationId,
    required this.organizationName,
    required this.audience,
    required this.name,
    required this.version,
    required this.source,
    required this.stages,
    this.isActive = true,
  });

  List<GraduationTemplateStage> get orderedStages {
    final result = List<GraduationTemplateStage>.of(stages);

    result.sort((a, b) => a.order.compareTo(b.order));

    return result;
  }
}
