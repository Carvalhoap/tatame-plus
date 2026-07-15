import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

class StudentQrScannerScreen extends StatefulWidget {
  const StudentQrScannerScreen({super.key});

  @override
  State<StudentQrScannerScreen> createState() =>
      _StudentQrScannerScreenState();
}

class _StudentQrScannerScreenState extends State<StudentQrScannerScreen> {
 final MobileScannerController scannerController =
    MobileScannerController(
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

  Future<void> handleDetection(BarcodeCapture capture) async {
    if (isProcessing || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;

    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    isProcessing = true;
    await scannerController.stop();

    try {
      final decodedData = jsonDecode(rawValue);

      if (decodedData is! Map<String, dynamic>) {
        throw const FormatException('Formato inválido.');
      }

      final sessionId = decodedData['sessionId'] as String?;
      final academyId = decodedData['academyId'] as String?;
      final classroomId = decodedData['classroomId'] as String?;
      final teacherId = decodedData['teacherId'] as String?;
      final expiresAtText = decodedData['expiresAt'] as String?;

      if (sessionId == null ||
          academyId == null ||
          classroomId == null ||
          teacherId == null ||
          expiresAtText == null) {
        throw const FormatException('Dados incompletos.');
      }

      final expiresAt = DateTime.tryParse(expiresAtText);

      if (expiresAt == null) {
        throw const FormatException('Validade inválida.');
      }

      if (DateTime.now().isAfter(expiresAt)) {
        await showResultDialog(
          success: false,
          title: 'Sessão expirada',
          message:
              'Este QR Code não está mais válido. Peça ao professor para gerar outro.',
        );

        return;
      }

      await showResultDialog(
        success: true,
        title: 'Presença confirmada!',
        message:
            'Check-in realizado na turma $classroomId.\n\nCada treino conta.',
      );
    } on FormatException {
      await showResultDialog(
        success: false,
        title: 'QR Code inválido',
        message:
            'Este código não pertence a uma sessão válida do Tatame+.',
      );
    } catch (_) {
      await showResultDialog(
        success: false,
        title: 'Não foi possível registrar',
        message:
            'Ocorreu um problema ao interpretar o QR Code. Tente novamente.',
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
            color: success
                ? AppColors.success
                : AppColors.gracieRed,
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
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
            icon: Icon(
              torchEnabled
                  ? Icons.flash_on
                  : Icons.flash_off,
            ),
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
                    'Não foi possível abrir a câmera.\nVerifique a permissão do aplicativo.',
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
                  Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.white,
                    size: 34,
                  ),
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
            border: Border.all(
              color: AppColors.white,
              width: 3,
            ),
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

  const _ScannerError({
    required this.message,
    required this.onRetry,
  });

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