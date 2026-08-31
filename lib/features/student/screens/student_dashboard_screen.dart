import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../attendance/repository/attendance_repository.dart';
import '../../auth/services/session_service.dart';
import '../../graduation/models/graduation_stage.dart';
import '../../graduation/models/progression_criterion.dart';
import '../../graduation/models/student_graduation_history.dart';
import '../../graduation/models/student_graduation_progress.dart';
import '../../graduation/models/student_graduation_evaluation.dart';
import '../../graduation/repository/graduation_program_repository.dart';
import '../../graduation/repository/student_graduation_history_repository.dart';
import '../../graduation/repository/student_graduation_progress_repository.dart';
import '../../graduation/repository/student_graduation_evaluation_repository.dart';
import '../models/student.dart';

class StudentDashboardScreen extends StatefulWidget {
  final Student student;

  const StudentDashboardScreen({super.key, required this.student});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool isLoading = true;
  String? errorMessage;

  StudentGraduationProgress? progress;
  GraduationStage? currentStage;
  List<StudentGraduationHistory> history = [];
  StudentGraduationEvaluation? latestEvaluation;

  int validAttendances = 0;
  int completedMonths = 0;

  bool _canAccess(UserRole? role) {
    return role == UserRole.admin ||
        role == UserRole.partner ||
        role == UserRole.teacher;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadData());
  }

  Future<void> loadData() async {
    final session = context.read<SessionService>();
    final currentUser = session.currentUser;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sess\u00e3o n\u00e3o encontrada.';
      });
      return;
    }

    if (!_canAccess(session.activeRole)) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Voc\u00ea n\u00e3o possui permiss\u00e3o para acessar esta \u00e1rea.';
      });
      return;
    }

    try {
      final progressRepository = context
          .read<StudentGraduationProgressRepository>();

      final programRepository = context.read<GraduationProgramRepository>();

      final attendanceRepository = context.read<AttendanceRepository>();

      final historyRepository = context
          .read<StudentGraduationHistoryRepository>();

      final evaluationRepository = context
          .read<StudentGraduationEvaluationRepository>();

      final loadedProgress = await progressRepository.getByStudent(
        academyId: currentUser.academyId,
        studentId: widget.student.id,
      );

      GraduationStage? loadedStage;
      StudentGraduationEvaluation? loadedEvaluation;
      var loadedAttendances = 0;
      var loadedMonths = 0;

      if (loadedProgress != null) {
        final program = await programRepository.getProgramById(
          academyId: currentUser.academyId,
          programId: loadedProgress.graduationProgramId,
        );

        if (program != null) {
          loadedStage = program.stages
              .where((stage) => stage.id == loadedProgress.currentStageId)
              .firstOrNull;
        }

        loadedEvaluation = await evaluationRepository
            .getLatestByStudentAndStage(
              academyId: currentUser.academyId,
              studentId: widget.student.id,
              graduationProgramId: loadedProgress.graduationProgramId,
              stageId: loadedProgress.currentStageId,
            );

        final attendances = await attendanceRepository.getAttendancesByStudent(
          academyId: currentUser.academyId,
          studentId: widget.student.id,
          start: loadedProgress.stageStartedAt,
          end: DateTime.now().add(const Duration(days: 1)),
        );

        loadedAttendances = attendances.where((item) => item.isValid).length;

        loadedMonths = _completedMonths(
          loadedProgress.stageStartedAt,
          DateTime.now(),
        );
      }

      final loadedHistory = await historyRepository.getByStudent(
        academyId: currentUser.academyId,
        studentId: widget.student.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        progress = loadedProgress;
        currentStage = loadedStage;
        history = loadedHistory;
        latestEvaluation = loadedEvaluation;
        validAttendances = loadedAttendances;
        completedMonths = loadedMonths;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage =
            'N\u00e3o foi poss\u00edvel carregar o acompanhamento do aluno: $error';
      });
    }
  }

  String _milestoneText(GraduationStage stage) {
    switch (stage.criterion) {
      case ProgressionCriterion.attendance:
        return '${stage.requiredAttendances ?? 0} treinos';

      case ProgressionCriterion.time:
        return '${stage.minimumDurationMonths ?? 0} meses';

      case ProgressionCriterion.attendanceAndTime:
        return '${stage.requiredAttendances ?? 0} treinos + '
            '${stage.minimumDurationMonths ?? 0} meses';

      case ProgressionCriterion.manual:
        return 'Acompanhamento manual';
    }
  }

  Future<void> _evaluateStudent(GraduationEvaluationStatus status) async {
    final currentUser = context.read<SessionService>().currentUser;
    final currentProgress = progress;
    final stage = currentStage;

    if (currentUser == null || currentProgress == null || stage == null) {
      return;
    }

    final evaluationRepository = context
        .read<StudentGraduationEvaluationRepository>();

    final observationController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isApproved = status == GraduationEvaluationStatus.approved;

        return AlertDialog(
          title: Text(
            isApproved
                ? 'Marcar como apto para graduação'
                : 'Continuar acompanhando',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isApproved
                    ? 'Confirma que ${widget.student.fullName} está apto para graduação?'
                    : 'Registrar que ${widget.student.fullName} continuará em acompanhamento?',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: observationController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  hintText: 'Ex.: técnica, frequência, comportamento...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      observationController.dispose();
      return;
    }

    final observation = observationController.text.trim();
    observationController.dispose();

    try {
      await evaluationRepository.addEvaluation(
        evaluation: StudentGraduationEvaluation(
          id: '',
          academyId: currentUser.academyId,
          studentId: widget.student.id,
          graduationProgramId: currentProgress.graduationProgramId,
          stageId: currentProgress.currentStageId,
          stageName: stage.name,
          status: status,
          observation: observation.isEmpty ? null : observation,
          evaluatedBy: currentUser.id,
          evaluatedAt: DateTime.now(),
          validAttendances: validAttendances,
          completedMonths: completedMonths,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == GraduationEvaluationStatus.approved
                ? 'Aluno marcado como apto para graduação.'
                : 'Acompanhamento registrado.',
          ),
        ),
      );

      await loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível registrar a avaliação: $error'),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Acompanhamento do aluno'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.gracieRed,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.student.fullName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.student.isActive ? 'Aluno ativo' : 'Aluno inativo',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 24),

                  if (progress != null && currentStage != null)
                    _CurrentGraduationCard(
                      stage: currentStage!,
                      progress: progress!,
                      attendances: validAttendances,
                      months: completedMonths,
                      milestoneText: _milestoneText(currentStage!),
                      formatDate: _formatDate,
                    )
                  else
                    const _InfoCard(
                      title: 'Gradua\u00e7\u00e3o atual',
                      text: 'Nenhuma gradua\u00e7\u00e3o atual foi encontrada.',
                    ),

                  const SizedBox(height: 18),

                  _InfoCard(
                    title: 'Hist\u00f3rico de gradua\u00e7\u00f5es',
                    text: history.isEmpty
                        ? 'Nenhuma gradua\u00e7\u00e3o anterior registrada.'
                        : '${history.length} gradua\u00e7\u00e3o(\u00f5es) conclu\u00edda(s)',
                  ),

                  if (history.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...history
                        .take(3)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HistoryPreviewCard(
                              history: item,
                              formatDate: _formatDate,
                            ),
                          ),
                        ),
                  ],

                  const SizedBox(height: 18),
                  _TeacherEvaluationCard(
                    evaluation: latestEvaluation,
                    formatDate: _formatDate,
                    onMonitoring: () =>
                        _evaluateStudent(GraduationEvaluationStatus.monitoring),
                    onApproved: () =>
                        _evaluateStudent(GraduationEvaluationStatus.approved),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CurrentGraduationCard extends StatelessWidget {
  final GraduationStage stage;
  final StudentGraduationProgress progress;
  final int attendances;
  final int months;
  final String milestoneText;
  final String Function(DateTime) formatDate;

  const _CurrentGraduationCard({
    required this.stage,
    required this.progress,
    required this.attendances,
    required this.months,
    required this.milestoneText,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gradua\u00e7\u00e3o atual',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Desde ${formatDate(progress.stageStartedAt)}',
            style: const TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 12),
          Text(
            '$attendances treinos na gradua\u00e7\u00e3o atual',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$months meses completos nesta gradua\u00e7\u00e3o',
            style: const TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 12),
          Text(
            'Marco configurado: $milestoneText',
            style: const TextStyle(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryPreviewCard extends StatelessWidget {
  final StudentGraduationHistory history;
  final String Function(DateTime) formatDate;

  const _HistoryPreviewCard({required this.history, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            history.stageName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatDate(history.startedAt)} \u2192 '
            '${formatDate(history.endedAt)}',
            style: const TextStyle(color: AppColors.grey),
          ),
          const SizedBox(height: 4),
          Text('${history.validAttendances} treinos'),
          if (history.observation != null &&
              history.observation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              history.observation!,
              style: const TextStyle(
                color: AppColors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeacherEvaluationCard extends StatelessWidget {
  final StudentGraduationEvaluation? evaluation;
  final String Function(DateTime) formatDate;
  final VoidCallback onMonitoring;
  final VoidCallback onApproved;

  const _TeacherEvaluationCard({
    required this.evaluation,
    required this.formatDate,
    required this.onMonitoring,
    required this.onApproved,
  });

  @override
  Widget build(BuildContext context) {
    final currentEvaluation = evaluation;

    final String statusTitle;
    final IconData statusIcon;
    final Color statusColor;

    if (currentEvaluation == null) {
      statusTitle = 'Aguardando avaliação';
      statusIcon = Icons.schedule;
      statusColor = AppColors.grey;
    } else {
      switch (currentEvaluation.status) {
        case GraduationEvaluationStatus.monitoring:
          statusTitle = 'Continuar acompanhando';
          statusIcon = Icons.visibility_outlined;
          statusColor = AppColors.brandPrimary;

        case GraduationEvaluationStatus.approved:
          statusTitle = 'Apto para graduação';
          statusIcon = Icons.check_circle_outline;
          statusColor = AppColors.success;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avaliação do professor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (currentEvaluation != null) ...[
            const SizedBox(height: 10),
            Text(
              'Avaliado em ${formatDate(currentEvaluation.evaluatedAt)}',
              style: const TextStyle(color: AppColors.grey),
            ),
            if (currentEvaluation.observation != null &&
                currentEvaluation.observation!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                currentEvaluation.observation!,
                style: const TextStyle(height: 1.35),
              ),
            ],
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onMonitoring,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Continuar acompanhando'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onApproved,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Marcar como apto para gradua\u00e7\u00e3o'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'O marco de acompanhamento serve apenas como referência. '
            'A decisão de graduar continua sendo do professor.',
            style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;

  const _InfoCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }
}

int _completedMonths(DateTime start, DateTime end) {
  var months = (end.year - start.year) * 12 + end.month - start.month;

  if (end.day < start.day) {
    months--;
  }

  return months < 0 ? 0 : months;
}
