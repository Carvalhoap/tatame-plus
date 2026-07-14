import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionService>();
    final user = session.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestão'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        actions: [
          IconButton(
            tooltip: 'Trocar perfil',
            onPressed: session.clearActiveRole,
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: session.endSession,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, ${user?.name ?? 'Administrador'}',
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
              children: const [
                _AdminCard(
                  title: 'Alunos',
                  subtitle: 'Cadastros e vínculos',
                  icon: Icons.groups,
                ),
                _AdminCard(
                  title: 'Professores',
                  subtitle: 'Equipe e permissões',
                  icon: Icons.school,
                ),
                _AdminCard(
                  title: 'Turmas',
                  subtitle: 'Horários e organização',
                  icon: Icons.calendar_month,
                ),
                _AdminCard(
                  title: 'Financeiro',
                  subtitle: 'Planos e pagamentos',
                  icon: Icons.payments_outlined,
                ),
                _AdminCard(
                  title: 'Graduações',
                  subtitle: 'Aptos e progressão',
                  icon: Icons.sports_martial_arts,
                ),
                _AdminCard(
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

  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: () {},
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