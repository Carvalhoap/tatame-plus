import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../services/session_service.dart';
import '../repository/auth_repository.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Escolha seu acesso'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
  await context.read<AuthRepository>().logout();

  if (!context.mounted) return;

  session.endSession();
},
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Olá, ${user.name}!',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Como você deseja acessar o Tatame+ agora?',
                  style: TextStyle(
                    fontSize: 17,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 28),
                ...user.roles.map(
                  (role) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _RoleCard(
                      role: role,
                      onTap: () {
                        session.changeActiveRole(role);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.onTap,
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
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.brandPrimary,
                child: Icon(
                  _roleIcon(role),
                  color: AppColors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _roleTitle(role),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roleDescription(role),
                      style: const TextStyle(
                        color: AppColors.grey,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleTitle(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Gestão — Administrador';
      case UserRole.partner:
        return 'Gestão — Sócio';
      case UserRole.teacher:
        return 'Professor';
      case UserRole.student:
        return 'Meu Dojo';
      case UserRole.guardian:
        return 'Responsável';
    }
  }

  String _roleDescription(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Acesso completo à gestão da academia.';
      case UserRole.partner:
        return 'Gestão, relatórios e informações administrativas.';
      case UserRole.teacher:
        return 'Turmas, chamadas e evolução dos alunos.';
      case UserRole.student:
        return 'Sua jornada, graduação, mascote e check-in.';
      case UserRole.guardian:
        return 'Acompanhe os alunos vinculados à sua conta.';
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.partner:
        return Icons.business;
      case UserRole.teacher:
        return Icons.school;
      case UserRole.student:
        return Icons.sports_martial_arts;
      case UserRole.guardian:
        return Icons.family_restroom;
    }
  }
}