import 'package:flutter/material.dart';

import '../model/match_score.dart';
import '../theme.dart';
import 'common.dart';

extension MatchLevelLabel on MatchLevel {
  String label(AppLocalizations l) => switch (this) {
    MatchLevel.longShot => l.matchLevelLongShot,
    MatchLevel.possible => l.matchLevelPossible,
    MatchLevel.good => l.matchLevelGood,
    MatchLevel.great => l.matchLevelGreat,
  };

  Color get color => switch (this) {
    MatchLevel.longShot => Mountain.clay,
    MatchLevel.possible => Mountain.granite,
    MatchLevel.good => Mountain.sky,
    MatchLevel.great => Mountain.olive,
  };
}

extension MatchReasonLabel on MatchReason {
  String label(AppLocalizations l) => switch (this) {
    MatchReason.otherDiscipline => l.matchReasonOtherDiscipline,
    MatchReason.tooHard => l.matchReasonTooHard,
    MatchReason.tooEasy => l.matchReasonTooEasy,
    MatchReason.startsSoon => l.matchReasonStartsSoon,
    MatchReason.far => l.matchReasonFar,
    MatchReason.bigGroup => l.matchReasonBigGroup,
    MatchReason.crowded => l.matchReasonCrowded,
    MatchReason.inGradesNearby => l.matchReasonInGradesNearby,
    MatchReason.inGrades => l.matchReasonInGrades,
    MatchReason.closeGrades => l.matchReasonCloseGrades,
  };
}

/// A match score (admins only): "Match 72% · good", in its level's color,
/// with its main reason beside it unless [compact].
class MatchScoreTag extends StatelessWidget {
  const MatchScoreTag(this.match, {super.key, this.compact = false});

  final MatchScore match;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tag = Tag(
      l.matchScore(match.percent, match.level.label(l)),
      icon: Icons.insights_outlined,
      color: match.level.color,
    );
    if (compact) return tag;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        tag,
        Text(
          match.reason.label(l),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Mountain.granite),
        ),
      ],
    );
  }
}
