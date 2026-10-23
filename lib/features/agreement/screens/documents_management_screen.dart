import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/document_enums.dart';
import '../models/legal_document.dart';
import '../repository/document_repository.dart';
import 'document_form_screen.dart';

class DocumentsManagementScreen extends StatefulWidget {
  const DocumentsManagementScreen({super.key});

  @override
  State<DocumentsManagementScreen> createState() =>
      _DocumentsManagementScreenState();
}

class _DocumentsManagementScreenState extends State<DocumentsManagementScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<LegalDocument> documents = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => loadDocuments());
  }

  Future<void> loadDocuments() async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Sessão não encontrada.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final loadedDocuments = await context
          .read<DocumentRepository>()
          .getDocuments(academyId: currentUser.academyId);

      if (!mounted) {
        return;
      }

      setState(() {
        documents = loadedDocuments;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Não foi possível carregar os documentos: $error';
      });
    }
  }

  Future<void> openNewDocument() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DocumentFormScreen()),
    );

    if (saved == true && mounted) {
      await loadDocuments();
    }
  }

  Future<void> publishDocument(LegalDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publicar documento?'),
        content: Text(
          'Após a publicação, "${document.title}" ficará disponível para atribuição aos alunos.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      await context.read<DocumentRepository>().publishDocument(
        academyId: currentUser.academyId,
        documentId: document.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Documento publicado.');
      await loadDocuments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Não foi possível publicar: $error', isError: true);
    }
  }

  Future<void> archiveDocument(LegalDocument document) async {
    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      return;
    }

    try {
      await context.read<DocumentRepository>().archiveDocument(
        academyId: currentUser.academyId,
        documentId: document.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Documento arquivado.');
      await loadDocuments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Não foi possível arquivar: $error', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.gracieRed : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draftCount = documents
        .where((document) => document.status == LegalDocumentStatus.draft)
        .length;

    final publishedCount = documents
        .where((document) => document.status == LegalDocumentStatus.published)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Documentos e assinaturas'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: loadDocuments,
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openNewDocument,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Novo documento'),
      ),
      body: RefreshIndicator(
        onRefresh: loadDocuments,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.gracieRed,
                  ),
                  const SizedBox(height: 16),
                  Text(errorMessage!, textAlign: TextAlign.center),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                children: [
                  const Text(
                    'Gestão documental',
                    style: TextStyle(
                      color: AppColors.brandPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cadastre, publique e acompanhe os documentos da academia.',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Rascunhos',
                          value: draftCount,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Publicados',
                          value: publishedCount,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (documents.isEmpty)
                    const _EmptyDocuments()
                  else
                    ...documents.map(
                      (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DocumentCard(
                          document: document,
                          onPublish: () => publishDocument(document),
                          onArchive: () => archiveDocument(document),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final LegalDocument document;
  final VoidCallback onPublish;
  final VoidCallback onArchive;

  const _DocumentCard({
    required this.document,
    required this.onPublish,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _statusColor().withValues(alpha: 0.12),
              foregroundColor: _statusColor(),
              child: const Icon(Icons.description_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      color: AppColors.brandPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${document.type.label} • Versão ${document.version}',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TextStyle(
                        color: _statusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (document.status != LegalDocumentStatus.archived)
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'publish') {
                    onPublish();
                  }

                  if (action == 'archive') {
                    onArchive();
                  }
                },
                itemBuilder: (_) => [
                  if (document.status == LegalDocumentStatus.draft)
                    const PopupMenuItem(
                      value: 'publish',
                      child: Text('Publicar'),
                    ),
                  if (document.status == LegalDocumentStatus.published)
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Arquivar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel() {
    switch (document.status) {
      case LegalDocumentStatus.draft:
        return 'Rascunho';

      case LegalDocumentStatus.published:
        return 'Publicado';

      case LegalDocumentStatus.archived:
        return 'Arquivado';
    }
  }

  Color _statusColor() {
    switch (document.status) {
      case LegalDocumentStatus.draft:
        return Colors.orange.shade800;

      case LegalDocumentStatus.published:
        return Colors.green.shade700;

      case LegalDocumentStatus.archived:
        return AppColors.grey;
    }
  }
}

class _EmptyDocuments extends StatelessWidget {
  const _EmptyDocuments();

  @override
  Widget build(BuildContext context) {
    return const Card(
      color: AppColors.white,
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 56, color: AppColors.grey),
            SizedBox(height: 14),
            Text(
              'Nenhum documento cadastrado',
              style: TextStyle(
                color: AppColors.brandPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Use o botão “Novo documento” para enviar o primeiro PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
