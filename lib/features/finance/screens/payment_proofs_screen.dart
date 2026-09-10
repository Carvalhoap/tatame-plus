import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../models/payment_proof.dart';
import '../repository/finance_repository.dart';
import 'payment_proof_review_screen.dart';

class PaymentProofsScreen extends StatefulWidget {
  const PaymentProofsScreen({super.key});

  @override
  State<PaymentProofsScreen> createState() => _PaymentProofsScreenState();
}

class _PaymentProofsScreenState extends State<PaymentProofsScreen> {
  late FinancePeriod period;
  PaymentProofStatus? statusFilter = PaymentProofStatus.pending;
  Future<_PaymentProofsData>? dataFuture;

  @override
  void initState() {
    super.initState();
    period = FinancePeriod.containing(DateTime.now());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dataFuture ??= _loadData();
  }

  Future<_PaymentProofsData> _loadData() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final results = await Future.wait<Object>([
      context.read<StudentRepository>().getStudentsByAcademy(
        currentUser.academyId,
      ),
      context.read<FinanceRepository>().getPaymentProofs(
        academyId: currentUser.academyId,
        period: period,
        status: statusFilter,
      ),
    ]);

    final students = results[0] as List<Student>;
    final proofs = results[1] as List<PaymentProof>;

    return _PaymentProofsData(
      studentsById: {for (final student in students) student.id: student},
      proofs: proofs,
    );
  }

  Future<void> reload() async {
    final nextFuture = _loadData();

    setState(() {
      dataFuture = nextFuture;
    });

    await nextFuture;
  }

  void movePeriod(int months) {
    final nextStart = DateTime(
      period.referenceYear,
      period.referenceMonth + months,
      15,
    );

    setState(() {
      period = FinancePeriod.fromReference(
        year: nextStart.year,
        month: nextStart.month,
      );
      dataFuture = _loadData();
    });
  }

  void changeFilter(PaymentProofStatus? status) {
    setState(() {
      statusFilter = status;
      dataFuture = _loadData();
    });
  }

  Future<void> openProof({
    required PaymentProof proof,
    required String studentName,
  }) async {
    final reviewed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaymentProofReviewScreen(proof: proof, studentName: studentName),
      ),
    );

    if (reviewed != true || !mounted) {
      return;
    }

    await reload();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comprovante analisado com sucesso.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Comprovantes'),
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
      body: FutureBuilder<_PaymentProofsData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: reload);
          }

          final data = snapshot.data;

          if (data == null) {
            return _ErrorState(
              error: StateError('Os comprovantes não foram carregados.'),
              onRetry: reload,
            );
          }

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _PeriodSelector(
                  period: period,
                  onPrevious: () => movePeriod(-1),
                  onNext: () => movePeriod(1),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Filtrar por situação',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Pendentes'),
                      selected: statusFilter == PaymentProofStatus.pending,
                      onSelected: (_) {
                        changeFilter(PaymentProofStatus.pending);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Aprovados'),
                      selected: statusFilter == PaymentProofStatus.approved,
                      onSelected: (_) {
                        changeFilter(PaymentProofStatus.approved);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Rejeitados'),
                      selected: statusFilter == PaymentProofStatus.rejected,
                      onSelected: (_) {
                        changeFilter(PaymentProofStatus.rejected);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: statusFilter == null,
                      onSelected: (_) {
                        changeFilter(null);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${data.proofs.length} comprovante'
                  '${data.proofs.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (data.proofs.isEmpty)
                  _EmptyState(status: statusFilter)
                else
                  ...data.proofs.map((proof) {
                    final studentName =
                        data.studentsById[proof.studentId]?.fullName ??
                        proof.studentId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProofCard(
                        proof: proof,
                        studentName: studentName,
                        onTap: () =>
                            openProof(proof: proof, studentName: studentName),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentProofsData {
  final Map<String, Student> studentsById;
  final List<PaymentProof> proofs;

  const _PaymentProofsData({required this.studentsById, required this.proofs});
}

class _PeriodSelector extends StatelessWidget {
  final FinancePeriod period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodSelector({
    required this.period,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  const Text(
                    'Período financeiro',
                    style: TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_date(period.start)} até '
                    '${_date(period.displayEnd)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _ProofCard extends StatelessWidget {
  final PaymentProof proof;
  final String studentName;
  final VoidCallback onTap;

  const _ProofCard({
    required this.proof,
    required this.studentName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(proof.status);

    return Card(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.12),
                foregroundColor: statusColor,
                child: Icon(
                  proof.isGympassCheckIn
                      ? Icons.qr_code_scanner
                      : Icons.receipt_outlined,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      proof.isGympassCheckIn
                          ? 'Check-in Gympass'
                          : 'Mensalidade • '
                                '${_paymentMethodLabel(proof.paymentMethod)}',
                      style: const TextStyle(color: AppColors.grey),
                    ),
                    const SizedBox(height: 5),
                    Text('Referência: ${_date(proof.referenceDate)}'),
                    const SizedBox(height: 8),
                    _StatusBadge(
                      label: _statusLabel(proof.status),
                      color: statusColor,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final PaymentProofStatus? status;

  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    final message = status == PaymentProofStatus.pending
        ? 'Não há comprovantes aguardando análise.'
        : 'Nenhum comprovante foi encontrado neste filtro.';

    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 54, color: AppColors.grey),
            const SizedBox(height: 12),
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
              'Não foi possível carregar os comprovantes.',
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

String _date(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _paymentMethodLabel(PaymentMethod? method) {
  switch (method) {
    case PaymentMethod.pix:
      return 'Pix';
    case PaymentMethod.cash:
      return 'Dinheiro';
    case PaymentMethod.card:
      return 'Cartão';
    case PaymentMethod.bankTransfer:
      return 'Transferência';
    case PaymentMethod.gympass:
      return 'Gympass';
    case PaymentMethod.other:
      return 'Outro';
    case null:
      return 'Não informado';
  }
}

String _statusLabel(PaymentProofStatus status) {
  switch (status) {
    case PaymentProofStatus.pending:
      return 'Aguardando análise';
    case PaymentProofStatus.approved:
      return 'Aprovado';
    case PaymentProofStatus.rejected:
      return 'Rejeitado';
  }
}

Color _statusColor(PaymentProofStatus status) {
  switch (status) {
    case PaymentProofStatus.pending:
      return Colors.orange;
    case PaymentProofStatus.approved:
      return Colors.green;
    case PaymentProofStatus.rejected:
      return AppColors.gracieRed;
  }
}
