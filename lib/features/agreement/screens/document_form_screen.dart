import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/services/session_service.dart';
import '../models/document_enums.dart';
import '../models/legal_document.dart';
import '../repository/document_repository.dart';
import '../repository/document_storage_repository.dart';
import '../services/pdf_document_validator.dart';

class DocumentFormScreen extends StatefulWidget {
  const DocumentFormScreen({super.key});

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final versionController = TextEditingController(text: '1.0');

  LegalDocumentType selectedType = LegalDocumentType.riskAcknowledgement;

  DateTime effectiveAt = DateTime.now();
  DateTime? expiresAt;
  bool guardianRequiredForMinor = true;
  bool isSelectingFile = false;
  bool isSaving = false;

  XFile? selectedFile;
  Uint8List? selectedBytes;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    versionController.dispose();
    super.dispose();
  }

  Future<void> selectPdf() async {
    if (isSelectingFile || isSaving) {
      return;
    }

    setState(() {
      isSelectingFile = true;
    });

    try {
      const pdfGroup = XTypeGroup(
        label: 'Documentos PDF',
        extensions: <String>['pdf'],
        mimeTypes: <String>['application/pdf'],
      );

      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[pdfGroup],
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();

      const PdfDocumentValidator().validate(bytes);

      if (!mounted) {
        return;
      }

      setState(() {
        selectedFile = file;
        selectedBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Não foi possível selecionar o PDF: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSelectingFile = false;
        });
      }
    }
  }

  Future<void> selectEffectiveDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: effectiveAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Início da vigência',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      effectiveAt = selectedDate;

      if (expiresAt != null && !expiresAt!.isAfter(effectiveAt)) {
        expiresAt = null;
      }
    });
  }

  Future<void> selectExpirationDate() async {
    final initialDate = expiresAt ?? effectiveAt.add(const Duration(days: 365));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: effectiveAt.add(const Duration(days: 1)),
      lastDate: DateTime(2100),
      helpText: 'Fim da vigência',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      expiresAt = selectedDate;
    });
  }

  Future<void> saveDocument({required bool publish}) async {
    if (isSaving) {
      return;
    }

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final file = selectedFile;
    final bytes = selectedBytes;

    if (file == null || bytes == null) {
      _showMessage('Selecione o documento PDF.', isError: true);
      return;
    }

    final currentUser = context.read<SessionService>().currentUser;

    if (currentUser == null) {
      _showMessage('Sua sessão não está disponível.', isError: true);
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final documentRepository = context.read<DocumentRepository>();

      final storageRepository = context.read<DocumentStorageRepository>();

      final documentId = documentRepository.createDocumentId(
        academyId: currentUser.academyId,
      );

      final upload = await storageRepository.uploadOriginalPdf(
        academyId: currentUser.academyId,
        documentId: documentId,
        version: versionController.text.trim(),
        fileName: file.name,
        uploadedBy: currentUser.id,
        bytes: bytes,
      );

      final now = DateTime.now();

      final document = LegalDocument(
        id: documentId,
        academyId: currentUser.academyId,
        type: selectedType,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        version: versionController.text.trim(),
        fileName: upload.fileName,
        storagePath: upload.storagePath,
        documentSha256: upload.sha256,
        status: LegalDocumentStatus.draft,
        guardianRequiredForMinor: guardianRequiredForMinor,
        effectiveAt: effectiveAt,
        expiresAt: expiresAt,
        publishedAt: null,
        createdAt: now,
        updatedAt: now,
        createdBy: currentUser.id,
      );

      await documentRepository.saveDraft(document: document);

      if (publish) {
        await documentRepository.publishDocument(
          academyId: currentUser.academyId,
          documentId: documentId,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Não foi possível salvar o documento: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.gracieRed : AppColors.success,
      ),
    );
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String formatFileSize(int sizeBytes) {
    final sizeMb = sizeBytes / (1024 * 1024);

    return '${sizeMb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Novo documento'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
      ),
      body: AbsorbPointer(
        absorbing: isSaving,
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Informações do documento',
                style: TextStyle(
                  color: AppColors.brandPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O documento original será preservado e não poderá ser substituído.',
                style: TextStyle(color: AppColors.grey, height: 1.4),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<LegalDocumentType>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de documento',
                  border: OutlineInputBorder(),
                ),
                items: LegalDocumentType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (type) {
                  if (type == null) {
                    return;
                  }

                  setState(() {
                    selectedType = type;

                    if (titleController.text.trim().isEmpty) {
                      titleController.text = type.label;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: titleController,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o título.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descriptionController,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: versionController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Versão',
                  hintText: 'Exemplo: 1.0',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe a versão.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 8),
              Card(
                color: AppColors.white,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.event_available_outlined,
                        color: AppColors.brandPrimary,
                      ),
                      title: const Text('Início da vigência'),
                      subtitle: Text(formatDate(effectiveAt)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: selectEffectiveDate,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.event_busy_outlined,
                        color: AppColors.brandPrimary,
                      ),
                      title: const Text('Fim da vigência'),
                      subtitle: Text(
                        expiresAt == null
                            ? 'Sem vencimento'
                            : formatDate(expiresAt!),
                      ),
                      trailing: expiresAt == null
                          ? const Icon(Icons.add)
                          : IconButton(
                              tooltip: 'Remover vencimento',
                              onPressed: () {
                                setState(() {
                                  expiresAt = null;
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                      onTap: selectExpirationDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: guardianRequiredForMinor,
                onChanged: (value) {
                  setState(() {
                    guardianRequiredForMinor = value;
                  });
                },
                title: const Text('Responsável assina para menores'),
                subtitle: const Text(
                  'Quando o aluno for menor, a assinatura deverá ser feita por um responsável vinculado.',
                ),
                activeThumbColor: AppColors.brandPrimary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isSelectingFile ? null : selectPdf,
                icon: isSelectingFile
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  selectedFile == null ? 'Selecionar PDF' : 'Trocar PDF',
                ),
              ),
              if (selectedFile != null && selectedBytes != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedFile!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(formatFileSize(selectedBytes!.length)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (isSaving)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Enviando e protegendo o documento...'),
                    ],
                  ),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: () => saveDocument(publish: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Salvar como rascunho'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => saveDocument(publish: true),
                  icon: const Icon(Icons.publish_outlined),
                  label: const Text('Salvar e publicar'),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
