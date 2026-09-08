import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class FinanceStorageService {
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  final FirebaseStorage storage;

  FinanceStorageService({FirebaseStorage? storage})
    : storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadProof({
    required String academyId,
    required String studentId,
    required String proofId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('O arquivo do comprovante está vazio.');
    }

    if (bytes.length > maxFileSizeBytes) {
      throw ArgumentError('O comprovante deve ter no máximo 5 MB.');
    }

    final extension = _extensionForContentType(contentType);

    final uploadVersion = DateTime.now().toUtc().microsecondsSinceEpoch;

    final storagePath =
        'academies/$academyId/financeProofs/'
        '$studentId/$proofId-$uploadVersion.$extension';

    final reference = storage.ref(storagePath);

    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'originalFileName': fileName,
          'academyId': academyId,
          'studentId': studentId,
          'proofId': proofId,
        },
      ),
    );

    return storagePath;
  }

  Future<String> getDownloadUrl(String storagePath) {
    return storage.ref(storagePath).getDownloadURL();
  }

  Future<void> deleteProof(String storagePath) {
    return storage.ref(storagePath).delete();
  }

  String _extensionForContentType(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      default:
        throw ArgumentError(
          'Formato inválido. Use uma imagem JPG, PNG ou WebP.',
        );
    }
  }
}
