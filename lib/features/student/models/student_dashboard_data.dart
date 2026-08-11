class StudentDashboardData {
  final int monthlyTrainings;
  final int monthlyGoal;

  final int streak;

  final String nextAchievement;
  final double achievementProgress;

  final String nextTraining;
  final String teacherName;

  final String quote;

  const StudentDashboardData({
    this.monthlyTrainings = 0,
    this.monthlyGoal = 12,
    this.streak = 0,
    this.nextAchievement = '',
    this.achievementProgress = 0,
    this.nextTraining = '',
    this.teacherName = '',
    this.quote = '',
  });

  double get monthlyProgress {
    if (monthlyGoal <= 0) {
      return 0;
    }

    return (monthlyTrainings / monthlyGoal).clamp(0, 1);
  }
}
