class Agreement {
  final String id;
  final String academyId;

  final String name;

  final bool active;

  final String description;

  const Agreement({
    required this.id,
    required this.academyId,
    required this.name,
    this.active = true,
  });
}