class AchievementModel {
  final int id;
  final String title;
  final String description;
  final String icon;
  final String badgeType;   // bronze | silver | gold | platinum
  final String badgeColor;  // hex string from backend
  final String conditionType;
  final int conditionValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int? progressCurrent;
  final int? progressMax;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.badgeType,
    required this.badgeColor,
    required this.conditionType,
    required this.conditionValue,
    required this.isUnlocked,
    this.unlockedAt,
    this.progressCurrent,
    this.progressMax,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> j) => AchievementModel(
        id:               j['id'] as int? ?? 0,
        title:            j['title'] as String? ?? '',
        description:      j['description'] as String? ?? '',
        icon:             j['icon'] as String? ?? '🏅',
        badgeType:        j['badge_type'] as String? ?? 'bronze',
        badgeColor:       j['badge_color'] as String? ?? '#CD7F32',
        conditionType:    j['condition_type'] as String? ?? '',
        conditionValue:   j['condition_value'] as int? ?? 0,
        isUnlocked:       j['is_unlocked'] as bool? ?? false,
        unlockedAt:       j['unlocked_at'] != null
            ? DateTime.tryParse(j['unlocked_at'].toString())
            : null,
        progressCurrent:  j['progress_current'] as int?,
        progressMax:      j['progress_max'] as int?,
      );

  double get progressFraction {
    if (progressCurrent == null || progressMax == null || progressMax == 0) {
      return isUnlocked ? 1.0 : 0.0;
    }
    return (progressCurrent! / progressMax!).clamp(0.0, 1.0);
  }
}
