import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../classroom/models/classroom.dart';
import '../../classroom/repository/classroom_repository.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/attendance.dart';
import '../repository/attendance_repository.dart';

class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() =>
      _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  late DateTime startDate;
  late DateTime endDate;

  List<Attendance> attendances = const [];
  List<Student> students = const [];
  List<Classroom> classrooms = const [];

  String? selectedStudentId;
  String? selectedClassroomId;

  bool showInvalid = false;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    startDate = DateTime(now.year, now.month);
    endDate = DateTime(now.year, now.month, now.day);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadReport();
    });
  }

  Future<void> loadReport() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final currentUser = context.read<SessionService>().currentUser;

      if (currentUser == null) {
        throw StateError('Sua sessão não está disponível.');
      }

      final results = await Future.wait<Object>([
        context.read<AttendanceRepository>().getAttendancesByPeriod(
          academyId: currentUser.academyId,
          start: startDate,
          end: endDate.add(const Duration(days: 1)),
          includeInvalid: true,
        ),
        context.read<StudentRepository>().getStudentsByAcademy(
          currentUser.academyId,
        ),
        context.read<ClassroomRepository>().getClassrooms(
          academyId: currentUser.academyId,
        ),
      ]);

      final loadedAttendances = results[0] as List<Attendance>;
      final loadedStudents = results[1] as List<Student>;
      final loadedClassrooms = results[2] as List<Classroom>;

      loadedStudents.sort(
        (first, second) => first.fullName.toLowerCase().compareTo(
          second.fullName.toLowerCase(),
        ),
      );

      loadedClassrooms.sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        attendances = loadedAttendances;
        students = loadedStudents;
        classrooms = loadedClassrooms;

        if (selectedStudentId != null &&
            !loadedStudents.any((student) => student.id == selectedStudentId)) {
          selectedStudentId = null;
        }

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

  List<Attendance> get filteredAttendances {
    return attendances.where((attendance) {
      if (!showInvalid && !attendance.isValid) {
        return false;
      }

      if (selectedStudentId != null &&
          attendance.studentId != selectedStudentId) {
        return false;
      }

      if (selectedClassroomId != null &&
          attendance.classroomId != selectedClassroomId) {
        return false;
      }

      return true;
    }).toList();
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

    await loadReport();
  }

  String studentName(String studentId) {
    for (final student in students) {
      if (student.id == studentId) {
        return student.fullName;
      }
    }

    return 'Aluno não encontrado';
  }

  String classroomName(String classroomId) {
    for (final classroom in classrooms) {
      if (classroom.id == classroomId) {
        return classroom.name;
      }
    }

    return 'Turma não encontrada';
  }

  String sourceName(AttendanceSource source) {
    switch (source) {
      case AttendanceSource.qrCode:
        return 'QR Code';
      case AttendanceSource.manual:
        return 'Manual';
      case AttendanceSource.import:
        return 'Importada';
    }
  }

  String formatDate(DateTime date) {
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
  }

  String formatDateTime(DateTime date) {
    return '${formatDate(date)} às '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredAttendances;

    final validAttendances = filtered
        .where((attendance) => attendance.isValid)
        .toList();

    final invalidCount = filtered
        .where((attendance) => !attendance.isValid)
        .length;

    final qrCodeCount = validAttendances
        .where((attendance) => attendance.source == AttendanceSource.qrCode)
        .length;

    final manualCount = validAttendances
        .where((attendance) => attendance.source == AttendanceSource.manual)
        .length;

    final uniqueStudents = validAttendances
        .map((attendance) => attendance.studentId)
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Relatório de presenças'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _ReportError(message: errorMessage!, onRetry: loadReport)
          : RefreshIndicator(
              onRefresh: loadReport,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _ReportFilters(
                    startDate: startDate,
                    endDate: endDate,
                    students: students,
                    classrooms: classrooms,
                    selectedStudentId: selectedStudentId,
                    selectedClassroomId: selectedClassroomId,
                    showInvalid: showInvalid,
                    formatDate: formatDate,
                    onSelectPeriod: selectPeriod,
                    onStudentChanged: (value) {
                      setState(() {
                        selectedStudentId = value;
                      });
                    },
                    onClassroomChanged: (value) {
                      setState(() {
                        selectedClassroomId = value;
                      });
                    },
                    onShowInvalidChanged: (value) {
                      setState(() {
                        showInvalid = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(
                        label: 'Presenças válidas',
                        value: validAttendances.length.toString(),
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      _MetricCard(
                        label: 'Alunos presentes',
                        value: uniqueStudents.toString(),
                        icon: Icons.groups_outlined,
                        color: AppColors.brandPrimary,
                      ),
                      _MetricCard(
                        label: 'Por QR Code',
                        value: qrCodeCount.toString(),
                        icon: Icons.qr_code_2,
                        color: Colors.blue,
                      ),
                      _MetricCard(
                        label: 'Manuais',
                        value: manualCount.toString(),
                        icon: Icons.touch_app_outlined,
                        color: Colors.orange,
                      ),
                      if (showInvalid)
                        _MetricCard(
                          label: 'Invalidadas',
                          value: invalidCount.toString(),
                          icon: Icons.cancel_outlined,
                          color: AppColors.gracieRed,
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Registros',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${filtered.length} encontrados',
                        style: const TextStyle(
                          color: AppColors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const _EmptyReport()
                  else
                    ...filtered.map(
                      (attendance) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AttendanceReportCard(
                          studentName: studentName(attendance.studentId),
                          classroomName: classroomName(attendance.classroomId),
                          dateTime: formatDateTime(attendance.dateTime),
                          source: sourceName(attendance.source),
                          isValid: attendance.isValid,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ReportFilters extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final List<Student> students;
  final List<Classroom> classrooms;
  final String? selectedStudentId;
  final String? selectedClassroomId;
  final bool showInvalid;
  final String Function(DateTime) formatDate;
  final VoidCallback onSelectPeriod;
  final ValueChanged<String?> onStudentChanged;
  final ValueChanged<String?> onClassroomChanged;
  final ValueChanged<bool> onShowInvalidChanged;

  const _ReportFilters({
    required this.startDate,
    required this.endDate,
    required this.students,
    required this.classrooms,
    required this.selectedStudentId,
    required this.selectedClassroomId,
    required this.showInvalid,
    required this.formatDate,
    required this.onSelectPeriod,
    required this.onStudentChanged,
    required this.onClassroomChanged,
    required this.onShowInvalidChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
              onPressed: onSelectPeriod,
              icon: const Icon(Icons.date_range),
              label: Text(
                '${formatDate(startDate)} até ${formatDate(endDate)}',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              key: ValueKey('student-$selectedStudentId'),
              initialValue: selectedStudentId,
              decoration: const InputDecoration(
                labelText: 'Aluno',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos os alunos'),
                ),
                ...students.map(
                  (student) => DropdownMenuItem<String?>(
                    value: student.id,
                    child: Text(
                      student.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onStudentChanged,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              key: ValueKey('classroom-$selectedClassroomId'),
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
              onChanged: onClassroomChanged,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: showInvalid,
              title: const Text('Mostrar presenças invalidadas'),
              onChanged: onShowInvalidChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
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

class _AttendanceReportCard extends StatelessWidget {
  final String studentName;
  final String classroomName;
  final String dateTime;
  final String source;
  final bool isValid;

  const _AttendanceReportCard({
    required this.studentName,
    required this.classroomName,
    required this.dateTime,
    required this.source,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isValid
              ? AppColors.brandPrimary
              : AppColors.gracieRed,
          foregroundColor: AppColors.white,
          child: Icon(isValid ? Icons.check : Icons.close),
        ),
        title: Text(
          studentName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('$classroomName\n$dateTime • $source'),
        ),
        isThreeLine: true,
        trailing: isValid
            ? null
            : const Text(
                'Invalidada',
                style: TextStyle(
                  color: AppColors.gracieRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Icon(Icons.event_busy_outlined, size: 44, color: AppColors.grey),
            SizedBox(height: 12),
            Text(
              'Nenhuma presença encontrada para os filtros selecionados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReportError({required this.message, required this.onRetry});

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
              'Não foi possível carregar o relatório.\n$message',
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
