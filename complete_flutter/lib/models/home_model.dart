import 'material_model.dart';

// ── Streak ────────────────────────────────────────────────────────────────────

class StreakModel {
  final int currentStreak;
  final int longestStreak;

  const StreakModel({
    required this.currentStreak,
    required this.longestStreak,
  });

  factory StreakModel.fromJson(Map<String, dynamic> j) => StreakModel(
        currentStreak: j['current_streak'] ?? 0,
        longestStreak: j['longest_streak'] ?? 0,
      );

  /// Contextual motivational message based on the current streak length.
  String get motivationalMessage {
    if (currentStreak == 0) return 'Start your streak today!';
    if (currentStreak == 1) return 'Great start — keep going!';
    if (currentStreak < 4)  return 'Consistency beats cramming.';
    if (currentStreak < 7)  return 'Small daily progress matters.';
    if (currentStreak < 14) return 'Keep your streak alive!';
    if (currentStreak < 30) return 'You\'re on fire! 🔥';
    return 'Incredible dedication! 🏆';
  }
}

// ── Quote ─────────────────────────────────────────────────────────────────────

class QuoteModel {
  final int id;
  final String quoteText;
  final String? author;

  const QuoteModel({
    required this.id,
    required this.quoteText,
    this.author,
  });

  factory QuoteModel.fromJson(Map<String, dynamic> j) => QuoteModel(
        id: j['id'],
        quoteText: j['quote_text'] ?? '',
        author: j['author'],
      );
}

// ── Aggregated home payload ───────────────────────────────────────────────────

class HomeData {
  final StreakModel streak;
  final QuoteModel? dailyQuote;
  final List<MaterialModel> trendingMaterials;
  final List<MaterialModel> recentlyViewed;
  final int examPrepCount;

  const HomeData({
    required this.streak,
    this.dailyQuote,
    required this.trendingMaterials,
    required this.recentlyViewed,
    required this.examPrepCount,
  });

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        streak: StreakModel.fromJson(j['streak'] ?? {}),
        dailyQuote: j['daily_quote'] != null
            ? QuoteModel.fromJson(j['daily_quote'])
            : null,
        trendingMaterials: (j['trending_materials'] as List? ?? [])
            .map((e) => MaterialModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentlyViewed: (j['recently_viewed'] as List? ?? [])
            .map((e) => MaterialModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        examPrepCount: j['exam_prep_count'] ?? 0,
      );

  /// Returns a copy of this HomeData with only the streak replaced.
  /// Used by HomeProvider.pingStreak() to update the streak without
  /// refetching the entire home payload.
  HomeData copyWithStreak(StreakModel newStreak) => HomeData(
        streak: newStreak,
        dailyQuote: dailyQuote,
        trendingMaterials: trendingMaterials,
        recentlyViewed: recentlyViewed,
        examPrepCount: examPrepCount,
      );
}
