import '../models/student.dart';
import '../models/student_dashboard_data.dart';

final mockStudent = Student(
  id: '1',
  academyId: 'academy_1',
  userId: 'mock-admin',
  fullName: 'Alexandre',
  birthDate: DateTime(1990, 1, 1),
  phone: '21999999999',
  email: 'alexandre@email.com',
  graduationProgramId: 'adult_program_1',
  jiuJitsuStartDate: DateTime(2024, 1, 1),
  academyJoinDate: DateTime(2024, 1, 1),
  classroomIds: const ['class_1'],
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2026, 8, 11),
  createdBy: 'mock-admin',
);

const mockStudentDashboardData = StudentDashboardData(
  monthlyTrainings: 8,
  monthlyGoal: 12,
  streak: 5,
  nextAchievement: 'Guerreiro de Bronze',
  achievementProgress: 0.82,
  nextTraining: 'Hoje â€¢ 20:30',
  teacherName: 'Professor ThiagÃ£o',
  quote: 'A disciplina vence o talento quando o talento nÃ£o tem disciplina.',
);
