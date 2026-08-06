import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/teacher_check_in_controller.dart';

class TeacherCheckInScreen extends StatefulWidget {
  const TeacherCheckInScreen({super.key});

  @override
  State<TeacherCheckInScreen> createState() =>
      _TeacherCheckInScreenState();
}

class _TeacherCheckInScreenState extends State<TeacherCheckInScreen> {
  String selectedClassroom = 'Adulto Noite';

  final List<String> classrooms = const [
    'Kids',
    'Adulto Noite',
    'No-Gi',
    'Turma da Manhã',
  ];

  void generateSession() {
    context.read<TeacherCheckInController>().createSession(
          academyId: 'academy_1',
          classroomId: selectedClassroom,
          teacherId: 'teacher_1',
        );
  }

  void closeSession() {
    context.read<TeacherCheckInController>().closeCurrentSession();
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
              style: TextStyle(
                fontSize: 17,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 24),

            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Turma',
                    style: _titleStyle,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassroom,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    items: classrooms
                        .map(
                          (classroom) => DropdownMenuItem(
                            value: classroom,
                            child: Text(classroom),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        selectedClassroom = value;
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
                      session.classroomId,
                      style: _bigTitleStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.isActive
                          ? '🟢 QR Code ativo'
                          : session.isClosed
                              ? '🔴 Chamada encerrada'
                              : '🔴 QR Code expirado',
                      style: TextStyle(
                        color: session.isActive
                            ? AppColors.success
                            : AppColors.gracieRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Expira às ${formatTime(session.expiresAt)}',
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
                                style: TextStyle(
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...attendances.map(
                        (attendance) => _StudentRow(
                          studentId: attendance.studentId,
                          dateTime: attendance.dateTime,
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
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
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

  const _Card({
    required this.child,
  });

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
  final String studentId;
  final DateTime dateTime;

  const _StudentRow({
    required this.studentId,
    required this.dateTime,
  });

  @override
  Widget build(BuildContext context) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.check_circle,
        color: AppColors.success,
      ),
      title: Text(studentId),
      subtitle: Text('Check-in às $hour:$minute'),
      trailing: const Text(
        'Presente',
        style: TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.bold,
        ),
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