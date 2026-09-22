import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FinanceStorageService {
  static const int maxFileSizeBytes = 5 * 1024 * 1024;

  final FirebaseStorage storage;
  final FirebaseFunctions functions;

  FinanceStorageService({
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : storage = storage ?? FirebaseStorage.instance,
       functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'southamerica-east1');

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

  Future<Uint8List> getProofBytes(String storagePath) async {
    final bytes = await storage.ref(storagePath).getData(maxFileSizeBytes);

    if (bytes == null || bytes.isEmpty) {
      throw StateError('O arquivo do comprovante está vazio.');
    }

    return bytes;
  }

  Future<void> deleteProof(String storagePath) async {
    await functions.httpsCallable('deletePaymentProofFile').call<void>({
      'storagePath': storagePath,
    });
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
