import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/document_assignment.dart';
import '../models/legal_document.dart';
import '../repository/document_storage_repository.dart';

class DocumentSigningScreen extends StatefulWidget {
  final LegalDocument document;
  final DocumentAssignment assignment;

  const DocumentSigningScreen({
    super.key,
    required this.document,
    required this.assignment,
  });

  @override
  State<DocumentSigningScreen> createState() => _DocumentSigningScreenState();
}

class _DocumentSigningScreenState extends State<DocumentSigningScreen> {
  late Future<Uint8List> pdfFuture;

  final List<List<Offset>> strokes = [];
  bool signingStep = false;
  bool accepted = false;
  bool submitting = false;

  static const acceptanceText =
      'Declaro que li integralmente o documento, compreendi seu '
      'conteúdo e manifesto livremente minha concordância por meio '
      'desta assinatura eletrônica.';

  @override
  void initState() {
    super.initState();
    pdfFuture = _loadPdf();
  }

  Future<Uint8List> _loadPdf() {
    return context.read<DocumentStorageRepository>().downloadOriginalPdf(
      storagePath: widget.document.storagePath,
      expectedSha256: widget.document.documentSha256,
    );
  }

  bool get hasSignature {
    return strokes.any((stroke) {
      if (stroke.length < 2) return false;
      final first = stroke.first;
      return stroke.any((point) => (point - first).distance > 0.02);
    });
  }

  Future<Uint8List> _signaturePng() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(900, 300);

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    _SignaturePainter(strokes).paint(canvas, size);

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(900, 300);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);

        if (data == null) {
          throw StateError('Não foi possível gerar a assinatura.');
        }

        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (submitting || !accepted || !hasSignature) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar assinatura'),
        content: Text(
          'Você assinará "${widget.document.title}", '
          'versão ${widget.assignment.documentVersion}, '
          'referente a ${widget.assignment.studentName}. '
          'Deseja confirmar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => submitting = true);

    try {
      final png = await _signaturePng();

      if (!mounted) return;

      final functions = FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      );

      final callable = functions.httpsCallable(
        'signLegalDocument',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 70)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'academyId': widget.assignment.academyId,
        'assignmentId': widget.assignment.id,
        'accepted': true,
        'signaturePngBase64': base64Encode(png),
      });

      if (result.data['success'] != true) {
        throw StateError(
          'O servidor não confirmou a assinatura. '
          'Atualize a lista antes de tentar novamente.',
        );
      }

      if (!mounted) return;

      setState(() => submitting = false);
      Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (error) {
      final message = switch (error.code) {
        'not-found' =>
          'A função ou o documento não está disponível. '
              'A publicação da função precisa ser conferida.',
        'unauthenticated' =>
          'Sua sessão expirou. Entre novamente no aplicativo.',
        'permission-denied' =>
          error.message ?? 'Você não tem autorização para assinar.',
        'deadline-exceeded' || 'unavailable' =>
          'Não foi possível confirmar o resultado. '
              'Volte e atualize a lista antes de tentar novamente.',
        _ => error.message ?? 'Não foi possível concluir a assinatura.',
      };
      _message(message);
    } catch (_) {
      _message(
        'Não foi possível confirmar a assinatura. '
        'Volte e atualize a lista antes de tentar novamente.',
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Widget _signaturePad() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxWidth / 3);

        Offset normalized(Offset point) {
          return Offset(
            (point.dx / size.width).clamp(0.0, 1.0).toDouble(),
            (point.dy / size.height).clamp(0.0, 1.0).toDouble(),
          );
        }

        return Semantics(
          label: 'Área para desenhar sua assinatura',
          child: ClipRect(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: submitting
                  ? null
                  : (details) {
                      setState(() {
                        strokes.add([normalized(details.localPosition)]);
                      });
                    },
              onPanUpdate: submitting
                  ? null
                  : (details) {
                      if (strokes.isEmpty) return;
                      setState(() {
                        strokes.last.add(normalized(details.localPosition));
                      });
                    },
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  painter: _SignaturePainter(strokes),
                  child: strokes.isEmpty
                      ? const Center(child: Text('Desenhe sua assinatura aqui'))
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !submitting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(signingStep ? 'Assinar documento' : 'Ler documento'),
        ),
        body: signingStep
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.document.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Aluno: ${widget.assignment.studentName}'),
                  Text('Versão: ${widget.assignment.documentVersion}'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: submitting
                        ? null
                        : () => setState(() => signingStep = false),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Reler documento'),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: accepted,
                    onChanged: submitting
                        ? null
                        : (value) {
                            setState(() => accepted = value == true);
                          },
                    title: const Text(acceptanceText),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  _signaturePad(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: submitting
                          ? null
                          : () => setState(strokes.clear),
                      child: const Text('Limpar assinatura'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: accepted && hasSignature && !submitting
                        ? _submit
                        : null,
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.draw_outlined),
                    label: Text(
                      submitting
                          ? 'Registrando assinatura...'
                          : 'Assinar documento',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'O envio registra seu aceite e sua assinatura '
                    'para esta versão do documento.',
                  ),
                ],
              )
            : FutureBuilder<Uint8List>(
                future: pdfFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(
                              'Não foi possível carregar e validar o PDF.\n\n'
                              '${snapshot.error ?? "Nenhum dado recebido."}',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                setState(() => pdfFuture = _loadPdf());
                              },
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final bytes = snapshot.data!;

                  return Column(
                    children: [
                      Expanded(
                        child: PdfPreview(
                          build: (_) async => bytes,
                          pdfFileName: widget.document.fileName,
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          allowPrinting: false,
                          allowSharing: false,
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: FilledButton(
                            onPressed: () {
                              setState(() => signingStep = true);
                            },
                            child: const Text(
                              'Li o documento e quero continuar',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = size.width / 300
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;

      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);

      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
