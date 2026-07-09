enum CheckInSessionStatus {
  active,
  expired,
  closed,
}

class CheckInSession {
  final String id;
  final String academyId;

  final String classroomId;
  final String teacherId;

  final DateTime createdAt;
  final DateTime expiresAt;

  final CheckInSessionStatus status;

  const CheckInSession({
    required this.id,
    required this.academyId,
    required this.classroomId,
    required this.teacherId,
    required this.createdAt,
    required this.expiresAt,
    this.status = CheckInSessionStatus.active,
  });

  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }

  bool get isActive {
    return status == CheckInSessionStatus.active && !isExpired;
  }
}