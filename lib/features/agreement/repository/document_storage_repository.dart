import 'dart:typed_data';

import '../models/document_upload_result.dart';

abstract class DocumentStorageRepository {
  Future<DocumentUploadResult> uploadOriginalPdf({
    required String academyId,
    required String documentId,
    required String version,
    required String fileName,
    required String uploadedBy,
    required Uint8List bytes,
  });
}
