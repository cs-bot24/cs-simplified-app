class LeaderboardEntry {
  final int rank;
  final int userId;
  final String displayName;
  final int currentStreak;
  final int longestStreak;
  final int totalStudyDays;
  final int materialsOpened;
  final int score;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.displayName,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalStudyDays,
    required this.materialsOpened,
    required this.score,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank:           j['rank'] as int? ?? 0,
        userId:         j['user_id'] as int? ?? 0,
        displayName:    j['display_name'] as String? ?? 'Anonymous',
        currentStreak:  j['current_streak'] as int? ?? 0,
        longestStreak:  j['longest_streak'] as int? ?? 0,
        totalStudyDays: j['total_study_days'] as int? ?? 0,
        materialsOpened: j['materials_opened'] as int? ?? 0,
        score:          j['score'] as int? ?? 0,
        isCurrentUser:  j['is_current_user'] as bool? ?? false,
      );
}

class MyLeaderboardStats {
  final int rank;
  final int currentStreak;
  final int longestStreak;
  final int totalStudyDays;
  final int materialsOpened;
  final int score;
  final String mode;

  const MyLeaderboardStats({
    required this.rank,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalStudyDays,
    required this.materialsOpened,
    required this.score,
    required this.mode,
  });

  factory MyLeaderboardStats.fromJson(Map<String, dynamic> j) =>
      MyLeaderboardStats(
        rank:            j['rank'] as int? ?? 0,
        currentStreak:   j['current_streak'] as int? ?? 0,
        longestStreak:   j['longest_streak'] as int? ?? 0,
        totalStudyDays:  j['total_study_days'] as int? ?? 0,
        materialsOpened: j['materials_opened'] as int? ?? 0,
        score:           j['score'] as int? ?? 0,
        mode:            j['mode'] as String? ?? 'all_time',
      );
}

class LeaderboardData {
  final String mode;
  final List<LeaderboardEntry> topUsers;
  final MyLeaderboardStats myStats;

  const LeaderboardData({
    required this.mode,
    required this.topUsers,
    required this.myStats,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> j) => LeaderboardData(
        mode:     j['mode'] as String? ?? 'all_time',
        topUsers: (j['top_users'] as List? ?? [])
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        myStats:  MyLeaderboardStats.fromJson(
            j['my_stats'] as Map<String, dynamic>? ?? {}),
      );
}
