class LevelModel {
  final int id;
  final String levelName;
  final String emoji;
  final int sortOrder;

  LevelModel({required this.id, required this.levelName,
      required this.emoji, required this.sortOrder});

  factory LevelModel.fromJson(Map<String, dynamic> j) => LevelModel(
    id: j['id'], levelName: j['level_name'],
    emoji: j['emoji'] ?? '🎓', sortOrder: j['sort_order'] ?? 0,
  );
}
