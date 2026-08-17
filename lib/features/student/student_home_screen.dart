import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/graduation_belt_widget.dart';
import '../graduation/models/belt_color.dart';
import '../mascot/data/mascot_mock.dart';
import '../auth/services/session_service.dart';
import '../graduation/models/graduation_program.dart';
import '../graduation/models/graduation_stage.dart';
import '../graduation/models/student_graduation_progress.dart';
import '../graduation/models/stripe_progress.dart';
import '../graduation/repository/graduation_program_repository.dart';
import '../graduation/repository/student_graduation_progress_repository.dart';
import 'models/student.dart';
import 'repository/student_repository.dart';
import '../mascot/widgets/mascot_card.dart';
import 'data/student_mock.dart';
import 'screens/student_qr_scanner_screen.dart';
import 'widgets/belt_journey_card.dart';
import 'widgets/graduation_card.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  bool isLoading = true;
  String? errorMessage;
  Student? loadedStudent;
  StudentGraduationProgress? graduationProgress;
  GraduationProgram? graduationProgram;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadStudent());
  }

  Future<void> loadStudent() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sessão não encontrada.';
      });

      return;
    }

    try {
      final studentRepository = context.read<StudentRepository>();

      final graduationProgressRepository = context
          .read<StudentGraduationProgressRepository>();

      final graduationProgramRepository = context
          .read<GraduationProgramRepository>();

      final student = await studentRepository.getStudentByUserId(
        academyId: currentUser.academyId,
        userId: currentUser.id,
      );

      StudentGraduationProgress? progress;
      GraduationProgram? program;

      if (student != null) {
        progress = await graduationProgressRepository.getByStudent(
          academyId: currentUser.academyId,
          studentId: student.id,
        );

        final programId =
            progress?.graduationProgramId ?? student.graduationProgramId;

        if (programId != null && programId.isNotEmpty) {
          program = await graduationProgramRepository.getProgramById(
            academyId: currentUser.academyId,
            programId: programId,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        loadedStudent = student;
        graduationProgress = progress;
        graduationProgram = program;
        isLoading = false;

        if (student == null) {
          errorMessage =
              'Nenhum cadastro de aluno está vinculado a este usuário.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar seus dados: $error';
      });
    }
  }

  GraduationStage? get currentGraduationStage {
    final progress = graduationProgress;
    final program = graduationProgram;

    if (progress == null || program == null) {
      return null;
    }

    for (final stage in program.stages) {
      if (stage.id == progress.currentStageId) {
        return stage;
      }
    }

    return null;
  }

  BeltColor _beltColorFromName(String beltName) {
    switch (beltName.trim().toLowerCase()) {
      case 'branca':
        return BeltColor.white;

      case 'cinza e branca':
        return BeltColor.greyWhite;

      case 'cinza':
        return BeltColor.grey;

      case 'cinza e preta':
        return BeltColor.greyBlack;

      case 'amarela e branca':
        return BeltColor.yellowWhite;

      case 'amarela':
        return BeltColor.yellow;

      case 'amarela e preta':
        return BeltColor.yellowBlack;

      case 'laranja e branca':
        return BeltColor.orangeWhite;

      case 'laranja':
        return BeltColor.orange;

      case 'laranja e preta':
        return BeltColor.orangeBlack;

      case 'verde e branca':
        return BeltColor.greenWhite;

      case 'verde':
        return BeltColor.green;

      case 'verde e preta':
        return BeltColor.greenBlack;

      case 'azul':
        return BeltColor.blue;

      case 'roxa':
        return BeltColor.purple;

      case 'marrom':
        return BeltColor.brown;

      case 'preta':
        return BeltColor.black;

      default:
        return BeltColor.white;
    }
  }

  List<StripeProgress> get currentStageStripes {
    final stage = currentGraduationStage;

    if (stage == null) {
      return const [];
    }

    final degreeName = stage.degreeName;

    if (degreeName == null || degreeName.isEmpty) {
      return const [];
    }

    final match = RegExp(r'\d+').firstMatch(degreeName);

    final earned = match == null ? 0 : int.tryParse(match.group(0) ?? '') ?? 0;

    if (earned <= 0) {
      return const [];
    }

    final stripeColor = switch (stage.stripeColor?.trim().toLowerCase()) {
      'vermelha' || 'vermelho' => StripeColor.red,
      'preta' || 'preto' => StripeColor.black,
      _ => StripeColor.white,
    };

    return [StripeProgress(color: stripeColor, earned: earned, total: 4)];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Minha Jornada'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.brandPrimary,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null || loadedStudent == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Minha Jornada'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.brandPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorMessage ?? 'Cadastro de aluno não encontrado.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: AppColors.grey),
            ),
          ),
        ),
      );
    }

    final student = loadedStudent!;
    const dashboard = mockStudentDashboardData;

    final mascot = mascots.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Minha Jornada'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bom dia, ${student.fullName} 👋',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada treino aproxima você da sua próxima evolução.',
              style: TextStyle(fontSize: 18, color: AppColors.grey),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final checkInConfirmed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentQrScannerScreen(),
                    ),
                  );

                  if (checkInConfirmed == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Presença registrada com sucesso! +1 treino.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  'Registrar presença',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gracieRed,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            MascotCard(mascot: mascot),
            const SizedBox(height: 24),
            const BeltJourneyCard(),
            const SizedBox(height: 18),
            const Text(
              'Minha graduação',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (graduationProgress != null &&
                graduationProgram != null &&
                currentGraduationStage != null) ...[
              GraduationBeltWidget(
                beltColor: _beltColorFromName(currentGraduationStage!.beltName),
                stripes: currentStageStripes,
              ),
              const SizedBox(height: 10),
              Text(
                currentGraduationStage!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 18),
              GraduationCard(
                progress: graduationProgress!,
                program: graduationProgram!,
              ),
            ] else
              const _SimpleCard(
                title: 'Graduação',
                text: 'Graduação ainda não definida.',
              ),
            const SizedBox(height: 18),
            _InfoCard(
              title: '🔥 Meta do mês',
              subtitle:
                  '${dashboard.monthlyTrainings} / '
                  '${dashboard.monthlyGoal} treinos',
              progress: dashboard.monthlyProgress,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: '🏆 Próxima conquista',
              text:
                  '${dashboard.nextAchievement} • '
                  '${(dashboard.achievementProgress * 100).round()}%',
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: '🔥 Sequência atual',
              text: '${dashboard.streak} treinos consecutivos',
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: '📅 Próximo treino',
              text:
                  '${dashboard.nextTraining}\n'
                  '${dashboard.teacherName}',
            ),
            const SizedBox(height: 18),
            _SimpleCard(title: '💬 Frase do dia', text: dashboard.quote),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color color;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _cardTitleStyle()),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.black12,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final String title;
  final String text;

  const _SimpleCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _cardTitleStyle()),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontSize: 17, height: 1.4)),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

TextStyle _cardTitleStyle() {
  return const TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.bold,
    color: AppColors.brandPrimary,
  );
}
