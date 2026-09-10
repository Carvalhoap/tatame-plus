import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/finance_enums.dart';
import '../models/payment_proof.dart';
import '../repository/finance_repository.dart';

class PaymentProofReviewScreen extends StatefulWidget {
  final PaymentProof proof;
  final String studentName;

  const PaymentProofReviewScreen({
    super.key,
    required this.proof,
    required this.studentName,
  });

  @override
  State<PaymentProofReviewScreen> createState() =>
      _PaymentProofReviewScreenState();
}

class _PaymentProofReviewScreenState extends State<PaymentProofReviewScreen> {
  Future<String>? downloadUrlFuture;
  bool isReviewing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    downloadUrlFuture ??= context
        .read<FinanceRepository>()
        .getPaymentProofDownloadUrl(storagePath: widget.proof.storagePath);
  }

  Future<void> approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Aprovar comprovante?'),
          content: Text(
            widget.proof.isGympassCheckIn
                ? 'Este check-in Gympass será incluído na receita.'
                : 'A cobrança vinculada será marcada como paga.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Aprovar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await review(status: PaymentProofStatus.approved);
  }

  Future<void> reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectionReasonDialog(),
    );

    if (reason == null || !mounted) {
      return;
    }

    await review(status: PaymentProofStatus.rejected, rejectionReason: reason);
  }

  Future<void> review({
    required PaymentProofStatus status,
    String? rejectionReason,
  }) async {
    if (isReviewing) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    final repository = context.read<FinanceRepository>();

    setState(() {
      isReviewing = true;
    });

    try {
      await repository.reviewPaymentProof(
        academyId: currentUser.academyId,
        proofId: widget.proof.id,
        status: status,
        reviewedBy: currentUser.id,
        rejectionReason: rejectionReason,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isReviewing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível analisar o comprovante: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final proof = widget.proof;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analisar comprovante'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: proof.isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isReviewing ? null : reject,
                        icon: const Icon(Icons.close),
                        label: const Text('Rejeitar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gracieRed,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isReviewing ? null : approve,
                        icon: isReviewing
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(isReviewing ? 'Salvando...' : 'Aprovar'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            color: AppColors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InformationRow(label: 'Aluno', value: widget.studentName),
                  const Divider(height: 22),
                  _InformationRow(
                    label: 'Tipo',
                    value: proof.isGympassCheckIn
                        ? 'Check-in Gympass'
                        : 'Mensalidade',
                  ),
                  const Divider(height: 22),
                  _InformationRow(
                    label: 'Data de referência',
                    value: _date(proof.referenceDate),
                  ),
                  const Divider(height: 22),
                  _InformationRow(
                    label: 'Forma de pagamento',
                    value: _paymentMethodLabel(proof.paymentMethod),
                  ),
                  const Divider(height: 22),
                  _InformationRow(
                    label: 'Situação',
                    value: _statusLabel(proof.status),
                    valueColor: _statusColor(proof.status),
                  ),
                  if (proof.rejectionReason != null) ...[
                    const Divider(height: 22),
                    _InformationRow(
                      label: 'Motivo da rejeição',
                      value: proof.rejectionReason!,
                      valueColor: AppColors.gracieRed,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Imagem enviada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<String>(
            future: downloadUrlFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || snapshot.data == null) {
                return _ImageError(
                  onRetry: () {
                    setState(() {
                      downloadUrlFuture = context
                          .read<FinanceRepository>()
                          .getPaymentProofDownloadUrl(
                            storagePath: proof.storagePath,
                          );
                    });
                  },
                );
              }

              return Container(
                constraints: const BoxConstraints(minHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Image.network(
                    snapshot.data!,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }

                      return const SizedBox(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, _, _) {
                      return const SizedBox(
                        height: 300,
                        child: Center(
                          child: Text('Não foi possível exibir a imagem.'),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InformationRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(label, style: const TextStyle(color: AppColors.grey)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ),
      ],
    );
  }
}

class _ImageError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ImageError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.broken_image_outlined,
              size: 52,
              color: AppColors.grey,
            ),
            const SizedBox(height: 10),
            const Text('Não foi possível carregar a imagem.'),
            const SizedBox(height: 12),
            TextButton.icon(
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

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog();

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rejeitar comprovante'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: reasonController,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motivo da rejeição',
            hintText: 'Explique o que precisa ser corrigido.',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o motivo da rejeição.';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) {
              return;
            }

            Navigator.pop(context, reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.gracieRed),
          child: const Text('Confirmar rejeição'),
        ),
      ],
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
