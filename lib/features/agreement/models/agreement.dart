class Agreement {
  final String id;
  final String academyId;
  final String name;
  final String description;
  final bool active;

  const Agreement({
    required this.id,
    required this.academyId,
    required this.name,
    this.description = '',
    this.active = true,
  });
}
