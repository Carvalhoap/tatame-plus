class CheckInSession {
  final String id;

  final String academyId;

  final String classroomId;

  final String teacherId;

  final DateTime createdAt;

  final DateTime expiresAt;

  const CheckInSession({
    required this.id,
    required this.academyId,
    required this.classroomId,
    required this.teacherId,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isActive => !isExpired;

  Duration get remainingTime =>
      expiresAt.difference(DateTime.now());
}