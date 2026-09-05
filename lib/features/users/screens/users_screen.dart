import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/repository/auth_repository.dart';
import '../../auth/services/session_service.dart';
import '../models/academy_member.dart';
import '../repository/user_repository.dart';
import 'create_user_screen.dart';
import 'edit_user_screen.dart';

class UsersScreen extends StatefulWidget {
  final UserRole? roleFilter;
  final String title;

  const UsersScreen({super.key, this.roleFilter, this.title = 'Usuários'});

  const UsersScreen.teachers({super.key})
    : roleFilter = UserRole.teacher,
      title = 'Professores';

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

  Future<void> openCreateUser() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );

    if (!mounted) {
      return;
    }

    if (created == true) {
      reload();
    }
  }

  Future<void> openEditUser(AcademyMember member) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditUserScreen(member: member)),
    );

    if (!mounted) {
      return;
    }

    if (updated == true) {
      reload();
    }
  }

  Future<void> sendPasswordReset(AcademyMember member) async {
    if (member.email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este usuário não possui e-mail cadastrado.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Redefinir senha'),
        content: Text('Enviar um link de redefinição para ${member.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await context.read<AuthRepository>().sendPasswordResetEmail(
        email: member.email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link de redefinição enviado para ${member.email}.'),
          backgroundColor: AppColors.success,
        ),
      );
    } on PasswordManagementException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.gracieRed,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar a redefinição de senha.'),
          backgroundColor: AppColors.gracieRed,
        ),
      );
    }
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
        title: Text(widget.title),
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
        onPressed: openCreateUser,
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          widget.roleFilter == UserRole.teacher
              ? 'Novo professor'
              : 'Novo usuário',
        ),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(error: snapshot.error, onRetry: reload);
                  }

                  final members = snapshot.data ?? const [];

                  final filteredMembers = members
                      .where((member) {
                        final roleFilter = widget.roleFilter;

                        if (roleFilter != null &&
                            !member.hasRole(roleFilter.name)) {
                          return false;
                        }

                        if (searchTerm.isEmpty) {
                          return true;
                        }

                        return member.displayName.toLowerCase().contains(
                              searchTerm,
                            ) ||
                            member.email.toLowerCase().contains(searchTerm);
                      })
                      .toList(growable: false);

                  if (members.isEmpty) {
                    return const _EmptyState(
                      title: 'Nenhum usuário encontrado',
                      message:
                          'Os usuários vinculados à academia aparecerão aqui.',
                    );
                  }

                  if (filteredMembers.isEmpty) {
                    final showingTeachers =
                        widget.roleFilter == UserRole.teacher;

                    return _EmptyState(
                      title: showingTeachers && searchTerm.isEmpty
                          ? 'Nenhum professor encontrado'
                          : 'Nenhum resultado',
                      message: showingTeachers && searchTerm.isEmpty
                          ? 'Os professores cadastrados aparecerão aqui.'
                          : 'Tente pesquisar usando outro nome ou e-mail.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      reload();
                      await membersFuture;
                    },
                    child: ListView.separated(
                      itemCount: filteredMembers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];

                        return _MemberCard(
                          member: member,
                          onTap: () => openEditUser(member),
                          onSendPasswordReset: () => sendPasswordReset(member),
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
  final VoidCallback onTap;
  final VoidCallback onSendPasswordReset;

  const _MemberCard({
    required this.member,
    required this.onTap,
    required this.onSendPasswordReset,
  });

  @override
  Widget build(BuildContext context) {
    final roles = member.activeRoles.map(_roleLabel).join(' • ');

    final isUserActive = member.isActive && member.status == 'active';

    return Card(
      color: AppColors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.white,
          child: Text(
            _initials(member.displayName),
            style: const TextStyle(fontWeight: FontWeight.bold),
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
            Text(roles.isEmpty ? 'Sem perfil autorizado' : roles),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: isUserActive ? 'Usuário ativo' : 'Usuário inativo',
              child: Icon(
                isUserActive ? Icons.check_circle : Icons.cancel,
                color: isUserActive ? AppColors.success : AppColors.gracieRed,
              ),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: 'Ações do usuário',
              icon: const Icon(Icons.more_vert, color: AppColors.brandPrimary),
              onSelected: (value) {
                if (value == 'resetPassword') {
                  onSendPasswordReset();
                  return;
                }

                if (value == 'edit') {
                  onTap();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editar usuário'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'resetPassword',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.lock_reset),
                    title: Text('Enviar redefinição de senha'),
                  ),
                ),
              ],
            ),
          ],
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

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
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

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined, size: 64, color: AppColors.grey),
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
              style: const TextStyle(color: AppColors.grey),
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

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    String message = 'Não foi possível carregar os usuários.';

    if (error is FirebaseException &&
        (error as FirebaseException).code == 'permission-denied') {
      message = 'Você não possui permissão para visualizar os usuários.';
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
              style: const TextStyle(color: AppColors.grey),
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
