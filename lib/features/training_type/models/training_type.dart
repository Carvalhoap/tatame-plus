class TrainingType {
  final String id;
  final String academyId;

  final String name;
  final String description;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String createdBy;
  final String updatedBy;

  const TrainingType({
    required this.id,
    required this.academyId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.description = '',
    this.isActive = true,
  });
}
