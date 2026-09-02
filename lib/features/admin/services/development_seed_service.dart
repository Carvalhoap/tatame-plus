import '../../classroom/models/classroom.dart';
import '../../classroom/repository/classroom_repository.dart';
import '../../graduation/data/graduation_template_catalog.dart';
import '../../graduation/models/graduation_program.dart';
import '../../graduation/models/graduation_stage.dart';
import '../../graduation/models/graduation_template.dart';
import '../../graduation/models/student_graduation_progress.dart';
import '../../graduation/repository/graduation_program_repository.dart';
import '../../graduation/repository/student_graduation_progress_repository.dart';
import '../../student/models/student.dart';
import '../../student/repository/student_repository.dart';
import '../../training_type/repository/training_type_repository.dart';

class DevelopmentSeedResult {
  final int trainingTypesCreated;
  final int classroomsCreated;
  final int graduationProgramsCreated;
  final int studentsCreated;
  final int graduationProgressesCreated;

  const DevelopmentSeedResult({
    required this.trainingTypesCreated,
    required this.classroomsCreated,
    required this.graduationProgramsCreated,
    required this.studentsCreated,
    required this.graduationProgressesCreated,
  });

  int get totalCreated =>
      trainingTypesCreated +
      classroomsCreated +
      graduationProgramsCreated +
      studentsCreated +
      graduationProgressesCreated;
}

class DevelopmentSeedService {
  static const _environment = String.fromEnvironment(
    'FIREBASE_ENV',
    defaultValue: 'production',
  );

