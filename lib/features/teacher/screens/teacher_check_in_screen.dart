import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/models/attendance.dart';
import '../../attendance/repository/attendance_repository.dart';
import '../../attendance/repository/check_in_session_repository.dart';
import '../../student/models/student.dart';
import '../../auth/services/session_service.dart';
import '../../classroom/models/classroom.dart';
import '../../classroom/repository/classroom_repository.dart';
import '../../student/repository/student_repository.dart';
import '../controllers/teacher_check_in_controller.dart';

class TeacherCheckInScreen extends StatefulWidget {
  const TeacherCheckInScreen({super.key});

  @override
  State<TeacherCheckInScreen> createState() => _TeacherCheckInScreenState();
}

class _TeacherCheckInScreenState extends State<TeacherCheckInScreen> {
  List<Classroom> classrooms = [];
  String? selectedClassroomId;

  bool isLoadingClassrooms = true;
  String? errorMessage;

  Timer? refreshTimer;
  final Map<String, String> studentNames = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => initializeScreen());
  }

  Future<void> initializeScreen() async {
    await loadClassrooms();

    if (!mounted) {
      return;
    }

    final controller = context.read<TeacherCheckInController>();
    final session = controller.currentSession;

    if (session != null && session.isActive) {
      await refreshSessionData();

      if (!mounted) {
        return;
      }

      startAutoRefresh();
    }
  }

  Future<void> loadClassrooms() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        isLoadingClassrooms = false;
        errorMessage = 'Sess\u00E3o n\u00E3o encontrada.';
      });

      return;
    }

    final classroomRepository = context.read<ClassroomRepository>();

    try {
      final result = await classroomRepository.getClassrooms(
        academyId: currentUser.academyId,
        includeInactive: false,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        classrooms = result;
        selectedClassroomId = result.isEmpty ? null : result.first.id;
        isLoadingClassrooms = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingClassrooms = false;
        errorMessage = 'N\u00E3o foi poss\u00EDvel carregar as turmas: $error';
      });
    }
  }

  Future<void> generateSession() async {
    final currentUser = context.read<SessionService>().currentUser;
    final classroomId = selectedClassroomId;

    if (currentUser == null || classroomId == null) {
      return;
    }

    final controller = context.read<TeacherCheckInController>();
    final currentSession = controller.currentSession;

    if (currentSession != null && currentSession.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'J\u00E1 existe uma sess\u00E3o de check-in ativa. Encerre-a antes de gerar outra.',
          ),
        ),
      );
      return;
    }

    await controller.createSession(
      academyId: currentUser.academyId,
      classroomId: classroomId,
      teacherId: currentUser.id,
    );

    if (!mounted) {
      return;
    }

    startAutoRefresh();
  }

  Future<void> closeSession() async {
    await context.read<TeacherCheckInController>().closeCurrentSession();
  }

  void startAutoRefresh() {
    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => refreshSessionData(),
    );
  }

  Future<void> refreshSessionData() async {
    final controller = context.read<TeacherCheckInController>();

    final studentRepository = context.read<StudentRepository>();

    final session = controller.currentSession;

    if (session == null || !session.isActive) {
      refreshTimer?.cancel();
      return;
    }

    await controller.refreshCurrentSession();

    if (!mounted) {
      return;
    }

    final students = await studentRepository.getStudentsByAcademy(
      session.academyId,
    );

    if (!mounted) {
      return;
    }

    final names = <String, String>{};

    for (final student in students) {
      names[student.id] = student.fullName;
    }

    setState(() {
      studentNames
        ..clear()
        ..addAll(names);
    });
  }

  Future<void> addManualAttendance() async {
    final currentUser = context.read<SessionService>().currentUser;
    final controller = context.read<TeacherCheckInController>();
    final session = controller.currentSession;

    if (currentUser == null || session == null || !session.isActive) {
      return;
    }

    final studentRepository = context.read<StudentRepository>();
    final checkInRepository = context.read<CheckInSessionRepository>();

    try {
      final students = await studentRepository.getStudentsByAcademy(
        currentUser.academyId,
      );

      if (!mounted) {
        return;
      }

      final presentStudentIds = controller.attendances
          .where((attendance) => attendance.isValid)
          .map((attendance) => attendance.studentId)
          .toSet();

      final availableStudents =
          students
              .where(
                (student) =>
                    student.isActive &&
                    student.classroomIds.contains(session.classroomId) &&
                    !presentStudentIds.contains(student.id),
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );

      if (availableStudents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Todos os alunos ativos desta turma j\u00E1 est\u00E3o presentes.',
            ),
          ),
        );
        return;
      }

      final selectedStudent = await showModalBottomSheet<Student>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.75,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1,
                          color: AppColors.brandPrimary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Adicionar presença manual',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: availableStudents.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = availableStudents[index];

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(student.fullName),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () {
                            Navigator.pop(sheetContext, student);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (selectedStudent == null || !mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Confirmar presença'),
            content: Text(
              'Registrar manualmente a presença de '
              '${selectedStudent.fullName} nesta aula?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Registrar'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) {
        return;
      }

      final attendance = await checkInRepository.registerAttendance(
        academyId: currentUser.academyId,
        sessionId: session.id,
        studentId: selectedStudent.id,
        source: AttendanceSource.manual,
      );

      if (!mounted) {
        return;
      }

      if (attendance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A presen\u00E7a n\u00E3o foi registrada. O aluno pode j\u00E1 estar presente ou a sess\u00E3o pode ter sido encerrada.',
            ),
          ),
        );
        return;
      }

      await controller.refreshCurrentSession();

      if (!mounted) {
        return;
      }

      setState(() {
        studentNames[selectedStudent.id] = selectedStudent.fullName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Presença de ${selectedStudent.fullName} registrada manualmente.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'N\u00E3o foi poss\u00EDvel registrar a presen\u00E7a manual: $error',
          ),
        ),
      );
    }
  }

  Future<void> invalidateAttendance(
    Attendance attendance,
    String studentName,
  ) async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Corrigir presença'),
          content: Text(
            'Invalidar a presença de $studentName nesta aula? '
            'Ela deixar\u00E1 de contar no acompanhamento e na gradua\u00E7\u00E3o.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Invalidar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await context.read<AttendanceRepository>().invalidateAttendance(
        academyId: currentUser.academyId,
        attendanceId: attendance.id,
        invalidatedBy: currentUser.id,
      );

      if (!mounted) {
        return;
      }

      await context.read<TeacherCheckInController>().refreshCurrentSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Presença de $studentName invalidada.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'N\u00E3o foi poss\u00EDvel invalidar a presen\u00E7a: $error',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TeacherCheckInController>();
    final session = controller.currentSession;
    final attendances = controller.attendances;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Check-in da Turma'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Painel de Chamada',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gere o QR Code e acompanhe os alunos entrando na aula.',
              style: TextStyle(fontSize: 17, color: AppColors.grey),
            ),
            const SizedBox(height: 24),

            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Turma', style: _titleStyle),
                  const SizedBox(height: 12),
                  if (isLoadingClassrooms)
                    const Center(child: CircularProgressIndicator())
                  else if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: AppColors.gracieRed),
                    )
                  else if (classrooms.isEmpty)
                    const Text(
                      'Nenhuma turma ativa cadastrada.',
                      style: TextStyle(color: AppColors.grey),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedClassroomId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: classrooms
                          .map(
                            (classroom) => DropdownMenuItem<String>(
                              value: classroom.id,
                              child: Text(classroom.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedClassroomId = value;
                        });

                        controller.clearSession();
                      },
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: generateSession,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text(
                        'Gerar QR Code',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (session != null) ...[
              const SizedBox(height: 18),

              _Card(
                child: Column(
                  children: [
                    QrImageView(
                      data: session.id,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: AppColors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      classrooms
                              .where(
                                (classroom) =>
                                    classroom.id == session.classroomId,
                              )
                              .map((classroom) => classroom.name)
                              .firstOrNull ??
                          session.classroomId,
                      style: _bigTitleStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.isActive
                          ? '\u{1F7E2} QR Code ativo'
                          : session.isClosed
                          ? '\u{1F534} Sess\u00E3o encerrada'
                          : '\u{1F7E0} Sess\u00E3o expirada',
                      style: TextStyle(
                        color: session.isActive
                            ? AppColors.success
                            : AppColors.gracieRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Expira \u00E0s ${formatTime(session.expiresAt)}',
                      style: const TextStyle(
                        color: AppColors.gracieRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Presentes (${attendances.length})',
                      style: _titleStyle,
                    ),
                    const SizedBox(height: 12),
                    if (session.isActive) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: addManualAttendance,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Adicionar presença manual'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (attendances.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.hourglass_empty,
                                size: 42,
                                color: AppColors.grey,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Nenhum aluno realizou o check-in ainda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...attendances.map(
                        (attendance) => _StudentRow(
                          studentName:
                              studentNames[attendance.studentId] ??
                              attendance.studentId,
                          dateTime: attendance.dateTime,
                          source: attendance.source,
                          onInvalidate: () => invalidateAttendance(
                            attendance,
                            studentNames[attendance.studentId] ??
                                attendance.studentId,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: session.isActive ? closeSession : null,
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    'Encerrar Chamada',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gracieRed,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StudentRow extends StatelessWidget {
  final String studentName;
  final DateTime dateTime;
  final AttendanceSource source;
  final VoidCallback onInvalidate;

  const _StudentRow({
    required this.studentName,
    required this.dateTime,
    required this.source,
    required this.onInvalidate,
  });

  @override
  Widget build(BuildContext context) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final sourceLabel = source == AttendanceSource.manual
        ? 'Manual'
        : 'QR Code';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle, color: AppColors.success),
      title: Text(studentName),
      subtitle: Text('$sourceLabel - $hour:$minute'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opções da presença',
        onSelected: (value) {
          if (value == 'invalidate') {
            onInvalidate();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'invalidate',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, color: AppColors.gracieRed),
                SizedBox(width: 10),
                Text('Corrigir presença'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: AppColors.brandPrimary,
);

const _bigTitleStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: AppColors.brandPrimary,
);
