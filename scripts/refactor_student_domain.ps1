$ErrorActionPreference = "Stop"

$projectRoot = "C:\Users\XANCAR\tatame_plus"
$backupRoot = "C:\Users\XANCAR\tatame_plus_backups"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupRoot "student-domain-$timestamp"

Set-Location $projectRoot

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path $Path -Parent

    if (-not (Test-Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

Write-Host ""
Write-Host "========================================="
Write-Host "Tatame+ - Refatoração Student Domain"
Write-Host "========================================="
Write-Host ""

$filesToBackup = @(
    "lib\features\student\models\student.dart",
    "lib\features\student\repository\student_repository.dart",
    "lib\features\student\data\student_mock.dart",
    "lib\features\student\data\mock\student_mock_repository.dart",
    "lib\features\student\student_home_screen.dart",
    "lib\features\student\widgets\graduation_card.dart"
)

foreach ($relativePath in $filesToBackup) {
    $fullPath = Join-Path $projectRoot $relativePath

    if (-not (Test-Path $fullPath)) {
        throw "Arquivo esperado não encontrado: $fullPath"
    }
}

New-Item `
    -Path $backupPath `
    -ItemType Directory `
    -Force | Out-Null

foreach ($relativePath in $filesToBackup) {
    $source = Join-Path $projectRoot $relativePath

    $safeName = $relativePath.Replace("\", "__")

    Copy-Item `
        -Path $source `
        -Destination (Join-Path $backupPath $safeName) `
        -Force
}

Write-Host "Backup criado em:"
Write-Host $backupPath
Write-Host ""

# ============================================================
# STUDENT MODEL
# ============================================================

$studentModel = @'
enum StudentStatus {
  active,
  inactive,
}

class Student {
  final String id;
  final String academyId;

  /// UID do Firebase Authentication.
  ///
  /// Pode ser nulo para alunos que não possuem login próprio,
  /// como crianças vinculadas a um responsável.
  final String? userId;

  final String fullName;
  final DateTime? birthDate;

  final String? phone;
  final String? email;
  final String? photoUrl;

  /// Programa oficial de graduação utilizado por este aluno.
  ///
  /// Exemplo: adult_program_1.
  final String? graduationProgramId;

  /// Data em que começou a praticar Jiu-Jitsu.
  final DateTime? jiuJitsuStartDate;

  /// Data de entrada nesta academia.
  final DateTime? academyJoinDate;

  final List<String> classroomIds;
  final List<String> guardianIds;

  final StudentStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// UID do usuário que realizou o cadastro.
  final String createdBy;

  const Student({
    required this.id,
    required this.academyId,
    required this.fullName,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.userId,
    this.birthDate,
    this.phone,
    this.email,
    this.photoUrl,
    this.graduationProgramId,
    this.jiuJitsuStartDate,
    this.academyJoinDate,
    this.classroomIds = const [],
    this.guardianIds = const [],
    this.status = StudentStatus.active,
  });

  bool get isActive => status == StudentStatus.active;

  bool get hasLogin => userId != null && userId!.isNotEmpty;
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\student\models\student.dart") `
    -Content $studentModel

# ============================================================
# DASHBOARD MODEL
# ============================================================

$dashboardModel = @'
class StudentDashboardData {
  final int monthlyTrainings;
  final int monthlyGoal;

  final int streak;

  final String nextAchievement;
  final double achievementProgress;

  final String nextTraining;
  final String teacherName;

  final String quote;

  const StudentDashboardData({
    this.monthlyTrainings = 0,
    this.monthlyGoal = 12,
    this.streak = 0,
    this.nextAchievement = '',
    this.achievementProgress = 0,
    this.nextTraining = '',
    this.teacherName = '',
    this.quote = '',
  });

  double get monthlyProgress {
    if (monthlyGoal <= 0) {
      return 0;
    }

    return (monthlyTrainings / monthlyGoal).clamp(0, 1);
  }
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\student\models\student_dashboard_data.dart") `
    -Content $dashboardModel

# ============================================================
# STUDENT REPOSITORY
# ============================================================

$studentRepository = @'
import '../models/student.dart';

abstract class StudentRepository {
  Future<List<Student>> getStudentsByAcademy(
    String academyId,
  );

  Future<Student?> getStudentById(
    String studentId,
  );
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\student\repository\student_repository.dart") `
    -Content $studentRepository

# ============================================================
# MOCK STUDENT REPOSITORY
# ============================================================

$studentMockRepository = @'
import '../../models/student.dart';
import '../../repository/student_repository.dart';

class StudentMockRepository implements StudentRepository {
  final List<Student> _students = [
    Student(
      id: '1',
      academyId: 'academy_1',
      userId: 'mock-admin',
      fullName: 'Alexandre Carvalho',
      birthDate: DateTime(1990, 1, 1),
      phone: '21999999999',
      email: 'alexandre@email.com',
      graduationProgramId: 'adult_program_1',
      jiuJitsuStartDate: DateTime(2024, 1, 1),
      academyJoinDate: DateTime(2024, 1, 1),
      classroomIds: const ['class_1'],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2026, 8, 11),
      createdBy: 'mock-admin',
    ),
  ];

  @override
  Future<List<Student>> getStudentsByAcademy(
    String academyId,
  ) async {
    return _students
        .where(
          (student) => student.academyId == academyId,
        )
        .toList(growable: false);
  }

  @override
  Future<Student?> getStudentById(
    String studentId,
  ) async {
    for (final student in _students) {
      if (student.id == studentId) {
        return student;
      }
    }

    return null;
  }
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\student\data\mock\student_mock_repository.dart") `
    -Content $studentMockRepository

# ============================================================
# STUDENT MOCK
# ============================================================

$studentMock = @'
import '../models/student.dart';
import '../models/student_dashboard_data.dart';

final mockStudent = Student(
  id: '1',
  academyId: 'academy_1',
  userId: 'mock-admin',
  fullName: 'Alexandre',
  birthDate: DateTime(1990, 1, 1),
  phone: '21999999999',
  email: 'alexandre@email.com',
  graduationProgramId: 'adult_program_1',
  jiuJitsuStartDate: DateTime(2024, 1, 1),
  academyJoinDate: DateTime(2024, 1, 1),
  classroomIds: const ['class_1'],
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2026, 8, 11),
  createdBy: 'mock-admin',
);

const mockStudentDashboardData = StudentDashboardData(
  monthlyTrainings: 8,
  monthlyGoal: 12,
  streak: 5,
  nextAchievement: 'Guerreiro de Bronze',
  achievementProgress: 0.82,
  nextTraining: 'Hoje • 20:30',
  teacherName: 'Professor Thiagão',
  quote:
      'A disciplina vence o talento quando o talento não tem disciplina.',
);
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\student\data\student_mock.dart") `
    -Content $studentMock

# ============================================================
# GRADUATION CARD
# ============================================================

$graduationCard = @'
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../graduation/models/graduation_program.dart';
import '../../graduation/models/graduation_stage.dart';
import '../../graduation/models/student_graduation_progress.dart';

class GraduationCard extends StatelessWidget {
  final StudentGraduationProgress progress;
  final GraduationProgram program;

  const GraduationCard({
    super.key,
    required this.progress,
    required this.program,
  });

  @override
  Widget build(BuildContext context) {
    final currentStage = _findStage(
      progress.currentStageId,
    );

    if (currentStage == null) {
      return _UnavailableGraduationCard(
        message:
            'O estágio atual de graduação não foi encontrado no programa.',
      );
    }

    final nextStage = currentStage.nextStageId == null
        ? null
        : _findStage(currentStage.nextStageId!);

    final requiredAttendances =
        currentStage.requiredAttendances;

    final attendanceProgress =
        requiredAttendances == null ||
                requiredAttendances <= 0
            ? null
            : (progress.validAttendances /
                    requiredAttendances)
                .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.08,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            '🥋 Próxima graduação',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nextStage == null
                ? currentStage.name
                : '${currentStage.name} → ${nextStage.name}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
          if (attendanceProgress != null) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: attendanceProgress,
              minHeight: 12,
              borderRadius:
                  BorderRadius.circular(20),
              backgroundColor: Colors.black12,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 10),
            Text(
              '${progress.validAttendances} / '
              '$requiredAttendances presenças válidas',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ],
          if (currentStage.minimumDurationMonths !=
              null) ...[
            const SizedBox(height: 12),
            Text(
              'Tempo mínimo: '
              '${currentStage.minimumDurationMonths} meses',
              style: const TextStyle(
                color: AppColors.grey,
              ),
            ),
          ],
          if (progress.estimatedCompletionDate !=
              null) ...[
            const SizedBox(height: 6),
            Text(
              'Previsão: '
              '${_formatDate(progress.estimatedCompletionDate!)}',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (progress.approvedByTeacher) ...[
            const SizedBox(height: 10),
            const Text(
              'Aprovado pelo professor',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  GraduationStage? _findStage(
    String stageId,
  ) {
    for (final stage in program.stages) {
      if (stage.id == stageId) {
        return stage;
      }
    }

    return null;
  }

  static String _formatDate(
    DateTime date,
  ) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    return '${months[date.month - 1]} de ${date.year}';
  }
}

class _UnavailableGraduationCard
    extends StatelessWidget {
  final String message;

  const _UnavailableGraduationCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.grey,
        ),
      ),
    );
  }
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\student\widgets\graduation_card.dart") `
    -Content $graduationCard

# ============================================================
# STUDENT HOME SCREEN
# ============================================================

$studentHome = @'
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_drawer.dart';
import '../../core/widgets/graduation_belt_widget.dart';
import '../graduation/data/mock/adult_graduation_program_mock.dart';
import '../graduation/data/mock/student_graduation_progress_mock.dart';
import '../graduation/models/belt_color.dart';
import '../mascot/data/mascot_mock.dart';
import '../mascot/widgets/mascot_card.dart';
import 'data/student_mock.dart';
import 'screens/student_qr_scanner_screen.dart';
import 'widgets/belt_journey_card.dart';
import 'widgets/graduation_card.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = mockStudent;
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
              style: TextStyle(
                fontSize: 18,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final checkInConfirmed =
                      await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const StudentQrScannerScreen(),
                    ),
                  );

                  if (checkInConfirmed == true &&
                      context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Presença registrada com sucesso! +1 treino.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.qr_code_scanner,
                ),
                label: const Text(
                  'Registrar presença',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.gracieRed,
                  foregroundColor:
                      AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            MascotCard(
              mascot: mascot,
            ),
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
            GraduationBeltWidget(
              beltColor: BeltColor.white,
              stripes:
                  studentGraduationProgressMock
                      .stripes,
            ),
            const SizedBox(height: 18),
            GraduationCard(
              progress:
                  studentGraduationProgressMock,
              program:
                  adultGraduationProgramMock,
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: '🔥 Meta do mês',
              subtitle:
                  '${dashboard.monthlyTrainings} / '
                  '${dashboard.monthlyGoal} treinos',
              progress:
                  dashboard.monthlyProgress,
              color:
                  AppColors.brandPrimary,
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
              text:
                  '${dashboard.streak} treinos consecutivos',
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: '📅 Próximo treino',
              text:
                  '${dashboard.nextTraining}\n'
                  '${dashboard.teacherName}',
            ),
            const SizedBox(height: 18),
            _SimpleCard(
              title: '💬 Frase do dia',
              text: dashboard.quote,
            ),
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _cardTitleStyle(),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            borderRadius:
                BorderRadius.circular(20),
            backgroundColor: Colors.black12,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final String title;
  final String text;

  const _SimpleCard({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: _cardTitleStyle(),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              height: 1.4,
            ),
          ),
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
        color: Colors.black.withValues(
          alpha: 0.08,
        ),
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
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\student\student_home_screen.dart") `
    -Content $studentHome

# ============================================================
# VALIDATION
# ============================================================

Write-Host ""
Write-Host "Formatando..."
dart format lib

if ($LASTEXITCODE -ne 0) {
    throw "dart format falhou."
}

Write-Host ""
Write-Host "Executando flutter analyze..."
flutter analyze

if ($LASTEXITCODE -ne 0) {
    throw "flutter analyze encontrou problemas."
}

Write-Host ""
Write-Host "Executando flutter test..."
flutter test

if ($LASTEXITCODE -ne 0) {
    throw "flutter test encontrou problemas."
}

Write-Host ""
Write-Host "========================================="
Write-Host "REFATORAÇÃO CONCLUÍDA COM SUCESSO"
Write-Host "========================================="
Write-Host ""
Write-Host "Backup:"
Write-Host $backupPath