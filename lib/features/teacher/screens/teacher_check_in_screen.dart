import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/models/attendance.dart';
import '../../attendance/models/check_in_session.dart';
import '../../attendance/repository/attendance_repository.dart';

class TeacherCheckInScreen extends StatefulWidget {
  const TeacherCheckInScreen({super.key});

  @override
  State<TeacherCheckInScreen> createState() =>
      _TeacherCheckInScreenState();
}

class _TeacherCheckInScreenState extends State<TeacherCheckInScreen> {
  String selectedClassroom = 'Adulto Noite';
  CheckInSession? currentSession;

  final List<String> classrooms = [
    'Kids',
    'Adulto Noite',
    'No-Gi',
    'Turma da Manhã',
  ];

  void generateQrCode() {
    final now = DateTime.now();

    setState(() {
      currentSession = CheckInSession(
        id: 'session_${now.millisecondsSinceEpoch}',
        academyId: 'academy_1',
        classroomId: selectedClassroom,
        teacherId: 'teacher_1',
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
    });
  }

  void closeSession() {
    setState(() {
      currentSession = null;
    });
  }

  String buildQrData(CheckInSession session) {
    return jsonEncode({
      'sessionId': session.id,
      'academyId': session.academyId,
      'classroomId': session.classroomId,
      'teacherId': session.teacherId,
      'expiresAt': session.expiresAt.toIso8601String(),
    });
  }

  String formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AttendanceRepository>();
    final session = currentSession;

    final List<Attendance> attendances = session == null
        ? []
        : repository.getAttendanceBySession(session.id);

    final presentNames = ['Alexandre', 'João', 'Rafael'];
    final waitingNames = ['Pedro', 'Carlos', 'Bruno'];

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
                  const Text('Turma', style: _titleStyle),
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
                      if (value == null) return;

                      setState(() {
                        selectedClassroom = value;
                        currentSession = null;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: generateQrCode,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Gerar QR Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.white,
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
                      data: buildQrData(session),
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: AppColors.white,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      selectedClassroom,
                      style: _bigTitleStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.isActive
                          ? '🟢 QR Code ativo'
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
                    ...presentNames.map(
                      (name) => _StudentRow(
                        name: name,
                        present: true,
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
                    const Text(
                      'Aguardando',
                      style: _titleStyle,
                    ),
                    const SizedBox(height: 12),
                    ...waitingNames.map(
                      (name) => _StudentRow(
                        name: name,
                        present: false,
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
                  onPressed: closeSession,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Encerrar Chamada'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gracieRed,
                    foregroundColor: AppColors.white,
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
            color: Colors.black.withOpacity(0.08),
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
  final String name;
  final bool present;

  const _StudentRow({
    required this.name,
    required this.present,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        present
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        color: present
            ? AppColors.success
            : AppColors.grey,
      ),
      title: Text(name),
      trailing: Text(
        present ? 'Presente' : 'Aguardando',
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