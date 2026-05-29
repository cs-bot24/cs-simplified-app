/// Holds the rating state for a single material.
///
/// Returned by both ApiClient.getMaterialRating() and
/// ApiClient.rateMaterial() so the PDF viewer always has
/// the full picture after any rating action.
class RatingModel {
  /// The current user's own rating (null if they have never rated).
  final int? userRating;

  /// Average across all users, rounded to 1 decimal place.
  final double averageRating;

  /// Total number of users who have rated this material.
  final int totalRatings;

  const RatingModel({
    this.userRating,
    required this.averageRating,
    required this.totalRatings,
  });

  factory RatingModel.fromJson(Map<String, dynamic> j) => RatingModel(
        userRating: j['user_rating'] as int?,
        averageRating: (j['average_rating'] ?? 0.0).toDouble(),
        totalRatings: j['total_ratings'] as int? ?? 0,
      );

  /// Returns a copy with a new userRating — used to update
  /// the local state after a successful submission.
  RatingModel copyWith({int? userRating}) => RatingModel(
        userRating: userRating ?? this.userRating,
        averageRating: averageRating,
        totalRatings: totalRatings,
      );
}
