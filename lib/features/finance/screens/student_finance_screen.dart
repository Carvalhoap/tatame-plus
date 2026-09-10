import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/models/attendance.dart';
import '../../attendance/repository/attendance_repository.dart';
import '../../auth/services/session_service.dart';
import '../../student/models/student.dart';
import '../models/billing_cycle.dart';
import '../models/finance_enums.dart';
import '../models/finance_period.dart';
import '../models/financial_profile.dart';
import '../models/payment_proof.dart';
import '../repository/finance_repository.dart';

class StudentFinanceScreen extends StatefulWidget {
  final Student student;

  const StudentFinanceScreen({super.key, required this.student});

  @override
  State<StudentFinanceScreen> createState() => _StudentFinanceScreenState();
}

class _StudentFinanceScreenState extends State<StudentFinanceScreen> {
  final ImagePicker imagePicker = ImagePicker();

  late final FinancePeriod period;

  FinancialProfile? profile;
  BillingCycle? billingCycle;
  List<Attendance> attendances = const [];
  List<PaymentProof> proofs = const [];

  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    period = FinancePeriod.containing(DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sua sessão não está disponível.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final financeRepository = context.read<FinanceRepository>();
      final attendanceRepository = context.read<AttendanceRepository>();

      final results = await Future.wait<Object?>([
        financeRepository.getFinancialProfile(
          academyId: currentUser.academyId,
          studentId: widget.student.id,
        ),
        financeRepository.getBillingCycles(
          academyId: currentUser.academyId,
          period: period,
          studentId: widget.student.id,
        ),
        financeRepository.getPaymentProofs(
          academyId: currentUser.academyId,
          period: period,
          studentId: widget.student.id,
        ),
        attendanceRepository.getAttendancesByStudent(
          academyId: currentUser.academyId,
          studentId: widget.student.id,
          start: period.start,
          end: period.endExclusive,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final loadedCycles = results[1] as List<BillingCycle>;

      setState(() {
        profile = results[0] as FinancialProfile?;
        billingCycle = loadedCycles.isEmpty ? null : loadedCycles.first;
        proofs = results[2] as List<PaymentProof>;
        attendances = results[3] as List<Attendance>;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar os pagamentos: $error';
      });
    }
  }

  PaymentProof? _proofForAttendance(String attendanceId) {
    for (final proof in proofs) {
      if (proof.type == PaymentProofType.gympassCheckIn &&
          proof.attendanceId == attendanceId) {
        return proof;
      }
    }

    return null;
  }

  PaymentProof? get _monthlyProof {
    final cycle = billingCycle;

    if (cycle == null) {
      return null;
    }

    for (final proof in proofs) {
      if (proof.type == PaymentProofType.monthlyFee &&
          proof.billingCycleId == cycle.id) {
        return proof;
      }
    }

    return null;
  }

  Future<ImageSource?> _selectImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Tirar foto'),
                onTap: () {
                  Navigator.pop(bottomSheetContext, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () {
                  Navigator.pop(bottomSheetContext, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<PaymentMethod?> _selectPaymentMethod() {
    return showDialog<PaymentMethod>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Forma de pagamento'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, PaymentMethod.pix),
              child: const Text('Pix'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, PaymentMethod.card),
              child: const Text('Cartão'),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(dialogContext, PaymentMethod.bankTransfer),
              child: const Text('Transferência bancária'),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(dialogContext, PaymentMethod.other),
              child: const Text('Outra forma'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitProof({Attendance? attendance}) async {
    if (isSubmitting) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;
    final financeRepository = context.read<FinanceRepository>();
    final cycle = billingCycle;
    final isGympass = attendance != null;
    final existingProof = attendance == null
        ? _monthlyProof
        : _proofForAttendance(attendance.id);

    if (currentUser == null) {
      return;
    }

    if (!isGympass && cycle == null) {
      _showMessage('A cobrança deste período ainda não foi gerada.');
      return;
    }

    final paymentMethod = isGympass
        ? PaymentMethod.gympass
        : await _selectPaymentMethod();

    if (paymentMethod == null || !mounted) {
      return;
    }

    final source = await _selectImageSource();

    if (source == null || !mounted) {
      return;
    }

    final image = await imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2000,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final fileName = image.name;
      final normalizedName = fileName.toLowerCase();

      final contentType = normalizedName.endsWith('.png')
          ? 'image/png'
          : normalizedName.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';

      await financeRepository.submitPaymentProof(
        academyId: currentUser.academyId,
        studentId: widget.student.id,
        submittedBy: currentUser.id,
        type: isGympass
            ? PaymentProofType.gympassCheckIn
            : PaymentProofType.monthlyFee,
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        paymentMethod: paymentMethod,
        referenceDate: attendance?.dateTime ?? DateTime.now(),
        billingCycleId: isGympass ? null : cycle!.id,
        attendanceId: attendance?.id,
        previousStoragePath: existingProof?.storagePath,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Comprovante enviado para análise.');
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Não foi possível enviar o comprovante: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _date(DateTime value, {bool includeTime = false}) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    if (!includeTime) {
      return '$day/$month/$year';
    }

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/$year às $hour:$minute';
  }

  String _money(int cents) {
    final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $value';
  }

  String _proofStatus(PaymentProof proof) {
    switch (proof.status) {
      case PaymentProofStatus.pending:
        return 'Aguardando análise';
      case PaymentProofStatus.approved:
        return 'Aprovado';
      case PaymentProofStatus.rejected:
        return 'Rejeitado: ${proof.rejectionReason ?? 'sem motivo informado'}';
    }
  }

  Color _proofColor(PaymentProof proof) {
    switch (proof.status) {
      case PaymentProofStatus.pending:
        return Colors.orange;
      case PaymentProofStatus.approved:
        return Colors.green;
      case PaymentProofStatus.rejected:
        return Colors.red;
    }
  }

  Widget _proofButton({
    required PaymentProof? proof,
    required VoidCallback onPressed,
  }) {
    if (proof?.isApproved == true) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    if (proof?.isPending == true) {
      return const Icon(Icons.hourglass_top, color: Colors.orange);
    }

    return OutlinedButton(
      onPressed: isSubmitting ? null : onPressed,
      child: Text(proof?.isRejected == true ? 'Reenviar' : 'Anexar'),
    );
  }

  Widget _monthlySection() {
    final cycle = billingCycle;
    final proof = _monthlyProof;

    if (cycle == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Cobrança ainda não gerada'),
          subtitle: Text(
            'A administração precisa gerar a mensalidade deste período.',
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mensalidade',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Valor: ${_money(cycle.expectedAmountCents)}'),
            Text('Vencimento: ${_date(cycle.dueDate)}'),
            if (cycle.isPaid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Pagamento confirmado',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (proof != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _proofStatus(proof),
                  style: TextStyle(
                    color: _proofColor(proof),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (!cycle.isPaid)
              Align(
                alignment: Alignment.centerRight,
                child: _proofButton(
                  proof: proof,
                  onPressed: () => _submitProof(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _gympassSection() {
    if (attendances.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.qr_code),
          title: Text('Nenhuma presença no período'),
          subtitle: Text(
            'Após registrar uma presença, anexe o check-in do Gympass aqui.',
          ),
        ),
      );
    }

    return Column(
      children: attendances.reversed.map((attendance) {
        final proof = _proofForAttendance(attendance.id);

        return Card(
          child: ListTile(
            leading: Icon(
              proof?.isApproved == true
                  ? Icons.check_circle
                  : Icons.fitness_center,
              color: proof?.isApproved == true
                  ? Colors.green
                  : AppColors.brandPrimary,
            ),
            title: Text(_date(attendance.dateTime, includeTime: true)),
            subtitle: proof == null
                ? const Text('Comprovante Gympass não enviado')
                : Text(
                    _proofStatus(proof),
                    style: TextStyle(color: _proofColor(proof)),
                  ),
            trailing: _proofButton(
              proof: proof,
              onPressed: () => _submitProof(attendance: attendance),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _content() {
    final currentProfile = profile;

    if (currentProfile == null || !currentProfile.isActive) {
      return const Center(
        child: Text(
          'O perfil financeiro deste aluno ainda não foi configurado.',
          textAlign: TextAlign.center,
        ),
      );
    }

    switch (currentProfile.billingMode) {
      case BillingMode.monthlyFee:
        return _monthlySection();
      case BillingMode.gympass:
        return _gympassSection();
      case BillingMode.exempt:
        return const Card(
          child: ListTile(
            leading: Icon(Icons.volunteer_activism_outlined),
            title: Text('Aluno isento'),
            subtitle: Text('Não existe pagamento pendente para este período.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pagamentos e comprovantes'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        actions: [
          IconButton(
            onPressed: isLoading ? null : _load,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(errorMessage!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    widget.student.fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Período: ${_date(period.start)} a '
                    '${_date(period.displayEnd)}',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 18),
                  if (isSubmitting) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  _content(),
                ],
              ),
            ),
    );
  }
}
