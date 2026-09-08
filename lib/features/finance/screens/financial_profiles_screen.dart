import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/finance_enums.dart';
import '../models/financial_profile.dart';
import '../repository/finance_repository.dart';
import 'financial_profile_form_screen.dart';

class FinancialProfilesScreen extends StatefulWidget {
  const FinancialProfilesScreen({super.key});

  @override
  State<FinancialProfilesScreen> createState() =>
      _FinancialProfilesScreenState();
}

class _FinancialProfilesScreenState extends State<FinancialProfilesScreen> {
  final searchController = TextEditingController();

  Future<_FinancialProfilesData>? dataFuture;
  String searchTerm = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dataFuture ??= _loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<_FinancialProfilesData> _loadData() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final results = await Future.wait<Object>([
      context.read<StudentRepository>().getStudentsByAcademy(
        currentUser.academyId,
      ),
      context.read<FinanceRepository>().getFinancialProfiles(
        academyId: currentUser.academyId,
      ),
    ]);

    final students = results[0] as List<Student>;
    final profiles = results[1] as List<FinancialProfile>;

    students.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.fullName.toLowerCase().compareTo(
        second.fullName.toLowerCase(),
      );
    });

    return _FinancialProfilesData(
      students: students,
      profilesByStudentId: {
        for (final profile in profiles) profile.studentId: profile,
      },
    );
  }

  Future<void> reload() async {
    final nextFuture = _loadData();

    setState(() {
      dataFuture = nextFuture;
    });

    await nextFuture;
  }

  Future<void> openProfile({
    required Student student,
    required FinancialProfile? profile,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FinancialProfileFormScreen(student: student, profile: profile),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Configuração financeira de ${student.fullName} salva.'),
      ),
    );

    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alunos e mensalidades'),
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar aluno',
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
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<_FinancialProfilesData>(
                future: dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(error: snapshot.error, onRetry: reload);
                  }

                  final data = snapshot.data;

                  if (data == null || data.students.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Nenhum aluno cadastrado',
                      message:
                          'Cadastre os alunos antes de configurar cobranças.',
                    );
                  }

                  final filteredStudents = data.students
                      .where((student) {
                        if (searchTerm.isEmpty) {
                          return true;
                        }

                        return student.fullName.toLowerCase().contains(
                              searchTerm,
                            ) ||
                            (student.email?.toLowerCase().contains(
                                  searchTerm,
                                ) ??
                                false);
                      })
                      .toList(growable: false);

                  if (filteredStudents.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.search_off,
                      title: 'Nenhum resultado',
                      message: 'Tente pesquisar usando outro nome.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: reload,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredStudents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        final profile = data.profilesByStudentId[student.id];

                        return _FinancialProfileCard(
                          student: student,
                          profile: profile,
                          onTap: () =>
                              openProfile(student: student, profile: profile),
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

class _FinancialProfilesData {
  final List<Student> students;
  final Map<String, FinancialProfile> profilesByStudentId;

  const _FinancialProfilesData({
    required this.students,
    required this.profilesByStudentId,
  });
}

class _FinancialProfileCard extends StatelessWidget {
  final Student student;
  final FinancialProfile? profile;
  final VoidCallback onTap;

  const _FinancialProfileCard({
    required this.student,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final configured = profile != null;

    return Card(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: configured
                    ? AppColors.brandPrimary
                    : Colors.orange,
                foregroundColor: AppColors.white,
                child: Icon(
                  configured
                      ? _billingModeIcon(profile!.billingMode)
                      : Icons.priority_high,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      configured
                          ? _profileDescription(profile!)
                          : 'Configuração financeira pendente',
                      style: TextStyle(
                        color: configured
                            ? AppColors.grey
                            : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusChip(
                          label: student.isActive
                              ? 'Aluno ativo'
                              : 'Aluno inativo',
                          color: student.isActive
                              ? Colors.green
                              : AppColors.grey,
                        ),
                        if (configured)
                          _StatusChip(
                            label: profile!.isActive
                                ? 'Cobrança ativa'
                                : 'Cobrança inativa',
                            color: profile!.isActive
                                ? AppColors.brandPrimary
                                : AppColors.grey,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.grey),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
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
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 54,
              color: AppColors.gracieRed,
            ),
            const SizedBox(height: 14),
            const Text(
              'Não foi possível carregar os alunos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
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

String _profileDescription(FinancialProfile profile) {
  switch (profile.billingMode) {
    case BillingMode.monthlyFee:
      return '${_currency(profile.monthlyFeeCents)} '
          '• vence dia ${profile.dueDay}';
    case BillingMode.gympass:
      return 'Gympass • fechamento de 15 a 14';
    case BillingMode.exempt:
      return 'Isento • sem cobrança mensal';
  }
}

IconData _billingModeIcon(BillingMode mode) {
  switch (mode) {
    case BillingMode.monthlyFee:
      return Icons.payments_outlined;
    case BillingMode.gympass:
      return Icons.qr_code_scanner_outlined;
    case BillingMode.exempt:
      return Icons.money_off_outlined;
  }
}

String _currency(int cents) {
  return 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';
}