  Future<DevelopmentSeedResult> seed({
    required String academyId,
    required String administratorUserId,
    required TrainingTypeRepository trainingTypeRepository,
    required ClassroomRepository classroomRepository,
    required GraduationProgramRepository graduationProgramRepository,
    required StudentRepository studentRepository,
    required StudentGraduationProgressRepository progressRepository,
  }) async {
    if (_environment != 'development') {
      throw StateError(
        'A carga de dados fictícios só pode ser executada em desenvolvimento.',
      );
    }

    var trainingTypesCreated = 0;
    var classroomsCreated = 0;
    var graduationProgramsCreated = 0;
    var studentsCreated = 0;
    var graduationProgressesCreated = 0;

    final existingTrainingTypes = await trainingTypeRepository.getTrainingTypes(
      academyId: academyId,
      includeInactive: true,
    );

    final trainingTypeIds = <String, String>{
      for (final item in existingTrainingTypes) item.name: item.id,
    };

    Future<String> ensureTrainingType({
      required String name,
      required String description,
    }) async {
      final existingId = trainingTypeIds[name];

      if (existingId != null) {
        return existingId;
      }

      final id = await trainingTypeRepository.createTrainingType(
        academyId: academyId,
        name: name,
        description: description,
        isActive: true,
        createdBy: administratorUserId,
      );

      trainingTypeIds[name] = id;
      trainingTypesCreated++;

      return id;
    }

    final fundamentalsTrainingTypeId = await ensureTrainingType(
      name: 'GB1 - Fundamentos',
      description: 'Aulas fundamentais de Jiu-Jitsu com kimono.',
    );

    final advancedTrainingTypeId = await ensureTrainingType(
      name: 'GB2 e GB3',
      description: 'Aulas intermediárias e avançadas com kimono.',
    );

    final kidsTrainingTypeId = await ensureTrainingType(
      name: 'Kids',
      description: 'Aulas de Jiu-Jitsu voltadas ao público infantil.',
    );

    final existingPrograms = await graduationProgramRepository.getPrograms(
      academyId: academyId,
      includeInactive: true,
    );

    final programsByName = <String, GraduationProgram>{
      for (final item in existingPrograms) item.name: item,
    };

    Future<GraduationProgram> ensureGraduationProgram({
      required String name,
      required String templateId,
      required GraduationAudience audience,
    }) async {
      final existing = programsByName[name];

      if (existing != null) {
        return existing;
      }

      final template = GraduationTemplateCatalog.findById(templateId);

      if (template == null) {
        throw StateError('Template de graduação não encontrado: $templateId');
      }

      final stages = _convertStages(template);

      final id = await graduationProgramRepository.createProgram(
        academyId: academyId,
        name: name,
        audience: audience,
        stages: stages,
        isActive: true,
        createdBy: administratorUserId,
      );

      final program = GraduationProgram(
        id: id,
        academyId: academyId,
        name: name,
        audience: audience,
        stages: stages,
      );

      programsByName[name] = program;
      graduationProgramsCreated++;

      return program;
    }

    final adultProgram = await ensureGraduationProgram(
      name: 'IBJJF Adulto - Desenvolvimento',
      templateId: 'ibjjf_bjj_adult_2026_1',
      audience: GraduationAudience.adult,
    );

    final kidsProgram = await ensureGraduationProgram(
      name: 'Programa Kids - Desenvolvimento',
      templateId: 'ibjjf_bjj_kids_2026_1',
      audience: GraduationAudience.kids,
    );

    final existingClassrooms = await classroomRepository.getClassrooms(
      academyId: academyId,
      includeInactive: true,
    );

    final classroomIds = <String, String>{
      for (final item in existingClassrooms) item.name: item.id,
    };

    Future<String> ensureClassroom({
      required String name,
      required String description,
      required List<ClassSchedule> schedules,
    }) async {
      final existingId = classroomIds[name];

      if (existingId != null) {
        return existingId;
      }

      final id = await classroomRepository.createClassroom(
        academyId: academyId,
        name: name,
        description: description,
        defaultTeacherId: administratorUserId,
        schedules: schedules,
        isActive: true,
        createdBy: administratorUserId,
      );

      classroomIds[name] = id;
      classroomsCreated++;

      return id;
    }

    final adultClassroomId = await ensureClassroom(
      name: 'Adulto - Noite - Desenvolvimento',
      description: 'Turma adulta fictícia para testes.',
      schedules: [
        ClassSchedule(
          id: 'adult_tuesday_2030',
          name: 'Terça-feira',
          dayOfWeek: 2,
          startTime: '20:30',
          endTime: '21:30',
          trainingTypeIds: [fundamentalsTrainingTypeId, advancedTrainingTypeId],
        ),
        ClassSchedule(
          id: 'adult_thursday_2030',
          name: 'Quinta-feira',
          dayOfWeek: 4,
          startTime: '20:30',
          endTime: '21:30',
          trainingTypeIds: [fundamentalsTrainingTypeId, advancedTrainingTypeId],
        ),
      ],
    );

    final kidsClassroomId = await ensureClassroom(
      name: 'Kids - Desenvolvimento',
      description: 'Turma infantil fictícia para testes.',
      schedules: [
        ClassSchedule(
          id: 'kids_tuesday_1830',
          name: 'Terça-feira',
          dayOfWeek: 2,
          startTime: '18:30',
          endTime: '19:30',
          trainingTypeIds: [kidsTrainingTypeId],
        ),
        ClassSchedule(
          id: 'kids_thursday_1830',
          name: 'Quinta-feira',
          dayOfWeek: 4,
          startTime: '18:30',
          endTime: '19:30',
          trainingTypeIds: [kidsTrainingTypeId],
        ),
      ],
    );

    final morningClassroomId = await ensureClassroom(
      name: 'Adulto - Manhã - Desenvolvimento',
      description: 'Turma matinal fictícia para testes.',
      schedules: [
        ClassSchedule(
          id: 'adult_friday_0630',
          name: 'Sexta-feira',
          dayOfWeek: 5,
          startTime: '06:30',
          endTime: '07:30',
          trainingTypeIds: [fundamentalsTrainingTypeId],
        ),
      ],
    );

    final existingStudents = await studentRepository.getStudentsByAcademy(
      academyId,
    );

    final studentIds = <String, String>{
      for (final item in existingStudents) item.fullName: item.id,
    };

    Future<String> ensureStudent({
      required String fullName,
      required DateTime birthDate,
      required String? userId,
      required String graduationProgramId,
      required List<String> classroomIds,
      required List<String> guardianIds,
    }) async {
      final existingId = studentIds[fullName];

      if (existingId != null) {
        return existingId;
      }

      final id = await studentRepository.createStudent(
        academyId: academyId,
        userId: userId,
        fullName: fullName,
        birthDate: birthDate,
        phone: null,
        email: null,
        photoUrl: null,
        graduationProgramId: graduationProgramId,
        jiuJitsuStartDate: DateTime(2024, 1, 15),
        academyJoinDate: DateTime(2024, 2, 1),
        classroomIds: classroomIds,
        guardianIds: guardianIds,
        status: StudentStatus.active,
        createdBy: administratorUserId,
      );

      studentIds[fullName] = id;
      studentsCreated++;

      return id;
    }

    final adultStudentId = await ensureStudent(
      fullName: 'Aluno Adulto Teste',
      birthDate: DateTime(1990, 5, 10),
      userId: administratorUserId,
      graduationProgramId: adultProgram.id,
      classroomIds: [adultClassroomId, morningClassroomId],
      guardianIds: const [],
    );

    final blueBeltStudentId = await ensureStudent(
      fullName: 'Mariana Souza Teste',
      birthDate: DateTime(1996, 8, 22),
      userId: null,
      graduationProgramId: adultProgram.id,
      classroomIds: [adultClassroomId],
      guardianIds: const [],
    );

    final firstKidStudentId = await ensureStudent(
      fullName: 'Ana Clara Teste',
      birthDate: DateTime(2017, 3, 14),
      userId: null,
      graduationProgramId: kidsProgram.id,
      classroomIds: [kidsClassroomId],
      guardianIds: [administratorUserId],
    );

    final secondKidStudentId = await ensureStudent(
      fullName: 'Pedro Henrique Teste',
      birthDate: DateTime(2015, 11, 8),
      userId: null,
      graduationProgramId: kidsProgram.id,
      classroomIds: [kidsClassroomId],
      guardianIds: [administratorUserId],
    );

    Future<void> ensureProgress({
      required String studentId,
      required String graduationProgramId,
      required String currentStageId,
      required DateTime stageStartedAt,
      required int validAttendances,
    }) async {
      final existing = await progressRepository.getByStudent(
        academyId: academyId,
        studentId: studentId,
      );

      if (existing != null) {
        return;
      }

      await progressRepository.saveProgress(
        progress: StudentGraduationProgress(
          id: studentId,
          academyId: academyId,
          studentId: studentId,
          graduationProgramId: graduationProgramId,
          currentStageId: currentStageId,
          stageStartedAt: stageStartedAt,
          validAttendances: validAttendances,
        ),
      );

      graduationProgressesCreated++;
    }

    final now = DateTime.now();

    await ensureProgress(
      studentId: adultStudentId,
      graduationProgramId: adultProgram.id,
      currentStageId: 'white_belt_degree_2',
      stageStartedAt: now.subtract(const Duration(days: 120)),
      validAttendances: 28,
    );

    await ensureProgress(
      studentId: blueBeltStudentId,
      graduationProgramId: adultProgram.id,
      currentStageId: 'blue_belt',
      stageStartedAt: now.subtract(const Duration(days: 240)),
      validAttendances: 64,
    );

    await ensureProgress(
      studentId: firstKidStudentId,
      graduationProgramId: kidsProgram.id,
      currentStageId: 'grey_white_belt_degree_1',
      stageStartedAt: now.subtract(const Duration(days: 90)),
      validAttendances: 22,
    );

    await ensureProgress(
      studentId: secondKidStudentId,
      graduationProgramId: kidsProgram.id,
      currentStageId: 'yellow_belt',
      stageStartedAt: now.subtract(const Duration(days: 180)),
      validAttendances: 51,
    );

    return DevelopmentSeedResult(
      trainingTypesCreated: trainingTypesCreated,
      classroomsCreated: classroomsCreated,
      graduationProgramsCreated: graduationProgramsCreated,
      studentsCreated: studentsCreated,
      graduationProgressesCreated: graduationProgressesCreated,
    );
  }

  List<GraduationStage> _convertStages(GraduationTemplate template) {
    return template.orderedStages
        .map(
          (stage) => GraduationStage(
            id: stage.id,
            name: stage.name,
            beltName: stage.beltName,
            degreeName: stage.degreeName,
            stripeColor: stage.stripeColor,
            order: stage.order,
            criterion: stage.criterion,
            requiredAttendances: stage.requiredAttendances,
            minimumDurationMonths: stage.minimumDurationMonths,
            nextStageId: stage.nextStageId,
          ),
        )
        .toList(growable: false);
  }
}
