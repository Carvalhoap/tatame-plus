import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tatame_plus/features/agreement/services/pdf_document_validator.dart';

void main() {
  const validator = PdfDocumentValidator();

  test('aceita arquivo com cabeçalho PDF', () {
    final bytes = Uint8List.fromList(<int>[37, 80, 68, 70, 45, 49, 46, 55]);

    expect(() => validator.validate(bytes), returnsNormally);
  });

  test('rejeita arquivo que não possui cabeçalho PDF', () {
    final bytes = Uint8List.fromList(<int>[80, 78, 71, 45, 49, 46, 55]);

    expect(() => validator.validate(bytes), throwsA(isA<FormatException>()));
  });

  test('gera SHA-256 estável para o mesmo conteúdo', () {
    final bytes = Uint8List.fromList(<int>[37, 80, 68, 70, 45, 49, 46, 55]);

    final firstHash = validator.calculateSha256(bytes);
    final secondHash = validator.calculateSha256(bytes);

    expect(firstHash, secondHash);
    expect(firstHash, hasLength(64));
  });
}
