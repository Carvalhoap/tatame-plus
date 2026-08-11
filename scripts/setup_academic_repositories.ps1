$ErrorActionPreference = "Stop"

$projectRoot = "C:\Users\XANCAR\tatame_plus"
$backupRoot = "C:\Users\XANCAR\tatame_plus_backups"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupRoot "academic-repositories-$timestamp"

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
Write-Host "==============================================="
Write-Host "Tatame+ - Estrutura acadêmica real"
Write-Host "==============================================="
Write-Host ""

$filesToBackup = @(
    "lib\app\app.dart",
    "lib\features\classroom\models\classroom.dart",
    "firestore.rules"
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
# CLASSROOM MODEL
# ============================================================

$classroomModel = @'
class Classroom {
  final String id;
  final String academyId;
  final String name;
  final String description;
  final List<String> teacherIds;
  final bool isActive;

  const Classroom({
    required this.id,
    required this.academyId,
    required this.name,
    this.description = '',
    this.teacherIds = const [],
    this.isActive = true,
  });
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\classroom\models\classroom.dart") `
    -Content $classroomModel

# ============================================================
# CLASSROOM REPOSITORY
# ============================================================

$classroomRepository = @'
import '../models/classroom.dart';

abstract class ClassroomRepository {
  Future<List<Classroom>> getActiveClassrooms({
    required String academyId,
  });
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\classroom\repository\classroom_repository.dart") `
    -Content $classroomRepository

# ============================================================
# FIRESTORE CLASSROOM REPOSITORY
# ============================================================

$firestoreClassroomRepository = @'
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/classroom.dart';
import '../../repository/classroom_repository.dart';

class FirestoreClassroomRepository
    implements ClassroomRepository {
  final FirebaseFirestore firestore;

  FirestoreClassroomRepository({
    FirebaseFirestore? firestore,
  }) : firestore =
            firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Classroom>> getActiveClassrooms({
    required String academyId,
  }) async {
    final snapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('classrooms')
        .where('isActive', isEqualTo: true)
        .get();

    final classrooms = snapshot.docs.map((document) {
      final data = document.data();

      return Classroom(
        id: document.id,
        academyId: academyId,
        name: data['name'] as String? ?? 'Turma sem nome',
        description:
            data['description'] as String? ?? '',
        teacherIds: _parseStringList(
          data['teacherIds'],
        ),
        isActive: data['isActive'] == true,
      );
    }).toList();

    classrooms.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(b.name.toLowerCase()),
    );

    return classrooms;
  }

  List<String> _parseStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<String>()
        .toList(growable: false);
  }
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\classroom\data\firebase\firestore_classroom_repository.dart") `
    -Content $firestoreClassroomRepository

# ============================================================
# GRADUATION PROGRAM REPOSITORY
# ============================================================

$graduationRepository = @'
import '../models/graduation_program.dart';

abstract class GraduationProgramRepository {
  Future<List<GraduationProgram>>
      getActivePrograms({
    required String academyId,
  });
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\graduation\repository\graduation_program_repository.dart") `
    -Content $graduationRepository

# ============================================================
# FIRESTORE GRADUATION PROGRAM REPOSITORY
# ============================================================

$firestoreGraduationRepository = @'
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/graduation_program.dart';
import '../../models/graduation_stage.dart';
import '../../models/progression_criterion.dart';
import '../../repository/graduation_program_repository.dart';

class FirestoreGraduationProgramRepository
    implements GraduationProgramRepository {
  final FirebaseFirestore firestore;

  FirestoreGraduationProgramRepository({
    FirebaseFirestore? firestore,
  }) : firestore =
            firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<GraduationProgram>>
      getActivePrograms({
    required String academyId,
  }) async {
    final snapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('graduationPrograms')
        .where('isActive', isEqualTo: true)
        .get();

    final programs = snapshot.docs.map((document) {
      final data = document.data();

      return GraduationProgram(
        id: document.id,
        academyId: academyId,
        name: data['name'] as String? ??
            'Programa sem nome',
        audience: _parseAudience(
          data['audience'],
        ),
        stages: _parseStages(
          data['stages'],
        ),
        isActive: data['isActive'] == true,
      );
    }).toList();

    programs.sort(
      (a, b) => a.name
          .toLowerCase()
          .compareTo(b.name.toLowerCase()),
    );

    return programs;
  }

  GraduationAudience _parseAudience(
    dynamic value,
  ) {
    switch (value) {
      case 'kids':
        return GraduationAudience.kids;
      case 'adult':
        return GraduationAudience.adult;
      default:
        return GraduationAudience.custom;
    }
  }

  List<GraduationStage> _parseStages(
    dynamic value,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (stage) => GraduationStage(
            id: stage['id'] as String? ?? '',
            name: stage['name'] as String? ?? '',
            beltName:
                stage['beltName'] as String? ?? '',
            degreeName:
                stage['degreeName'] as String?,
            stripeColor:
                stage['stripeColor'] as String?,
            order: stage['order'] as int? ?? 0,
            criterion: _parseCriterion(
              stage['criterion'],
            ),
            requiredAttendances:
                stage['requiredAttendances'] as int?,
            minimumDurationMonths:
                stage['minimumDurationMonths']
                    as int?,
            nextStageId:
                stage['nextStageId'] as String?,
          ),
        )
        .where((stage) => stage.id.isNotEmpty)
        .toList(growable: false);
  }

  ProgressionCriterion _parseCriterion(
    dynamic value,
  ) {
    switch (value) {
      case 'attendance':
        return ProgressionCriterion.attendance;
      case 'time':
        return ProgressionCriterion.time;
      case 'attendanceAndTime':
        return ProgressionCriterion.attendanceAndTime;
      default:
        return ProgressionCriterion.manual;
    }
  }
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\features\graduation\data\firebase\firestore_graduation_program_repository.dart") `
    -Content $firestoreGraduationRepository

# ============================================================
# APP.DART
# ============================================================

$appContent = @'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';

import '../features/auth/data/firebase/firebase_auth_repository.dart';
import '../features/auth/repository/auth_repository.dart';
import '../features/auth/screens/session_router.dart';
import '../features/auth/services/session_service.dart';

import '../features/student/data/mock/student_mock_repository.dart';
import '../features/student/repository/student_repository.dart';

import '../features/attendance/data/mock/attendance_mock_repository.dart';
import '../features/attendance/repository/attendance_repository.dart';

import '../features/attendance/data/mock/check_in_session_mock_repository.dart';
import '../features/attendance/repository/check_in_session_repository.dart';

import '../features/teacher/controllers/teacher_check_in_controller.dart';

import '../features/users/data/firebase/firestore_user_repository.dart';
import '../features/users/repository/user_repository.dart';

import '../features/classroom/data/firebase/firestore_classroom_repository.dart';
import '../features/classroom/repository/classroom_repository.dart';

import '../features/graduation/data/firebase/firestore_graduation_program_repository.dart';
import '../features/graduation/repository/graduation_program_repository.dart';

class TatamePlusApp extends StatelessWidget {
  const TatamePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => FirebaseAuthRepository(),
        ),

        ChangeNotifierProvider(
          create: (_) => SessionService(),
        ),

        Provider<UserRepository>(
          create: (_) => FirestoreUserRepository(),
        ),

        Provider<ClassroomRepository>(
          create: (_) =>
              FirestoreClassroomRepository(),
        ),

        Provider<GraduationProgramRepository>(
          create: (_) =>
              FirestoreGraduationProgramRepository(),
        ),

        Provider<StudentRepository>(
          create: (_) => StudentMockRepository(),
        ),

        Provider<AttendanceRepository>(
          create: (_) => AttendanceMockRepository(),
        ),

        ChangeNotifierProvider<
            CheckInSessionRepository>(
          create: (_) =>
              CheckInSessionMockRepository(),
        ),

        ChangeNotifierProxyProvider<
          CheckInSessionRepository,
          TeacherCheckInController
        >(
          create: (context) =>
              TeacherCheckInController(
            repository:
                context.read<
                    CheckInSessionRepository>(),
          ),
          update: (_, repository, controller) {
            return controller ??
                TeacherCheckInController(
                  repository: repository,
                );
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tatame+',
        theme: AppTheme.light,
        home: const SessionRouter(),
      ),
    );
  }
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "lib\app\app.dart") `
    -Content $appContent

# ============================================================
# FIRESTORE RULES
# ============================================================

$firestoreRules = @'
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(uid) {
      return isSignedIn() &&
        request.auth.uid == uid;
    }

    function memberPath(academyId, uid) {
      return /databases/$(database)/documents/academies/$(academyId)/members/$(uid);
    }

    function isAcademyMember(academyId) {
      return isSignedIn()
        && exists(
          memberPath(
            academyId,
            request.auth.uid
          )
        )
        && get(
          memberPath(
            academyId,
            request.auth.uid
          )
        ).data.status == 'active';
    }

    function isAdmin(academyId) {
      return isAcademyMember(academyId)
        && get(
          memberPath(
            academyId,
            request.auth.uid
          )
        ).data.roles.admin == true;
    }

    function userBelongsToAcademy(
      academyId,
      uid
    ) {
      return exists(
        memberPath(
          academyId,
          uid
        )
      );
    }

    match /users/{uid} {
      allow get: if isOwner(uid)
        || (
          isSignedIn()
          && isAdmin(
            'gracie-barra-neves'
          )
          && userBelongsToAcademy(
            'gracie-barra-neves',
            uid
          )
        );

      allow list: if false;
      allow create, update, delete: if false;
    }

    match /academies/{academyId} {
      allow get:
        if isAcademyMember(academyId);

      allow list: if false;
      allow create, update, delete: if false;

      match /members/{uid} {
        allow get:
          if isOwner(uid)
          || isAdmin(academyId);

        allow list:
          if isAdmin(academyId);

        allow create, update, delete:
          if false;
      }

      match /classrooms/{classroomId} {
        allow get, list:
          if isAcademyMember(academyId);

        allow create, update, delete:
          if false;
      }

      match /graduationPrograms/{programId} {
        allow get, list:
          if isAcademyMember(academyId);

        allow create, update, delete:
          if false;
      }

      match /auditLogs/{documentId} {
        allow read, write: if false;
      }

      match /{document=**} {
        allow read, write: if false;
      }
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
'@

Write-Utf8File `
    -Path (Join-Path $projectRoot "firestore.rules") `
    -Content $firestoreRules

Write-Host ""
Write-Host "Formatando Flutter..."
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
Write-Host "==============================================="
Write-Host "ESTRUTURA ACADÊMICA CRIADA COM SUCESSO"
Write-Host "==============================================="
Write-Host ""
Write-Host "Backup:"
Write-Host $backupPath