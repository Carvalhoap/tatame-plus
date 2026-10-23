import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../models/document_upload_result.dart';
import '../../repository/document_storage_repository.dart';
import '../../services/pdf_document_validator.dart';

class FirebaseDocumentStorageRepository implements DocumentStorageRepository {
  final FirebaseStorage storage;
  final PdfDocumentValidator validator;

  FirebaseDocumentStorageRepository({
    FirebaseStorage? storage,
    PdfDocumentValidator? validator,
  }) : storage = storage ?? FirebaseStorage.instance,
       validator = validator ?? const PdfDocumentValidator();

  @override
  Future<DocumentUploadResult> uploadOriginalPdf({
    required String academyId,
    required String documentId,
    required String version,
    required String fileName,
    required String uploadedBy,
    required Uint8List bytes,
  }) async {
    validator.validate(bytes);

    final normalizedVersion = _normalizeSegment(version);
    final normalizedFileName = _normalizeFileName(fileName);
    final fileSha256 = validator.calculateSha256(bytes);

    final storagePath =
        'academies/$academyId/'
        'legalDocuments/$documentId/'
        'versions/$normalizedVersion/'
        '$normalizedFileName';

    final reference = storage.ref().child(storagePath);

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'academyId': academyId,
          'documentId': documentId,
          'version': version,
          'sha256': fileSha256,
          'uploadedBy': uploadedBy,
        },
      ),
    );

    return DocumentUploadResult(
      storagePath: storagePath,
      fileName: normalizedFileName,
      sha256: fileSha256,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<Uint8List> downloadOriginalPdf({
    required String storagePath,
    required String expectedSha256,
  }) async {
    final normalizedPath = storagePath.trim();

    if (normalizedPath.isEmpty) {
      throw const FormatException('O caminho do documento não é válido.');
    }

    final bytes = await storage
        .ref()
        .child(normalizedPath)
        .getData(10 * 1024 * 1024);

    if (bytes == null || bytes.isEmpty) {
      throw StateError('O arquivo do documento não foi encontrado.');
    }

    validator.validate(bytes);

    final actualSha256 = validator.calculateSha256(bytes);

    if (actualSha256.toLowerCase() != expectedSha256.trim().toLowerCase()) {
      throw StateError('A integridade do documento não pôde ser confirmada.');
    }

    return bytes;
  }

  String _normalizeSegment(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (normalized.isEmpty) {
      throw const FormatException('A versão do documento não é válida.');
    }

    return normalized;
  }

  String _normalizeFileName(String value) {
    var normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (normalized.isEmpty) {
      normalized = 'documento.pdf';
    }

    if (!normalized.endsWith('.pdf')) {
      normalized = '$normalized.pdf';
    }

    return normalized;
  }
}
