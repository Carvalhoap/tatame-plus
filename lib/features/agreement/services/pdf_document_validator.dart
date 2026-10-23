import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PdfDocumentValidator {
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  const PdfDocumentValidator();

  void validate(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('O arquivo PDF está vazio.');
    }

    if (bytes.length > maxFileSizeBytes) {
      throw const FormatException('O PDF deve possuir no máximo 10 MB.');
    }

    if (!_hasPdfHeader(bytes)) {
      throw const FormatException('O arquivo selecionado não é um PDF válido.');
    }
  }

  String calculateSha256(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  bool _hasPdfHeader(Uint8List bytes) {
    const pdfHeader = <int>[37, 80, 68, 70, 45];

    if (bytes.length < pdfHeader.length) {
      return false;
    }

    for (var index = 0; index < pdfHeader.length; index++) {
      if (bytes[index] != pdfHeader[index]) {
        return false;
      }
    }

    return true;
  }
}
