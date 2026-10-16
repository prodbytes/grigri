/// How likely a climber and a plan end in a match, from the API's match
/// model (aityx; specs/match-scores.md). Admins only see them.
class MatchScore {
  const MatchScore({
    required this.score,
    required this.level,
    required this.reason,
  });

  /// 0 to 1.
  final double score;
  final MatchLevel level;

  /// The main reason, the first that applies.
  final MatchReason reason;

  /// Whole percent, 0 to 100.
  int get percent => (score * 100).round().clamp(0, 100);

  /// Null for anything the app doesn't know (a newer model's level or
  /// reason): no score rather than a wrong one.
  static MatchScore? fromJson(Map<String, Object?> json) {
    final score = json['score'];
    final level = MatchLevel.values.asNameMap()[_camel(json['level'])];
    final reason = MatchReason.values.asNameMap()[_camel(json['reason'])];
    if (score is! num || level == null || reason == null) return null;
    return MatchScore(score: score.toDouble(), level: level, reason: reason);
  }

  /// The API's snake_case names as the enums' camelCase.
  static String? _camel(Object? v) => v is String
      ? v.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase())
      : null;
}

enum MatchLevel { longShot, possible, good, great }

enum MatchReason {
  otherDiscipline,
  tooHard,
  tooEasy,
  startsSoon,
  far,
  bigGroup,
  crowded,
  inGradesNearby,
  inGrades,
  closeGrades,
}

/// One climber's score for one plan, from a scoring run.
class ScoredPair {
  const ScoredPair({
    required this.climberId,
    required this.planId,
    required this.match,
  });

  final String climberId;
  final String planId;
  final MatchScore match;
}

/// What the latest scoring run did (`GET /api/admin/scores`).
class ScoreRun {
  const ScoreRun({
    required this.finishedAt,
    required this.climbers,
    required this.plans,
    required this.pairs,
    required this.scored,
    required this.failed,
    required this.skipped,
  });

  final DateTime finishedAt;
  final int climbers;
  final int plans;
  final int pairs;
  final int scored;
  final int failed;
  final int skipped;

  static ScoreRun? fromJson(Object? v) {
    if (v is! Map) return null;
    final at = DateTime.tryParse('${v['finishedAt']}');
    if (at == null) return null;
    int n(String k) => (v[k] as num?)?.toInt() ?? 0;
    return ScoreRun(
      finishedAt: at,
      climbers: n('climbers'),
      plans: n('plans'),
      pairs: n('pairs'),
      scored: n('scored'),
      failed: n('failed'),
      skipped: n('skipped'),
    );
  }
}
