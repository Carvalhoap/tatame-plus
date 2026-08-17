import '../../models/belt_color.dart';
import '../../models/graduation_template.dart';
import '../../models/martial_art_modality.dart';
import '../../models/progression_criterion.dart';

final ibjjfKids2026Template = GraduationTemplate(
  id: 'ibjjf_bjj_kids_2026_1',
  modality: MartialArtModality.brazilianJiuJitsu,
  organizationId: 'gracie_barra_ibjjf',
  organizationName: 'Gracie Barra / IBJJF',
  audience: GraduationTemplateAudience.kids,
  name: 'Programa Infantil',
  version: '2026.1',
  source: GraduationTemplateSource.academy,
  stages: _buildKidsStages(),
);

List<GraduationTemplateStage> _buildKidsStages() {
  const belts = [
    _KidsBeltSpec(id: 'white_belt', name: 'Branca', color: BeltColor.white),
    _KidsBeltSpec(
      id: 'grey_white_belt',
      name: 'Cinza e Branca',
      color: BeltColor.greyWhite,
    ),
    _KidsBeltSpec(id: 'grey_belt', name: 'Cinza', color: BeltColor.grey),
    _KidsBeltSpec(
      id: 'grey_black_belt',
      name: 'Cinza e Preta',
      color: BeltColor.greyBlack,
    ),
    _KidsBeltSpec(
      id: 'yellow_white_belt',
      name: 'Amarela e Branca',
      color: BeltColor.yellowWhite,
    ),
    _KidsBeltSpec(id: 'yellow_belt', name: 'Amarela', color: BeltColor.yellow),
    _KidsBeltSpec(
      id: 'yellow_black_belt',
      name: 'Amarela e Preta',
      color: BeltColor.yellowBlack,
    ),
    _KidsBeltSpec(
      id: 'orange_white_belt',
      name: 'Laranja e Branca',
      color: BeltColor.orangeWhite,
    ),
    _KidsBeltSpec(id: 'orange_belt', name: 'Laranja', color: BeltColor.orange),
    _KidsBeltSpec(
      id: 'orange_black_belt',
      name: 'Laranja e Preta',
      color: BeltColor.orangeBlack,
    ),
    _KidsBeltSpec(
      id: 'green_white_belt',
      name: 'Verde e Branca',
      color: BeltColor.greenWhite,
    ),
    _KidsBeltSpec(id: 'green_belt', name: 'Verde', color: BeltColor.green),
    _KidsBeltSpec(
      id: 'green_black_belt',
      name: 'Verde e Preta',
      color: BeltColor.greenBlack,
    ),
  ];

  final stages = <GraduationTemplateStage>[];
  var order = 1;

  for (var beltIndex = 0; beltIndex < belts.length; beltIndex++) {
    final belt = belts[beltIndex];

    for (var degree = 0; degree <= 4; degree++) {
      final isBaseBelt = degree == 0;

      final stageId = isBaseBelt ? belt.id : '${belt.id}_degree_$degree';

      String? nextStageId;

      if (degree < 4) {
        nextStageId = '${belt.id}_degree_${degree + 1}';
      } else if (beltIndex < belts.length - 1) {
        nextStageId = belts[beltIndex + 1].id;
      }

      stages.add(
        GraduationTemplateStage(
          id: stageId,
          name: isBaseBelt
              ? 'Faixa ${belt.name}'
              : 'Faixa ${belt.name} - $degreeº grau',
          beltColor: belt.color,
          beltName: belt.name,
          degreeName: isBaseBelt ? null : '$degreeº grau',
          stripeColor: isBaseBelt ? null : 'Branca',
          order: order,
          criterion: ProgressionCriterion.manual,
          nextStageId: nextStageId,
        ),
      );

      order++;
    }
  }

  return List.unmodifiable(stages);
}

class _KidsBeltSpec {
  final String id;
  final String name;
  final BeltColor color;

  const _KidsBeltSpec({
    required this.id,
    required this.name,
    required this.color,
  });
}
