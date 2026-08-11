class Classroom {
  final String id;
  final String academyId;
  final String name;
  final String description;
  final List<String> teacherIds;
  final bool isActive;

  const Classroom({
    required this.id,
    required this.academyId,
    required this.name,
    this.description = '',
    this.teacherIds = const [],
    this.isActive = true,
  });
}
