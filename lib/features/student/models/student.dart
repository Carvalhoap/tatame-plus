class Student {
  final String id;
  final String academyId;

  final String name;
  final DateTime birthDate;
  final String? phone;
  final String? email;
  final String? photoUrl;

  final List<String> classroomIds;
  final List<String> teacherIds;

  final String planId;
  final String agreementId;

  final List<String> guardianIds;

  final int monthlyTrainings;
  final int monthlyGoal;
  final int streak;
  final String nextAchievement;
  final double achievementProgress;
  final String nextTraining;
  final String teacherName;
  final String quote;

  final String currentBelt;
  final String nextBelt;
  final int graduationClassesDone;
  final int graduationClassesRequired;
  final String minimumTime;
  final String estimatedGraduation;

  final bool isActive;

  const Student({
    required this.id,
    required this.academyId,
    required this.name,
    required this.birthDate,
    this.phone,
    this.email,
    this.photoUrl,
    required this.classroomIds,
    required this.teacherIds,
    required this.planId,
    required this.agreementId,
    this.guardianIds = const [],
    this.monthlyTrainings = 0,
    this.monthlyGoal = 12,
    this.streak = 0,
    this.nextAchievement = '',
    this.achievementProgress = 0,
    this.nextTraining = '',
    this.teacherName = '',
    this.quote = '',
    this.currentBelt = '',
    this.nextBelt = '',
    this.graduationClassesDone = 0,
    this.graduationClassesRequired = 1,
    this.minimumTime = '',
    this.estimatedGraduation = '',
    this.isActive = true,
  });
}