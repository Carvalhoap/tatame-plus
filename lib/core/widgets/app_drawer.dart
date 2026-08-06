import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/services/session_service.dart';
import '../enums/user_role.dart';
import '../theme/app_colors.dart';
import '../../features/auth/repository/auth_repository.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.currentUser;
    final activeRole = session.activeRole;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: AppColors.brandPrimary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.white,
                    child: Text(
                      _initials(user.name),
                      style: const TextStyle(
                        color: AppColors.brandPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Acesso atual: ${_roleTitle(activeRole)}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Text(
                      'ÁREAS DE ACESSO',
                      style: TextStyle(
                        color: AppColors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  ...user.roles.map(
                    (role) => ListTile(
                      selected: activeRole == role,
                      selectedTileColor:
                          AppColors.brandPrimary.withValues(alpha: 0.08),
                      leading: Icon(
                        _roleIcon(role),
                        color: activeRole == role
                            ? AppColors.brandPrimary
                            : AppColors.grey,
                      ),
                      title: Text(
                        _roleTitle(role),
                        style: TextStyle(
                          fontWeight: activeRole == role
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: activeRole == role
                              ? AppColors.brandPrimary
                              : null,
                        ),
                      ),
                      trailing: activeRole == role
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);

                        if (activeRole != role) {
                          session.changeActiveRole(role);
                        }
                      },
                    ),
                  ),

                  const Divider(height: 32),

                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: AppColors.grey,
                    ),
                    title: const Text('Sobre o Tatame+'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/about');
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.gracieRed,
              ),
              title: const Text(
                'Sair',
                style: TextStyle(
                  color: AppColors.gracieRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);

                await context.read<AuthRepository>().logout();

                if (!context.mounted) return;

                session.endSession();
              },
            ),

            const SizedBox(height: 8),
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

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _roleTitle(UserRole? role) {
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

      case null:
        return 'Não selecionado';
    }
  }

  static IconData _roleIcon(UserRole role) {
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