import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../attendance/repository/check_in_session_repository.dart';
import '../../auth/services/session_service.dart';
import '../models/student.dart';
import '../repository/student_repository.dart';

class StudentQrScannerScreen extends StatefulWidget {
  final Student? student;

  const StudentQrScannerScreen({super.key, this.student});

  @override
  State<StudentQrScannerScreen> createState() => _StudentQrScannerScreenState();
}

class _StudentQrScannerScreenState extends State<StudentQrScannerScreen> {
  final MobileScannerController scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool isProcessing = false;
  bool torchEnabled = false;

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  Future<bool> _confirmGuardianCheckIn(Student student) async {
    if (!mounted) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.family_restroom,
            size: 56,
            color: AppColors.brandPrimary,
          ),
          title: const Text('Confirmar aluno', textAlign: TextAlign.center),
          content: Text(
            'Registrar a presença de ${student.fullName}?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar presença'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  Future<void> handleDetection(BarcodeCapture capture) async {
    if (isProcessing || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;

    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    isProcessing = true;

    final currentUser = context.read<SessionService>().currentUser;

    final studentRepository = context.read<StudentRepository>();

    final checkInRepository = context.read<CheckInSessionRepository>();

    await scannerController.stop();

    try {
      final sessionId = rawValue.trim();

      if (sessionId.isEmpty) {
        throw const FormatException('Sess\u00E3o inv\u00E1lida.');
      }
      if (currentUser == null) {
        throw StateError(
          'Sua sess\u00E3o no Tatame+ n\u00E3o est\u00E1 dispon\u00EDvel.',
        );
      }

      final student =
          widget.student ??
          await studentRepository.getStudentByUserId(
            academyId: currentUser.academyId,
            userId: currentUser.id,
          );

      if (student == null) {
        throw StateError('Nenhum aluno está vinculado a este usuário.');
      }

      if (widget.student != null &&
          !student.guardianIds.contains(currentUser.id)) {
        throw StateError(
          'Este aluno não está vinculado à sua conta de responsável.',
        );
      }

      final session = await checkInRepository.findSessionById(
        academyId: currentUser.academyId,
        sessionId: sessionId,
      );

      if (session == null) {
        throw const FormatException('Sess\u00E3o n\u00E3o encontrada.');
      }

      if (session.academyId != currentUser.academyId) {
        throw const FormatException(
          'Esta sess\u00E3o pertence a outra academia.',
        );
      }

      if (!session.isActive) {
        throw StateError(
          'Esta sess\u00E3o de check-in n\u00E3o est\u00E1 mais ativa.',
        );
      }

      if (!student.isActive) {
        throw StateError('Este aluno não está ativo na academia.');
      }

      if (!student.classroomIds.contains(session.classroomId)) {
        throw StateError(
          'Este aluno não pertence à turma desta chamada. Volte e selecione o aluno correto.',
        );
      }

      if (widget.student != null) {
        final confirmed = await _confirmGuardianCheckIn(student);

        if (!confirmed) {
          isProcessing = false;

          if (mounted) {
            await scannerController.start();
          }

          return;
        }
      }

      final alreadyCheckedIn = await checkInRepository.isStudentCheckedIn(
        academyId: currentUser.academyId,
        sessionId: sessionId,
        studentId: student.id,
      );

      if (alreadyCheckedIn) {
        throw StateError('Sua presença já foi registrada nesta aula.');
      }

      final attendance = await checkInRepository.registerAttendance(
        academyId: currentUser.academyId,
        sessionId: sessionId,
        studentId: student.id,
      );

      if (attendance == null) {
        throw StateError(
          'N\u00E3o foi poss\u00EDvel registrar sua presen\u00E7a.',
        );
      }

      await showResultDialog(
        success: true,
        title: 'Presença registrada!',
        message: 'Seu check-in foi realizado com sucesso.',
      );
    } on FormatException {
      await showResultDialog(
        success: false,
        title: 'QR Code inválido',
        message:
            'Este c\u00F3digo n\u00E3o pertence a uma sess\u00E3o v\u00E1lida do Tatame+.',
      );
    } on StateError catch (error) {
      await showResultDialog(
        success: false,
        title: 'Check-in n\u00E3o realizado',
        message: error.message.toString(),
      );
    } catch (_) {
      await showResultDialog(
        success: false,
        title: 'N\u00E3o foi poss\u00EDvel registrar',
        message: 'Ocorreu um problema ao realizar o check-in. Tente novamente.',
      );
    }
  }

  Future<void> showResultDialog({
    required bool success,
    required String title,
    required String message,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            success ? Icons.check_circle : Icons.error_outline,
            size: 64,
            color: success ? AppColors.success : AppColors.gracieRed,
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                if (success) {
                  Navigator.pop(context, true);
                } else {
                  restartScanner();
                }
              },
              child: Text(success ? 'Continuar' : 'Tentar novamente'),
            ),
          ],
        );
      },
    );
  }

  Future<void> restartScanner() async {
    isProcessing = false;
    await scannerController.start();
  }

  Future<void> toggleTorch() async {
    await scannerController.toggleTorch();

    if (!mounted) return;

    setState(() {
      torchEnabled = !torchEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Registrar presença'),
        backgroundColor: Colors.black,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            tooltip: 'Lanterna',
            onPressed: toggleTorch,
            icon: Icon(torchEnabled ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: handleDetection,
            errorBuilder: (context, error) {
              return _ScannerError(
                message:
                    'N\u00E3o foi poss\u00EDvel abrir a c\u00E2mera.\nVerifique a permiss\u00E3o do aplicativo.',
                onRetry: restartScanner,
              );
            },
          ),

          const _ScannerOverlay(),

          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.white, size: 34),
                  SizedBox(height: 10),
                  Text(
                    'Posicione o QR Code da turma dentro da área destacada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 270,
          height: 270,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.white, width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ScannerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: AppColors.gracieRed,
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
