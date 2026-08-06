class Plan {
  final String id;
  final String academyId;

  final String name;
  final String description;

  final double price;

  final bool active;

  const Plan({
    required this.id,
    required this.academyId,
    required this.name,
    required this.description,
    required this.price,
    this.active = true,
  });
}
