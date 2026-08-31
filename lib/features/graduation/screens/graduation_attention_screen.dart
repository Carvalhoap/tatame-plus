import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../attendance/repository/attendance_repository.dart';
import '../../student/models/student.dart';
import '../../student/screens/student_dashboard_screen.dart';
import '../../student/repository/student_repository.dart';
import '../models/graduation_stage.dart';
import '../models/progression_criterion.dart';
import '../models/student_graduation_progress.dart';
import '../repository/graduation_program_repository.dart';
import '../repository/student_graduation_progress_repository.dart';

class GraduationAttentionScreen extends StatefulWidget {
  const GraduationAttentionScreen({super.key});

  @override
  State<GraduationAttentionScreen> createState() =>
      _GraduationAttentionScreenState();
}

class _GraduationAttentionScreenState extends State<GraduationAttentionScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<_GraduationAttentionItem> items = [];

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
    final activeRole = session.activeRole;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sess\u00e3o n\u00e3o encontrada.';
      });
      return;
    }

    if (!_canAccess(activeRole)) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Voc\u00ea n\u00e3o possui permiss\u00e3o para acessar esta \u00e1rea.';
      });
      return;
    }

    try {
      final studentRepository = context.read<StudentRepository>();

      final progressRepository = context
          .read<StudentGraduationProgressRepository>();

      final attendanceRepository = context.read<AttendanceRepository>();

      final programRepository = context.read<GraduationProgramRepository>();

      final students = await studentRepository.getStudentsByAcademy(
        currentUser.academyId,
      );

      final programs = await programRepository.getActivePrograms(
        academyId: currentUser.academyId,
      );

      final loadedItems = <_GraduationAttentionItem>[];
      final now = DateTime.now();
      for (final student in students) {
        if (!student.isActive) {
          continue;
        }

        final progress = await progressRepository.getByStudent(
          academyId: currentUser.academyId,
          studentId: student.id,
        );

        if (progress == null) {
          continue;
        }

        final program = programs
            .where((item) => item.id == progress.graduationProgramId)
            .firstOrNull;

        if (program == null) {
          continue;
        }

        final stage = program.stages
            .where((item) => item.id == progress.currentStageId)
            .firstOrNull;

        if (stage == null) {
          continue;
        }

        if (stage.criterion == ProgressionCriterion.manual) {
          continue;
        }

        final attendances = await attendanceRepository.getAttendancesByStudent(
          academyId: currentUser.academyId,
          studentId: student.id,
          start: progress.stageStartedAt,
          end: now.add(const Duration(days: 1)),
        );

        final validAttendances = attendances
            .where((item) => item.isValid)
            .length;

        final completedMonths = _completedMonths(progress.stageStartedAt, now);

        final attendanceReached =
            stage.requiredAttendances != null &&
            validAttendances >= stage.requiredAttendances!;

        final timeReached =
            stage.minimumDurationMonths != null &&
            completedMonths >= stage.minimumDurationMonths!;

        final shouldAlert = switch (stage.criterion) {
          ProgressionCriterion.attendance => attendanceReached,
          ProgressionCriterion.time => timeReached,
          ProgressionCriterion.attendanceAndTime =>
            attendanceReached && timeReached,
          ProgressionCriterion.manual => false,
        };
        if (!shouldAlert) {
          continue;
        }

        loadedItems.add(
          _GraduationAttentionItem(
            student: student,
            progress: progress,
            stage: stage,
            validAttendances: validAttendances,
            completedMonths: completedMonths,
          ),
        );
      }

      loadedItems.sort(
        (a, b) => b.validAttendances.compareTo(a.validAttendances),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        items = loadedItems;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage =
            'N\u00e3o foi poss\u00edvel carregar o acompanhamento: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Acompanhamento de gradua\u00e7\u00e3o'),
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
          : items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum aluno atingiu um marco de acompanhamento no momento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey, fontSize: 16),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];

                return _AttentionCard(item: item);
              },
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

class _GraduationAttentionItem {
  final Student student;
  final StudentGraduationProgress progress;
  final GraduationStage stage;
  final int validAttendances;
  final int completedMonths;

  const _GraduationAttentionItem({
    required this.student,
    required this.progress,
    required this.stage,
    required this.validAttendances,
    required this.completedMonths,
  });
}

class _AttentionCard extends StatelessWidget {
  final _GraduationAttentionItem item;

  const _AttentionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final stage = item.stage;

    final String milestoneText;

    switch (stage.criterion) {
      case ProgressionCriterion.attendance:
        milestoneText = '${stage.requiredAttendances ?? 0} treinos';

      case ProgressionCriterion.time:
        milestoneText = '${stage.minimumDurationMonths ?? 0} meses';

      case ProgressionCriterion.attendanceAndTime:
        milestoneText =
            '${stage.requiredAttendances ?? 0} treinos + '
            '${stage.minimumDurationMonths ?? 0} meses';

      case ProgressionCriterion.manual:
        milestoneText = 'Avaliação manual';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDashboardScreen(student: item.student),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.18),
            ),
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
              Text(
                item.student.fullName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stage.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: AppColors.brandPrimary,
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Marco de acompanhamento atingido',
                        style: TextStyle(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${item.validAttendances} treinos na gradua\u00e7\u00e3o atual',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.completedMonths} meses nesta gradua\u00e7\u00e3o',
                style: const TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 12),
              Text(
                'Marco configurado: $milestoneText',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Este aviso indica apenas que o aluno merece aten\u00e7\u00e3o do professor. '
                'A gradua\u00e7\u00e3o n\u00e3o \u00e9 autom\u00e1tica.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
