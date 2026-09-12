import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/check_in_provider.dart';
import '../repository/finance_repository.dart';
import 'check_in_provider_form_screen.dart';

class CheckInProvidersScreen extends StatefulWidget {
  const CheckInProvidersScreen({super.key});

  @override
  State<CheckInProvidersScreen> createState() => _CheckInProvidersScreenState();
}

class _CheckInProvidersScreenState extends State<CheckInProvidersScreen> {
  Future<List<CheckInProvider>>? providersFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    providersFuture ??= _loadProviders();
  }

  Future<List<CheckInProvider>> _loadProviders() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    return context.read<FinanceRepository>().getCheckInProviders(
      academyId: currentUser.academyId,
    );
  }

  Future<void> _reload() async {
    final nextFuture = _loadProviders();

    setState(() {
      providersFuture = nextFuture;
    });

    await nextFuture;
  }

  Future<void> _openProvider([CheckInProvider? provider]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckInProviderFormScreen(provider: provider),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    await _reload();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider == null ? 'Convênio cadastrado.' : 'Convênio atualizado.',
        ),
      ),
    );
  }

  String _currency(int cents) {
    final reais = cents ~/ 100;
    final decimal = (cents % 100).toString().padLeft(2, '0');

    return 'R\$ $reais,$decimal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Convênios de check-in'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reload,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProvider(),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo convênio'),
      ),
      body: FutureBuilder<List<CheckInProvider>>(
        future: providersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ProvidersError(error: snapshot.error, onRetry: _reload);
          }

          final providers = snapshot.data ?? const <CheckInProvider>[];

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.brandPrimary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cadastre serviços pagos por check-in. '
                            'Cada convênio pode ter valor, limite e regra '
                            'de divisão próprios.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (providers.isEmpty)
                  const _EmptyProviders()
                else
                  ...providers.map(
                    (provider) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProviderCard(
                        provider: provider,
                        currency: _currency,
                        onTap: () => _openProvider(provider),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final CheckInProvider provider;
  final String Function(int) currency;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.provider,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = provider.isActive
        ? Colors.green.shade700
        : Colors.grey.shade600;

    return Card(
      color: AppColors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: provider.isActive
                    ? Colors.green.shade50
                    : Colors.grey.shade200,
                child: Icon(Icons.qr_code_scanner_outlined, color: statusColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.name,
                            style: const TextStyle(
                              color: AppColors.brandPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _StatusChip(
                          text: provider.isActive ? 'Ativo' : 'Inativo',
                          color: statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currency(provider.checkInValueCents)} por check-in',
                    ),
                    const SizedBox(height: 3),
                    Text('Limite: ${provider.monthlyLimit} por aluno/período'),
                    const SizedBox(height: 3),
                    Text(
                      provider.sharesWithMoving
                          ? 'Compartilhado com a Moving'
                          : 'Receita integral da equipe',
                      style: TextStyle(
                        color: provider.sharesWithMoving
                            ? Colors.orange.shade800
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyProviders extends StatelessWidget {
  const _EmptyProviders();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_scanner_outlined,
              size: 44,
              color: AppColors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'Nenhum convênio cadastrado.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvidersError extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _ProvidersError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os convênios: $error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
