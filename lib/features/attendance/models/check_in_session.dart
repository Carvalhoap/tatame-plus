class CheckInSession {
  final String id;
  final String academyId;
  final String classroomId;
  final String teacherId;

  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? closedAt;

  const CheckInSession({
    required this.id,
    required this.academyId,
    required this.classroomId,
    required this.teacherId,
    required this.createdAt,
    required this.expiresAt,
    this.closedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isClosed => closedAt != null;

  bool get isActive => !isExpired && !isClosed;

  Duration get remainingTime {
    if (!isActive) {
      return Duration.zero;
    }

    return expiresAt.difference(DateTime.now());
  }

  CheckInSession copyWith({DateTime? closedAt}) {
    return CheckInSession(
      id: id,
      academyId: academyId,
      classroomId: classroomId,
      teacherId: teacherId,
      createdAt: createdAt,
      expiresAt: expiresAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}
