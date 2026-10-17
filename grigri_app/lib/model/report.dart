// Reports of objectionable content (specs/moderation.md): what a climber
// reports, and what admins see of it in Admin → Reports.

/// What a report is about.
enum ReportKind { profile, plan, message, pic, ad }

/// Why it's reported.
enum ReportReason { spam, harassment, inappropriate, fake, other }

/// What an admin does with a report.
enum ReportAction { dismiss, remove, block }

/// A photo or video in a report's content.
class ReportMedia {
  const ReportMedia(this.key, {this.video = false});

  /// Served at `<site>/photos/<key>`.
  final String key;
  final bool video;
}

/// What was reported, as it was then.
class ReportContent {
  const ReportContent({
    this.title,
    this.text,
    this.media = const [],
    this.link,
  });

  final String? title;
  final String? text;
  final List<ReportMedia> media;
  final String? link;

  static ReportContent fromJson(Object? json) {
    final m = (json as Map?)?.cast<String, Object?>() ?? const {};
    return ReportContent(
      title: m['title'] as String?,
      text: m['text'] as String?,
      link: m['link'] as String?,
      media: [
        for (final e in (m['media'] as List?) ?? const [])
          if (e is Map && e['key'] is String)
            ReportMedia(e['key']! as String, video: e['kind'] == 'video'),
      ],
    );
  }
}

/// An open report, as admins see it (`GET /api/admin/reports`).
class Report {
  const Report({
    required this.id,
    required this.kind,
    required this.targetId,
    required this.subjectId,
    required this.reporterId,
    required this.reason,
    required this.time,
    this.planId,
    this.text = '',
    this.content = const ReportContent(),
  });

  final String id;
  final ReportKind kind;

  /// The profile's climber id, or the plan's, message's, photo's or ad's id.
  final String targetId;

  /// A message's or plan photo's plan.
  final String? planId;

  /// Whose content it is.
  final String subjectId;

  /// Who reported it.
  final String reporterId;
  final ReportReason reason;

  /// The reporter's own words.
  final String text;
  final ReportContent content;
  final DateTime time;

  /// Null for a kind or reason this version of the app doesn't know.
  static Report? fromJson(Map<String, Object?> json) {
    final kind = ReportKind.values.asNameMap()[json['kind']];
    final reason = ReportReason.values.asNameMap()[json['reason']];
    if (kind == null || reason == null) return null;
    return Report(
      id: json['id']! as String,
      kind: kind,
      targetId: json['targetId']! as String,
      planId: json['planId'] as String?,
      subjectId: json['subjectId']! as String,
      reporterId: json['reporterId']! as String,
      reason: reason,
      text: json['text'] as String? ?? '',
      content: ReportContent.fromJson(json['content']),
      time: DateTime.parse(json['time']! as String),
    );
  }
}
