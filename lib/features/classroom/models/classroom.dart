class Classroom {
  final String id;
  final String academyId;
  final String name;
  final List<String> teacherIds;

  final String description;
  final bool isActive;

  const Classroom({
    required this.id,
    required this.academyId,
    required this.name,
    required this.teacherIds,
    required this.studentIds,
    required this.description,
    this.isActive = true,
  });
}