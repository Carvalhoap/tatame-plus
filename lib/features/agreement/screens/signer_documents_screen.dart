import 'document_signing_screen.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/document_assignment.dart';
import '../models/document_enums.dart';
import '../models/legal_document.dart';
import '../repository/document_repository.dart';
import '../repository/document_storage_repository.dart';

class SignerDocumentsScreen extends StatefulWidget {
  const SignerDocumentsScreen({super.key});

  @override
  State<SignerDocumentsScreen> createState() => _SignerDocumentsScreenState();
}

class _SignerDocumentsScreenState extends State<SignerDocumentsScreen> {
  late Future<_SignerDocumentsData> dataFuture;

  @override
  void initState() {
    super.initState();
    dataFuture = _loadData();
  }

  Future<_SignerDocumentsData> _loadData() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      throw StateError('Sua sessão não está disponível.');
    }

    final repository = context.read<DocumentRepository>();

    late final List<DocumentAssignment> assignments;
    late final List<LegalDocument> documents;

    try {
      assignments = List<DocumentAssignment>.from(
        await repository.getAssignmentsForSigner(
          academyId: currentUser.academyId,
          signerUserId: currentUser.id,
        ),
      );
    } catch (error) {
      throw StateError('Falha ao consultar atribuições do assinante: $error');
    }

    try {
      documents = List<LegalDocument>.from(
        await repository.getPublishedDocuments(
          academyId: currentUser.academyId,
        ),
      );
    } catch (error) {
      throw StateError('Falha ao consultar documentos publicados: $error');
    }

    final documentsById = {
      for (final document in documents) document.id: document,
    };

    assignments.sort((first, second) {
      final firstPriority = _statusPriority(first);
      final secondPriority = _statusPriority(second);

      if (firstPriority != secondPriority) {
        return firstPriority.compareTo(secondPriority);
      }

      return second.assignedAt.compareTo(first.assignedAt);
    });

    return _SignerDocumentsData(
      assignments: assignments,
      documentsById: documentsById,
    );
  }

  static int _statusPriority(DocumentAssignment assignment) {
    if (assignment.status != DocumentAssignmentStatus.signed &&
        assignment.isExpiredAt(DateTime.now())) {
      return 2;
    }

    switch (assignment.status) {
      case DocumentAssignmentStatus.pending:
        return 0;

      case DocumentAssignmentStatus.signed:
        return 1;

      case DocumentAssignmentStatus.expired:
        return 2;
    }
  }

  void _reload() {
    setState(() {
      dataFuture = _loadData();
    });
  }

  Future<void> _openDocument(
    LegalDocument document,
    DocumentAssignment assignment,
  ) async {
    final canSign =
        assignment.status == DocumentAssignmentStatus.pending &&
        !assignment.isExpiredAt(DateTime.now()) &&
        document.isEffectiveAt(DateTime.now()) &&
        assignment.documentVersion == document.version;

    if (canSign) {
      final signed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DocumentSigningScreen(document: document, assignment: assignment),
        ),
      );

      if (mounted && signed == true) {
        _reload();
      }
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DocumentPdfScreen(document: document, assignment: assignment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Documentos'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_SignerDocumentsData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _DocumentError(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final data = snapshot.data!;

          if (data.assignments.isEmpty) {
            return const _EmptyDocuments();
          }

          final now = DateTime.now();

          final pendingCount = data.assignments.where((assignment) {
            return assignment.status == DocumentAssignmentStatus.pending &&
                !assignment.isExpiredAt(now);
          }).length;

          final signedCount = data.assignments.where((assignment) {
            return assignment.status == DocumentAssignmentStatus.signed;
          }).length;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await dataFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SummaryCard(
                  pendingCount: pendingCount,
                  signedCount: signedCount,
                ),
                const SizedBox(height: 16),
                ...data.assignments.map((assignment) {
                  final document = data.documentsById[assignment.documentId];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AssignmentCard(
                      assignment: assignment,
                      document: document,
                      onOpen: document == null
                          ? null
                          : () => _openDocument(document, assignment),
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

class DocumentPdfScreen extends StatefulWidget {
  final LegalDocument document;

  final DocumentAssignment? assignment;

  const DocumentPdfScreen({super.key, required this.document, this.assignment});

  @override
  State<DocumentPdfScreen> createState() => _DocumentPdfScreenState();
}

class _DocumentPdfScreenState extends State<DocumentPdfScreen> {
  late Future<Uint8List> pdfFuture;

  @override
  void initState() {
    super.initState();

    pdfFuture = _loadPdf();
  }

  Future<Uint8List> _loadPdf() async {
    final storage = context.read<DocumentStorageRepository>();
    final repository = context.read<DocumentRepository>();
    final assignment = widget.assignment;

    if (assignment?.status == DocumentAssignmentStatus.signed) {
      final signedAssignment = assignment!;
      final signature = await repository.getSignatureByAssignment(
        academyId: signedAssignment.academyId,
        assignmentId: signedAssignment.id,
      );

      if (signature == null) {
        throw StateError('O registro da assinatura não foi encontrado.');
      }

      final expectedPrefix =
          'academies/${signedAssignment.academyId}/signedDocuments/'
          '${signedAssignment.studentId}/${signedAssignment.id}/';

      if (signature.assignmentId != signedAssignment.id ||
          signature.documentId != signedAssignment.documentId ||
          signature.documentVersion != signedAssignment.documentVersion ||
          signature.studentId != signedAssignment.studentId ||
          signature.signerUserId != signedAssignment.assignedSignerUserId ||
          !signature.signedPdfStoragePath.startsWith(expectedPrefix)) {
        throw StateError(
          'Os dados do PDF assinado não correspondem à atribuição.',
        );
      }

      return storage.downloadOriginalPdf(
        storagePath: signature.signedPdfStoragePath,
        expectedSha256: signature.signedPdfSha256,
      );
    }

    return storage.downloadOriginalPdf(
      storagePath: widget.document.storagePath,
      expectedSha256: widget.document.documentSha256,
    );
  }

  void _reload() {
    setState(() {
      pdfFuture = _loadPdf();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.document.title, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
      ),
      body: FutureBuilder<Uint8List>(
        future: pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _DocumentError(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final bytes = snapshot.data!;

          return PdfPreview(
            build: (_) async => bytes,
            pdfFileName: widget.document.fileName,
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowPrinting: false,
            allowSharing: false,
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pendingCount;
  final int signedCount;

  const _SummaryCard({required this.pendingCount, required this.signedCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.brandPrimary,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seus documentos',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Leia cada documento antes de assinar.',
                    style: TextStyle(color: AppColors.white),
                  ),
                ],
              ),
            ),
            _SummaryNumber(value: pendingCount, label: 'Pendentes'),
            const SizedBox(width: 12),
            _SummaryNumber(value: signedCount, label: 'Assinados'),
          ],
        ),
      ),
    );
  }
}

class _SummaryNumber extends StatelessWidget {
  final int value;
  final String label;

  const _SummaryNumber({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.white, fontSize: 11),
        ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final DocumentAssignment assignment;
  final LegalDocument? document;
  final VoidCallback? onOpen;

  const _AssignmentCard({
    required this.assignment,
    required this.document,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final status = _displayStatus();
    final documentTitle = document?.title ?? 'Documento indisponível';

    return Card(
      color: AppColors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined, color: status.color, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documentTitle,
                        style: const TextStyle(
                          color: AppColors.brandPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Referente a ${assignment.studentName}',
                        style: const TextStyle(color: AppColors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              assignment.requiredSignerRole == DocumentSignerRole.guardian
                  ? 'Assinatura solicitada ao responsável.'
                  : 'Assinatura solicitada ao aluno.',
              style: const TextStyle(color: AppColors.grey),
            ),
            if (assignment.status == DocumentAssignmentStatus.pending &&
                !assignment.isExpiredAt(DateTime.now())) ...[
              const SizedBox(height: 6),
              const Text(
                'Leia o documento completo antes de assinar.',
                style: TextStyle(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Abrir documento'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _DocumentStatusPresentation _displayStatus() {
    if (assignment.status != DocumentAssignmentStatus.signed &&
        assignment.isExpiredAt(DateTime.now())) {
      return _DocumentStatusPresentation(
        label: 'Vencido',
        color: Colors.red.shade700,
      );
    }

    switch (assignment.status) {
      case DocumentAssignmentStatus.pending:
        return _DocumentStatusPresentation(
          label: 'Pendente',
          color: Colors.orange.shade800,
        );

      case DocumentAssignmentStatus.signed:
        return _DocumentStatusPresentation(
          label: 'Assinado',
          color: Colors.green.shade700,
        );

      case DocumentAssignmentStatus.expired:
        return _DocumentStatusPresentation(
          label: 'Vencido',
          color: Colors.red.shade700,
        );
    }
  }
}

class _DocumentStatusPresentation {
  final String label;
  final Color color;

  const _DocumentStatusPresentation({required this.label, required this.color});
}

class _SignerDocumentsData {
  final List<DocumentAssignment> assignments;
  final Map<String, LegalDocument> documentsById;

  const _SignerDocumentsData({
    required this.assignments,
    required this.documentsById,
  });
}

class _EmptyDocuments extends StatelessWidget {
  const _EmptyDocuments();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 90),
        Icon(Icons.task_alt, size: 64, color: AppColors.grey),
        SizedBox(height: 18),
        Text(
          'Nenhum documento pendente',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.brandPrimary,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Quando a academia solicitar uma assinatura, '
          'o documento aparecerá aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grey, fontSize: 15),
        ),
      ],
    );
  }
}

class _DocumentError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DocumentError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Não foi possível carregar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.brandPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
