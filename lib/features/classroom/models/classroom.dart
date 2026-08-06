class Classroom {
  final String id;
  final String academyId;
  final String name;
  final List<String> teacherIds;
  final List<String> studentIds;
  final String description;
  final bool isActive;

  const Classroom({
    required this.id,
    required this.academyId,
    required this.name,
    this.teacherIds = const [],
    this.studentIds = const [],
    this.description = '',
    this.isActive = true,
  });
}
