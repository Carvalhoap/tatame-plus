class Classroom {
  final String id;
  final String academyId;

  final String name;
  final String description;

  final String? defaultTeacherId;

  final List<ClassSchedule> schedules;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String createdBy;
  final String updatedBy;

  const Classroom({
    required this.id,
    required this.academyId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.description = '',
    this.defaultTeacherId,
    this.schedules = const [],
    this.isActive = true,
  });
}

class ClassSchedule {
  final String id;

  final String name;

  /// 1 = segunda-feira
  /// ...
  /// 7 = domingo
  final int dayOfWeek;

  final String startTime;
  final String? endTime;

  /// Um horário pode pertencer a mais de um tipo de treino.
  ///
  /// Exemplo:
  /// GB2 + GB3 no mesmo horário.
  final List<String> trainingTypeIds;

  /// Quando nulo, usa o professor padrão da turma.
  final String? teacherId;

  final bool isActive;

  const ClassSchedule({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.startTime,
    this.endTime,
    this.trainingTypeIds = const [],
    this.teacherId,
    this.isActive = true,
  });
}
