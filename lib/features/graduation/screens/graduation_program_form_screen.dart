import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/graduation_program.dart';
import '../models/graduation_stage.dart';
import '../models/progression_criterion.dart';
import '../repository/graduation_program_repository.dart';
import '../data/graduation_template_catalog.dart';
import '../models/graduation_template.dart';
import '../models/martial_art_modality.dart';

class GraduationProgramFormScreen extends StatefulWidget {
  final GraduationProgram? program;

  const GraduationProgramFormScreen({super.key, this.program});

  bool get isEditing => program != null;

  @override
  State<GraduationProgramFormScreen> createState() =>
      _GraduationProgramFormScreenState();
}

class _GraduationProgramFormScreenState
    extends State<GraduationProgramFormScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();

  GraduationAudience audience = GraduationAudience.adult;
  bool isActive = true;
  bool isSaving = false;

  final List<_StageDraft> stages = [];

  @override
  void initState() {
    super.initState();

    _loadProgramValues();
  }

  void _loadProgramValues() {
    final program = widget.program;

    if (program == null) {
      return;
    }

    nameController.text = program.name;
    audience = program.audience;
    isActive = program.isActive;

    final orderedStages = List<GraduationStage>.of(program.stages)
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final stage in orderedStages) {
      stages.add(_StageDraft.fromStage(stage));
    }
  }

  @override
  void dispose() {
    nameController.dispose();

    for (final stage in stages) {
      stage.dispose();
    }

    super.dispose();
  }

  void addStage() {
    setState(() {
      stages.add(_StageDraft(order: stages.length + 1));
    });
  }

  void removeStage(int index) {
    setState(() {
      final removed = stages.removeAt(index);
      removed.dispose();

      for (var i = 0; i < stages.length; i++) {
        stages[i].order = i + 1;
      }
    });
  }

  void loadTemplate(GraduationTemplate template) {
    for (final stage in stages) {
      stage.dispose();
    }

    stages.clear();

    nameController.text = template.name;

    switch (template.audience) {
      case GraduationTemplateAudience.adult:
        audience = GraduationAudience.adult;
        break;
      case GraduationTemplateAudience.kids:
        audience = GraduationAudience.kids;
        break;
      case GraduationTemplateAudience.juvenile:
      case GraduationTemplateAudience.custom:
        audience = GraduationAudience.custom;
        break;
    }

    for (final templateStage in template.orderedStages) {
      stages.add(_StageDraft.fromTemplateStage(templateStage));
    }

    setState(() {});
  }

  Future<void> save() async {
    if (isSaving) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (stages.isEmpty) {
      _showError('Adicione pelo menos um estágio ao programa.');
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      _showError('Sua sessão não está disponível.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final graduationStages = <GraduationStage>[];

      for (var i = 0; i < stages.length; i++) {
        final draft = stages[i];

        final id = draft.idController.text.trim().isEmpty
            ? 'stage_${i + 1}'
            : draft.idController.text.trim();

        final nextStageId = i < stages.length - 1
            ? (stages[i + 1].idController.text.trim().isEmpty
                  ? 'stage_${i + 2}'
                  : stages[i + 1].idController.text.trim())
            : null;

        graduationStages.add(
          GraduationStage(
            id: id,
            name: draft.nameController.text.trim(),
            beltName: draft.beltController.text.trim(),
            degreeName: _optional(draft.degreeController.text),
            stripeColor: _optional(draft.stripeColorController.text),
            order: i + 1,
            criterion: draft.criterion,
            requiredAttendances:
                draft.criterion == ProgressionCriterion.attendance ||
                    draft.criterion == ProgressionCriterion.attendanceAndTime
                ? int.tryParse(draft.attendancesController.text.trim())
                : null,
            minimumDurationMonths:
                draft.criterion == ProgressionCriterion.time ||
                    draft.criterion == ProgressionCriterion.attendanceAndTime
                ? int.tryParse(draft.monthsController.text.trim())
                : null,
            nextStageId: nextStageId,
          ),
        );
      }

      final repository = context.read<GraduationProgramRepository>();

      if (widget.isEditing) {
        await repository.updateProgram(
          academyId: currentUser.academyId,
          programId: widget.program!.id,
          name: nameController.text.trim(),
          audience: audience,
          stages: graduationStages,
          isActive: isActive,
          updatedBy: currentUser.id,
        );
      } else {
        await repository.createProgram(
          academyId: currentUser.academyId,
          name: nameController.text.trim(),
          audience: audience,
          stages: graduationStages,
          isActive: isActive,
          createdBy: currentUser.id,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Programa de graduação criado com sucesso.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        widget.isEditing
            ? 'Não foi possível atualizar o programa: $error'
            : 'Não foi possível criar o programa: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.gracieRed),
      );
  }

  String? _optional(String value) {
    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar programa' : 'Novo programa'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do programa',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Informe o nome do programa.';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<GraduationAudience>(
              initialValue: audience,
              decoration: const InputDecoration(
                labelText: 'Público',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: GraduationAudience.adult,
                  child: Text('Adulto'),
                ),
                DropdownMenuItem(
                  value: GraduationAudience.kids,
                  child: Text('Kids'),
                ),
                DropdownMenuItem(
                  value: GraduationAudience.custom,
                  child: Text('Personalizado'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    audience = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isActive,
              title: const Text('Programa ativo'),
              onChanged: (value) {
                setState(() {
                  isActive = value;
                });
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'Modelo oficial',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Selecione um modelo pronto para preencher automaticamente a estrutura de graduação.',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<GraduationTemplate>(
              decoration: const InputDecoration(
                labelText: 'Modelo',
                border: OutlineInputBorder(),
              ),
              items: GraduationTemplateCatalog.activeTemplates
                  .map(
                    (template) => DropdownMenuItem<GraduationTemplate>(
                      value: template,
                      child: Text(
                        '${template.modality.label} • '
                        '${template.organizationName} • '
                        '${template.name} • '
                        '${template.version}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (template) {
                if (template != null) {
                  loadTemplate(template);
                }
              },
            ),

            const SizedBox(height: 28),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estágios',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: addStage,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stages.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Adicione o primeiro estágio do programa.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...List.generate(
                stages.length,
                (index) => _StageCard(
                  index: index,
                  stage: stages[index],
                  onRemove: () => removeStage(index),
                  onChanged: () => setState(() {}),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          color: AppColors.white,
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : save,
              icon: const Icon(Icons.save),
              label: Text(isSaving ? 'Salvando...' : 'Salvar programa'),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  final int index;
  final _StageDraft stage;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _StageCard({
    required this.index,
    required this.stage,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Estágio ${index + 1}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remover estágio',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: stage.nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do estágio',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Informe o nome.';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: stage.beltController,
              decoration: const InputDecoration(
                labelText: 'Faixa',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Informe a faixa.';
                }

                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: stage.degreeController,
              decoration: const InputDecoration(
                labelText: 'Grau (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: stage.stripeColorController,
              decoration: const InputDecoration(
                labelText: 'Cor do grau (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProgressionCriterion>(
              initialValue: stage.criterion,
              decoration: const InputDecoration(
                labelText: 'Critério',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ProgressionCriterion.manual,
                  child: Text('Manual'),
                ),
                DropdownMenuItem(
                  value: ProgressionCriterion.attendance,
                  child: Text('Presença'),
                ),
                DropdownMenuItem(
                  value: ProgressionCriterion.time,
                  child: Text('Tempo'),
                ),
                DropdownMenuItem(
                  value: ProgressionCriterion.attendanceAndTime,
                  child: Text('Presença + tempo'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  stage.criterion = value;
                  onChanged();
                }
              },
            ),
            if (stage.criterion == ProgressionCriterion.attendance ||
                stage.criterion == ProgressionCriterion.attendanceAndTime) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: stage.attendancesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Presenças necessárias',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (stage.criterion == ProgressionCriterion.time ||
                stage.criterion == ProgressionCriterion.attendanceAndTime) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: stage.monthsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tempo mínimo em meses',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: stage.idController,
              decoration: const InputDecoration(
                labelText: 'ID técnico (opcional)',
                helperText: 'Se vazio, o Tatame+ gera automaticamente.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageDraft {
  final TextEditingController idController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController beltController = TextEditingController();
  final TextEditingController degreeController = TextEditingController();
  final TextEditingController stripeColorController = TextEditingController();
  final TextEditingController attendancesController = TextEditingController();
  final TextEditingController monthsController = TextEditingController();

  int order;
  ProgressionCriterion criterion;

  _StageDraft({required this.order}) : criterion = ProgressionCriterion.manual;

  _StageDraft.fromTemplateStage(GraduationTemplateStage stage)
    : order = stage.order,
      criterion = stage.criterion {
    idController.text = stage.id;
    nameController.text = stage.name;
    beltController.text = stage.beltName;
    degreeController.text = stage.degreeName ?? '';
    stripeColorController.text = stage.stripeColor ?? '';
    attendancesController.text = stage.requiredAttendances?.toString() ?? '';
    monthsController.text = stage.minimumDurationMonths?.toString() ?? '';
  }

  _StageDraft.fromStage(GraduationStage stage)
    : order = stage.order,
      criterion = stage.criterion {
    idController.text = stage.id;
    nameController.text = stage.name;
    beltController.text = stage.beltName;
    degreeController.text = stage.degreeName ?? '';
    stripeColorController.text = stage.stripeColor ?? '';
    attendancesController.text = stage.requiredAttendances?.toString() ?? '';
    monthsController.text = stage.minimumDurationMonths?.toString() ?? '';
  }

  void dispose() {
    idController.dispose();
    nameController.dispose();
    beltController.dispose();
    degreeController.dispose();
    stripeColorController.dispose();
    attendancesController.dispose();
    monthsController.dispose();
  }
}
