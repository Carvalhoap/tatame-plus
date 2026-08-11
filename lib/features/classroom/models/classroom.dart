class Classroom {
  final String id;
  final String academyId;

  final String name;
  final String description;

  /// Professor responsável padrão da turma.
  ///
  /// Pode ser nulo caso a turma ainda não tenha
  /// um professor principal definido.
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

  /// Nome configurável pelo admin.
  ///
  /// Exemplo:
  /// "Treino Gi"
  /// "No-Gi"
  /// "Treino Feminino"
  final String name;

  /// 1 = segunda-feira
  /// 2 = terça-feira
  /// ...
  /// 7 = domingo
  final int dayOfWeek;

  /// Horário no formato HH:mm.
  final String startTime;

  /// Opcional.
  ///
  /// Caso não seja informado, a interface
  /// exibe somente o horário de início.
  final String? endTime;

  /// Referência a um tipo de treino configurável
  /// pela academia.
  final String? trainingTypeId;

  /// Professor específico deste horário.
  ///
  /// Quando nulo, utiliza o professor padrão
  /// da turma.
  final String? teacherId;

  final bool isActive;

  const ClassSchedule({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.startTime,
    this.endTime,
    this.trainingTypeId,
    this.teacherId,
    this.isActive = true,
  });
}
