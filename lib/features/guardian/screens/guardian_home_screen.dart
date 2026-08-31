import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../../student/student_home_screen.dart';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Student> students = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadStudents());
  }

  Future<void> loadStudents() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sessão não encontrada.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedStudents = await context
          .read<StudentRepository>()
          .getStudentsByGuardianId(
            academyId: currentUser.academyId,
            guardianId: currentUser.id,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        students = loadedStudents
            .where((student) => student.isActive)
            .toList(growable: false);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar os alunos vinculados: $error';
      });
    }
  }

  Future<void> openStudent(Student student) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StudentHomeScreen(selectedStudent: student, guardianView: true),
      ),
    );

    if (mounted) {
      await loadStudents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Meus alunos'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loadStudents,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadStudents,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.gracieRed,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: loadStudents,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ),
                ],
              )
            : students.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.family_restroom, size: 72, color: AppColors.grey),
                  SizedBox(height: 18),
                  Text(
                    'Nenhum aluno vinculado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.brandPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Peça à administração da academia para vincular os alunos à sua conta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Acompanhe seus filhos',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Selecione um aluno para acessar a jornada, a graduação e o check-in.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ...students.map(
                    (student) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _StudentCard(
                        student: student,
                        onTap: () => openStudent(student),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.white,
          child: Text(
            _initials(student.fullName),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          student.fullName,
          style: const TextStyle(
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text('Ver jornada e registrar presença'),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }

  String _initials(String name) {
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

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
