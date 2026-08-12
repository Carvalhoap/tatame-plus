import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../auth/services/session_service.dart';
import '../../class_occurrence/screens/class_occurrences_screen.dart';
import '../../classroom/screens/classrooms_screen.dart';
import '../../training_type/screens/training_types_screen.dart';
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
              style: TextStyle(fontSize: 17, color: AppColors.grey),
            ),
            const SizedBox(height: 28),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _AdminCard(
                  title: 'Usuários',
                  subtitle: 'Cadastros e permissões',
                  icon: Icons.manage_accounts,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsersScreen()),
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
                _AdminCard(
                  title: 'Turmas',
                  subtitle: 'Horários e organização',
                  icon: Icons.calendar_month,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ClassroomsScreen(),
                      ),
                    );
                  },
                ),
                _AdminCard(
                  title: 'Tipos de Treino',
                  subtitle: 'Gi, No-Gi e modalidades',
                  icon: Icons.category_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrainingTypesScreen(),
                      ),
                    );
                  },
                ),
                _AdminCard(
                  title: 'Agenda / Exceções',
                  subtitle: 'Substituições, cancelamentos e treinos extras',
                  icon: Icons.event_note,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ClassOccurrencesScreen(),
                      ),
                    );
                  },
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
              Icon(icon, size: 38, color: AppColors.brandPrimary),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.grey,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
