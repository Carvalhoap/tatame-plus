import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../classroom/models/classroom.dart';
import '../../classroom/repository/classroom_repository.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/attendance.dart';
import '../models/check_in_session.dart';
import '../repository/attendance_repository.dart';
import '../repository/check_in_session_repository.dart';

class StudentAttendanceSummaryScreen extends StatefulWidget {
  const StudentAttendanceSummaryScreen({super.key});

  @override
  State<StudentAttendanceSummaryScreen> createState() =>
      _StudentAttendanceSummaryScreenState();
}

class _StudentAttendanceSummaryScreenState
    extends State<StudentAttendanceSummaryScreen> {
  late DateTime startDate;
  late DateTime endDate;

  List<Attendance> attendances = const [];
  List<CheckInSession> sessions = const [];
  List<Student> students = const [];
  List<Classroom> classrooms = const [];

  String? selectedClassroomId;
  bool includeInactiveStudents = false;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    startDate = DateTime(now.year, now.month);
    endDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadSummary();
    });
  }

  Future<void> loadSummary() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUser = context.read<SessionService>().currentUser;

      if (currentUser == null) {
        throw StateError('Sua sessão não está disponível.');
      }

      final exclusiveEnd = endDate.add(const Duration(days: 1));

      final results = await Future.wait<Object>([
        context.read<AttendanceRepository>().getAttendancesByPeriod(
          academyId: currentUser.academyId,
          start: startDate,
          end: exclusiveEnd,
        ),
        context.read<CheckInSessionRepository>().getSessionsByPeriod(
          academyId: currentUser.academyId,
          start: startDate,
          end: exclusiveEnd,
        ),
        context.read<StudentRepository>().getStudentsByAcademy(
          currentUser.academyId,
        ),
        context.read<ClassroomRepository>().getClassrooms(
          academyId: currentUser.academyId,
        ),
      ]);

      final loadedAttendances = results[0] as List<Attendance>;
      final loadedSessions = results[1] as List<CheckInSession>;

      final loadedStudents = List<Student>.from(results[2] as List<Student>)
        ..sort(
          (first, second) => first.fullName.toLowerCase().compareTo(
            second.fullName.toLowerCase(),
          ),
        );

      final loadedClassrooms =
          List<Classroom>.from(results[3] as List<Classroom>)..sort(
            (first, second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        attendances = loadedAttendances;
        sessions = loadedSessions;
        students = loadedStudents;
        classrooms = loadedClassrooms;

        if (selectedClassroomId != null &&
            !loadedClassrooms.any(
              (classroom) => classroom.id == selectedClassroomId,
            )) {
          selectedClassroomId = null;
        }

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('Exception: ', '');
      });
    }
  }

  List<_StudentFrequency> get studentFrequencies {
    final result = <_StudentFrequency>[];

    for (final student in students) {
      if (!includeInactiveStudents && !student.isActive) {
        continue;
      }

      if (selectedClassroomId != null &&
          !student.classroomIds.contains(selectedClassroomId)) {
        continue;
      }

      final completedClassKeys = <String>{};

      for (final session in sessions) {
        if (session.isActive) {
          continue;
        }

        if (selectedClassroomId != null &&
            session.classroomId != selectedClassroomId) {
          continue;
        }

        if (!student.classroomIds.contains(session.classroomId)) {
          continue;
        }

        final joinDate = student.academyJoinDate;

        if (joinDate != null) {
          final normalizedJoinDate = DateTime(
            joinDate.year,
            joinDate.month,
            joinDate.day,
          );

          if (session.createdAt.isBefore(normalizedJoinDate)) {
            continue;
          }
        }

        completedClassKeys.add(
          classDayKey(session.classroomId, session.createdAt),
        );
      }

      final attendedClassKeys = attendances
          .where(
            (attendance) =>
                attendance.isValid &&
                attendance.studentId == student.id &&
                (selectedClassroomId == null ||
                    attendance.classroomId == selectedClassroomId),
          )
          .map(
            (attendance) =>
                classDayKey(attendance.classroomId, attendance.dateTime),
          )
          .where(completedClassKeys.contains)
          .toSet();

      result.add(
        _StudentFrequency(
          student: student,
          classes: completedClassKeys.length,
          presences: attendedClassKeys.length,
        ),
      );
    }

    result.sort((first, second) {
      final firstHasClasses = first.classes > 0;
      final secondHasClasses = second.classes > 0;

      if (firstHasClasses != secondHasClasses) {
        return firstHasClasses ? -1 : 1;
      }

      if (firstHasClasses && secondHasClasses) {
        final frequencyComparison = first.frequency.compareTo(second.frequency);

        if (frequencyComparison != 0) {
          return frequencyComparison;
        }
      }

      return first.student.fullName.toLowerCase().compareTo(
        second.student.fullName.toLowerCase(),
      );
    });

    return result;
  }

  Future<void> selectPeriod() async {
    final selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      helpText: 'Selecione o período',
      confirmText: 'Aplicar',
      cancelText: 'Cancelar',
      saveText: 'Aplicar',
    );

    if (selectedRange == null) {
      return;
    }

    setState(() {
      startDate = DateTime(
        selectedRange.start.year,
        selectedRange.start.month,
        selectedRange.start.day,
      );

      endDate = DateTime(
        selectedRange.end.year,
        selectedRange.end.month,
        selectedRange.end.day,
      );
    });

    await loadSummary();
  }

  String classDayKey(String classroomId, DateTime date) {
    return '$classroomId|'
        '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  String formatDate(DateTime date) {
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final frequencies = studentFrequencies;

    final frequenciesWithClasses = frequencies
        .where((item) => item.classes > 0)
        .toList();

    final averageFrequency = frequenciesWithClasses.isEmpty
        ? null
        : frequenciesWithClasses
                  .map((item) => item.frequency)
                  .reduce((first, second) => first + second) /
              frequenciesWithClasses.length;

    final lowFrequencyCount = frequenciesWithClasses
        .where((item) => item.frequency < 75)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Resumo por aluno'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _SummaryError(message: errorMessage!, onRetry: loadSummary)
          : RefreshIndicator(
              onRefresh: loadSummary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    elevation: 0,
                    color: AppColors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Filtros',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: selectPeriod,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              '${formatDate(startDate)} até '
                              '${formatDate(endDate)}',
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String?>(
                            key: ValueKey(
                              'summary-classroom-$selectedClassroomId',
                            ),
                            initialValue: selectedClassroomId,
                            decoration: const InputDecoration(
                              labelText: 'Turma',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todas as turmas'),
                              ),
                              ...classrooms.map(
                                (classroom) => DropdownMenuItem<String?>(
                                  value: classroom.id,
                                  child: Text(
                                    classroom.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedClassroomId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: includeInactiveStudents,
                            title: const Text('Incluir alunos inativos'),
                            onChanged: (value) {
                              setState(() {
                                includeInactiveStudents = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryMetric(
                        label: 'Alunos listados',
                        value: frequencies.length.toString(),
                        icon: Icons.groups_outlined,
                        color: AppColors.brandPrimary,
                      ),
                      _SummaryMetric(
                        label: 'Frequência média',
                        value: averageFrequency == null
                            ? '--'
                            : '${averageFrequency.toStringAsFixed(1)}%',
                        icon: Icons.percent,
                        color: Colors.teal,
                      ),
                      _SummaryMetric(
                        label: 'Abaixo de 75%',
                        value: lowFrequencyCount.toString(),
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.gracieRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Alunos com frequência abaixo de 75% aparecem destacados.',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Frequência dos alunos',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (frequencies.isEmpty)
                    const _EmptySummary()
                  else
                    ...frequencies.map(
                      (frequency) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StudentFrequencyCard(frequency: frequency),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StudentFrequency {
  final Student student;
  final int classes;
  final int presences;

  const _StudentFrequency({
    required this.student,
    required this.classes,
    required this.presences,
  });

  int get absences => classes - presences;

  double get frequency {
    if (classes == 0) {
      return 0;
    }

    return presences * 100 / classes;
  }
}

class _StudentFrequencyCard extends StatelessWidget {
  final _StudentFrequency frequency;

  const _StudentFrequencyCard({required this.frequency});

  Color get statusColor {
    if (frequency.classes == 0) {
      return AppColors.grey;
    }

    if (frequency.frequency < 75) {
      return AppColors.gracieRed;
    }

    if (frequency.frequency < 85) {
      return Colors.orange;
    }

    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final hasClasses = frequency.classes > 0;

    return Card(
      elevation: 0,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor,
                  foregroundColor: AppColors.white,
                  child: Text(
                    initials(frequency.student.fullName),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    frequency.student.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
                Text(
                  hasClasses
                      ? '${frequency.frequency.toStringAsFixed(1)}%'
                      : '--',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: hasClasses ? frequency.frequency / 100 : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: statusColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 12),
            Text(
              hasClasses
                  ? '${frequency.classes} aulas • '
                        '${frequency.presences} presenças • '
                        '${frequency.absences} faltas'
                  : 'Nenhuma aula contabilizada no período',
              style: const TextStyle(
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: Card(
        elevation: 0,
        color: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySummary extends StatelessWidget {
  const _EmptySummary();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Icon(Icons.groups_outlined, size: 44, color: AppColors.grey),
            SizedBox(height: 12),
            Text(
              'Nenhum aluno encontrado para os filtros selecionados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SummaryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar o resumo.\n$message',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
