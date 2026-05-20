class LevelModel {
  final int id;
  final String levelName;
  final String emoji;
  final int sortOrder;

  LevelModel({
    required this.id,
    required this.levelName,
    required this.emoji,
    required this.sortOrder,
  });

  factory LevelModel.fromJson(Map<String, dynamic> json) => LevelModel(
        id: json['id'],
        levelName: json['level_name'],
        emoji: json['emoji'] ?? '🎓',
        sortOrder: json['sort_order'] ?? 0,
      );
}
