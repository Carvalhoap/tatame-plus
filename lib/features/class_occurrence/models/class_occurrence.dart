enum ClassOccurrenceStatus { scheduled, substituted, cancelled, extra }

class ClassOccurrence {
  final String id;
  final String academyId;

  /// Opcional em treinos extraordinários
  /// que não pertencem a uma turma específica.
  final String? classroomId;

  /// ID do horário recorrente que originou
  /// esta ocorrência.
  ///
  /// Fica nulo quando for um treino extra.
  final String? scheduleId;

  final String name;

  /// Data da ocorrência.
  final DateTime date;

  /// Horários no formato HH:mm.
  final String startTime;
  final String? endTime;

  /// Um treino pode ter múltiplos tipos.
  final List<String> trainingTypeIds;

  /// Professor efetivamente responsável
  /// por esta ocorrência específica.
  ///
  /// Se houver substituição, este campo contém
  /// o professor substituto.
  final String? teacherId;

  final ClassOccurrenceStatus status;

  /// Motivo ou observação administrativa.
  ///
  /// Exemplos:
  /// férias, substituição, feriado,
  /// treino especial, cancelamento etc.
  final String note;

  final DateTime createdAt;
  final DateTime updatedAt;

  final String createdBy;
  final String updatedBy;

  const ClassOccurrence({
    required this.id,
    required this.academyId,
    required this.name,
    required this.date,
    required this.startTime,
    required this.trainingTypeIds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.classroomId,
    this.scheduleId,
    this.endTime,
    this.teacherId,
    this.note = '',
  });

  bool get isCancelled => status == ClassOccurrenceStatus.cancelled;

  bool get isExtra => status == ClassOccurrenceStatus.extra;

  bool get hasSubstitute => status == ClassOccurrenceStatus.substituted;
}
