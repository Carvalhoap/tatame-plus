import '../../models/stripe_progress.dart';
import '../../models/student_graduation_progress.dart';

final studentGraduationProgressMock = StudentGraduationProgress(
  id: 'progress_1',
  academyId: 'academy_1',
  studentId: '1',
  graduationProgramId: 'adult_program_1',
  currentStageId: 'white_belt_degree_2',
  stageStartedAt: DateTime(2026, 4, 1),
  validAttendances: 12,
  stripes: const [
    StripeProgress(color: StripeColor.white, earned: 2, total: 4),
  ],
  estimatedCompletionDate: DateTime(2026, 8, 1),
);
