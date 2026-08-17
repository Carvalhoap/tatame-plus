import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/graduation_program.dart';
import '../repository/graduation_program_repository.dart';
import 'graduation_program_form_screen.dart';

class GraduationProgramsScreen extends StatefulWidget {
  const GraduationProgramsScreen({super.key});

  @override
  State<GraduationProgramsScreen> createState() =>
      _GraduationProgramsScreenState();
}

class _GraduationProgramsScreenState extends State<GraduationProgramsScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<GraduationProgram> programs = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadPrograms());
  }

  Future<void> loadPrograms() async {
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
      final result = await context
          .read<GraduationProgramRepository>()
          .getActivePrograms(academyId: currentUser.academyId);

      if (!mounted) {
        return;
      }

      setState(() {
        programs = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar os programas: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Graduações'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const GraduationProgramFormScreen(),
            ),
          );

          if (changed == true && mounted) {
            await loadPrograms();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo programa'),
      ),
      body: RefreshIndicator(
        onRefresh: loadPrograms,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            const Text(
              'Programas de graduação',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Defina faixas, estágios e critérios de progressão da academia.',
              style: TextStyle(color: AppColors.grey),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (errorMessage != null)
              _MessageCard(icon: Icons.error_outline, message: errorMessage!)
            else if (programs.isEmpty)
              const _MessageCard(
                icon: Icons.sports_martial_arts,
                message: 'Nenhum programa de graduação cadastrado.',
              )
            else
              ...programs.map(
                (program) => _ProgramCard(
                  program: program,
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GraduationProgramFormScreen(program: program),
                      ),
                    );

                    if (changed == true && mounted) {
                      await loadPrograms();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final GraduationProgram program;
  final VoidCallback onTap;

  const _ProgramCard({required this.program, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.sports_martial_arts)),
        title: Text(
          program.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_audienceName(program.audience)} • '
          '${program.stages.length} estágio(s)',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  static String _audienceName(GraduationAudience audience) {
    switch (audience) {
      case GraduationAudience.kids:
        return 'Kids';
      case GraduationAudience.adult:
        return 'Adulto';
      case GraduationAudience.custom:
        return 'Personalizado';
    }
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: AppColors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
