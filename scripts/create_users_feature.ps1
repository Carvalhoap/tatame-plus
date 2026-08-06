$ErrorActionPreference = "Stop"

$projectRoot = "C:\Users\XANCAR\tatame_plus"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path $projectRoot "backups\users-feature-$timestamp"

Set-Location $projectRoot

Write-Host ""
Write-Host "=========================================="
Write-Host "Tatame+ - Criando Gestão de Usuários"
Write-Host "=========================================="
Write-Host ""

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $parentDirectory = Split-Path $Path -Parent

    if (-not (Test-Path $parentDirectory)) {
        New-Item `
            -Path $parentDirectory `
            -ItemType Directory `
            -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

# --------------------------------------------------
# 1. Verificações
# --------------------------------------------------

Write-Host "1. Verificando arquivos atuais..."

$appFile = Join-Path $projectRoot "lib\app\app.dart"
$adminFile = Join-Path `
    $projectRoot `
    "lib\features\admin\screens\admin_home_screen.dart"

if (-not (Test-Path $appFile)) {
    throw "Arquivo não encontrado: $appFile"
}

if (-not (Test-Path $adminFile)) {
    throw "Arquivo não encontrado: $adminFile"
}

Write-Host "Arquivos principais encontrados."

# --------------------------------------------------
# 2. Backup
# --------------------------------------------------

Write-Host ""
Write-Host "2. Criando backup..."

New-Item `
    -Path $backupRoot `
    -ItemType Directory `
    -Force | Out-Null

Copy-Item `
    -Path $appFile `
    -Destination (Join-Path $backupRoot "app.dart") `
    -Force

Copy-Item `
    -Path $adminFile `
    -Destination (Join-Path $backupRoot "admin_home_screen.dart") `
    -Force

Write-Host "Backup criado em:"
Write-Host $backupRoot

# --------------------------------------------------
# 3. AcademyMember
# --------------------------------------------------

Write-Host ""
Write-Host "3. Criando AcademyMember..."

$academyMemberPath = Join-Path `
    $projectRoot `
    "lib\features\users\models\academy_member.dart"

$academyMemberContent = @"
class AcademyMember {
  final String userId;
  final String displayName;
  final String email;
  final String status;
  final Map<String, bool> roles;
  final bool isActive;

  const AcademyMember({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.status,
    required this.roles,
    required this.isActive,
  });

  bool hasRole(String role) {
    return roles[role] == true;
  }

  List<String> get activeRoles {
    return roles.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
  }
}
"@

Write-Utf8File `
    -Path $academyMemberPath `
    -Content $academyMemberContent

# --------------------------------------------------
# 4. UserRepository
# --------------------------------------------------

Write-Host "4. Criando UserRepository..."

$userRepositoryPath = Join-Path `
    $projectRoot `
    "lib\features\users\repository\user_repository.dart"

$userRepositoryContent = @"
import '../models/academy_member.dart';

abstract class UserRepository {
  Future<List<AcademyMember>> getAcademyMembers({
    required String academyId,
  });
}
"@

Write-Utf8File `
    -Path $userRepositoryPath `
    -Content $userRepositoryContent

# --------------------------------------------------
# 5. FirestoreUserRepository
# --------------------------------------------------

Write-Host "5. Criando FirestoreUserRepository..."

$firestoreRepositoryPath = Join-Path `
    $projectRoot `
    "lib\features\users\data\firebase\firestore_user_repository.dart"

$firestoreRepositoryContent = @"
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/academy_member.dart';
import '../../repository/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore firestore;

  FirestoreUserRepository({
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<AcademyMember>> getAcademyMembers({
    required String academyId,
  }) async {
    final membersSnapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('members')
        .get();

    final members = await Future.wait(
      membersSnapshot.docs.map((memberDocument) async {
        final memberData = memberDocument.data();
        final userId =
            memberData['userId'] as String? ?? memberDocument.id;

        final userSnapshot = await firestore
            .collection('users')
            .doc(userId)
            .get();

        final userData = userSnapshot.data();

        return AcademyMember(
          userId: userId,
          displayName:
              userData?['displayName'] as String? ?? 'Usuário sem nome',
          email: userData?['email'] as String? ?? '',
          status: memberData['status'] as String? ?? 'inactive',
          roles: _parseRoles(memberData['roles']),
          isActive: userData?['isActive'] == true,
        );
      }),
    );

    members.sort(
      (first, second) => first.displayName.toLowerCase().compareTo(
            second.displayName.toLowerCase(),
          ),
    );

    return members;
  }

  Map<String, bool> _parseRoles(dynamic rawRoles) {
    if (rawRoles is! Map) {
      return const {};
    }

    return rawRoles.map(
      (key, value) => MapEntry(
        key.toString(),
        value == true,
      ),
    );
  }
}
"@

Write-Utf8File `
    -Path $firestoreRepositoryPath `
    -Content $firestoreRepositoryContent

# --------------------------------------------------
# 6. UsersScreen
# --------------------------------------------------

Write-Host "6. Criando UsersScreen..."

$usersScreenPath = Join-Path `
    $projectRoot `
    "lib\features\users\screens\users_screen.dart"

$usersScreenContent = @"
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/academy_member.dart';
import '../repository/user_repository.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final searchController = TextEditingController();

  Future<List<AcademyMember>>? membersFuture;
  String searchTerm = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    membersFuture ??= _loadMembers();
  }

  Future<List<AcademyMember>> _loadMembers() {
    final session = context.read<SessionService>();
    final user = session.currentUser;

    if (user == null) {
      return Future.error(
        StateError('Nenhum usuário autenticado foi encontrado.'),
      );
    }

    return context.read<UserRepository>().getAcademyMembers(
          academyId: user.academyId,
        );
  }

  void reload() {
    setState(() {
      membersFuture = _loadMembers();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Usuários'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'O cadastro de usuários será implementado na próxima etapa.',
              ),
            ),
          );
        },
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo usuário'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome ou e-mail',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchTerm.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();

                          setState(() {
                            searchTerm = '';
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchTerm = value.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<AcademyMember>>(
                future: membersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(
                      error: snapshot.error,
                      onRetry: reload,
                    );
                  }

                  final members = snapshot.data ?? const [];

                  final filteredMembers = members.where((member) {
                    if (searchTerm.isEmpty) {
                      return true;
                    }

                    return member.displayName
                            .toLowerCase()
                            .contains(searchTerm) ||
                        member.email
                            .toLowerCase()
                            .contains(searchTerm);
                  }).toList(growable: false);

                  if (members.isEmpty) {
                    return const _EmptyState(
                      title: 'Nenhum usuário encontrado',
                      message:
                          'Os usuários vinculados à academia aparecerão aqui.',
                    );
                  }

                  if (filteredMembers.isEmpty) {
                    return const _EmptyState(
                      title: 'Nenhum resultado',
                      message:
                          'Tente pesquisar usando outro nome ou e-mail.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      reload();
                      await membersFuture;
                    },
                    child: ListView.separated(
                      itemCount: filteredMembers.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _MemberCard(
                          member: filteredMembers[index],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final AcademyMember member;

  const _MemberCard({
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    final roles = member.activeRoles
        .map(_roleLabel)
        .join(' • ');

    return Card(
      color: AppColors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.white,
          child: Text(
            _initials(member.displayName),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          member.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.brandPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(member.email),
            ],
            const SizedBox(height: 4),
            Text(
              roles.isEmpty ? 'Sem perfil autorizado' : roles,
            ),
          ],
        ),
        trailing: Icon(
          member.isActive && member.status == 'active'
              ? Icons.check_circle
              : Icons.cancel,
          color: member.isActive && member.status == 'active'
              ? AppColors.success
              : AppColors.gracieRed,
        ),
      ),
    );
  }

  static String _initials(String name) {
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

    return (
      parts.first.substring(0, 1) +
      parts.last.substring(0, 1)
    ).toUpperCase();
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'partner':
        return 'Sócio';
      case 'teacher':
        return 'Professor';
      case 'student':
        return 'Aluno';
      case 'guardian':
        return 'Responsável';
      default:
        return role;
    }
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 64,
              color: AppColors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    String message =
        'Não foi possível carregar os usuários.';

    if (error is FirebaseException &&
        (error as FirebaseException).code ==
            'permission-denied') {
      message =
          'O Firestore ainda não autorizou a listagem dos usuários.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 16),
            const Text(
              'Não foi possível carregar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grey,
              ),
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
"@

Write-Utf8File `
    -Path $usersScreenPath `
    -Content $usersScreenContent

# --------------------------------------------------
# 7. app.dart completo
# --------------------------------------------------

Write-Host "7. Atualizando app.dart..."

$appContent = @"
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

        Provider<StudentRepository>(
          create: (_) => StudentMockRepository(),
        ),

        Provider<AttendanceRepository>(
          create: (_) => AttendanceMockRepository(),
        ),

        ChangeNotifierProvider<CheckInSessionRepository>(
          create: (_) => CheckInSessionMockRepository(),
        ),

        ChangeNotifierProxyProvider<
          CheckInSessionRepository,
          TeacherCheckInController
        >(
          create: (context) => TeacherCheckInController(
            repository: context.read<CheckInSessionRepository>(),
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
"@

Write-Utf8File `
    -Path $appFile `
    -Content $appContent

# --------------------------------------------------
# 8. AdminHomeScreen completo
# --------------------------------------------------

Write-Host "8. Atualizando AdminHomeScreen..."

$adminContent = @"
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../auth/services/session_service.dart';
import '../../users/screens/users_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Gestão'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, `${user?.name ?? 'Administrador'}',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Acompanhe e organize a operação da academia.',
              style: TextStyle(
                fontSize: 17,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 28),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _AdminCard(
                  title: 'Usuários',
                  subtitle: 'Cadastros e permissões',
                  icon: Icons.manage_accounts,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UsersScreen(),
                      ),
                    );
                  },
                ),
                const _AdminCard(
                  title: 'Alunos',
                  subtitle: 'Dados e vínculos esportivos',
                  icon: Icons.groups,
                ),
                const _AdminCard(
                  title: 'Professores',
                  subtitle: 'Equipe e permissões',
                  icon: Icons.school,
                ),
                const _AdminCard(
                  title: 'Turmas',
                  subtitle: 'Horários e organização',
                  icon: Icons.calendar_month,
                ),
                const _AdminCard(
                  title: 'Financeiro',
                  subtitle: 'Planos e pagamentos',
                  icon: Icons.payments_outlined,
                ),
                const _AdminCard(
                  title: 'Graduações',
                  subtitle: 'Aptos e progressão',
                  icon: Icons.sports_martial_arts,
                ),
                const _AdminCard(
                  title: 'Relatórios',
                  subtitle: 'Presenças e indicadores',
                  icon: Icons.bar_chart,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 38,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
"@

Write-Utf8File `
    -Path $adminFile `
    -Content $adminContent

# --------------------------------------------------
# 9. Formatação e testes
# --------------------------------------------------

Write-Host ""
Write-Host "9. Formatando arquivos..."

dart format lib test

if ($LASTEXITCODE -ne 0) {
    throw "dart format falhou."
}

Write-Host ""
Write-Host "10. Executando flutter analyze..."

flutter analyze

if ($LASTEXITCODE -ne 0) {
    throw "flutter analyze encontrou problemas."
}

Write-Host ""
Write-Host "11. Executando flutter test..."

flutter test

if ($LASTEXITCODE -ne 0) {
    throw "flutter test encontrou problemas."
}

Write-Host ""
Write-Host "=========================================="
Write-Host "FEATURE USERS CRIADA COM SUCESSO"
Write-Host "=========================================="
Write-Host ""
Write-Host "Backup:"
Write-Host $backupRoot
Write-Host ""
Write-Host "Agora execute:"
Write-Host "flutter run -d chrome"