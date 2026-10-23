class DocumentUploadResult {
  final String storagePath;
  final String fileName;
  final String sha256;
  final int sizeBytes;

  const DocumentUploadResult({
    required this.storagePath,
    required this.fileName,
    required this.sha256,
    required this.sizeBytes,
  });
}
