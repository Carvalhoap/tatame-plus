enum LegalDocumentType {
  riskAcknowledgement,
  healthAndEmergency,
  imageAuthorization,
  minorResponsibility,
  codeOfConduct,
  privacyAndLgpd,
  enrollmentContract,
}

extension LegalDocumentTypePresentation on LegalDocumentType {
  String get label {
    switch (this) {
      case LegalDocumentType.riskAcknowledgement:
        return 'Ciência de riscos';

      case LegalDocumentType.healthAndEmergency:
        return 'Saúde e emergência';

      case LegalDocumentType.imageAuthorization:
        return 'Autorização de uso de imagem';

      case LegalDocumentType.minorResponsibility:
        return 'Responsabilidade por menor';

      case LegalDocumentType.codeOfConduct:
        return 'Código de conduta';

      case LegalDocumentType.privacyAndLgpd:
        return 'Privacidade e LGPD';

      case LegalDocumentType.enrollmentContract:
        return 'Contrato de matrícula';
    }
  }
}

enum LegalDocumentStatus { draft, published, archived }

enum DocumentAssignmentStatus { pending, signed, expired }

enum DocumentSignerRole { student, guardian }
