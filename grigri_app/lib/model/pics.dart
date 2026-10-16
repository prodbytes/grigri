/// A photo in a plan's "Your Pics": one a member added, or a photo sent in
/// its chat (specs/pics.md). Served at `<site>/photos/<key>`.
class PlanPic {
  const PlanPic({
    required this.id,
    required this.planId,
    required this.key,
    required this.uploaderId,
    required this.time,
    this.fromChat = false,
  });

  final String id;
  final String planId;
  final String key;

  /// Who added it, or sent it in the chat.
  final String uploaderId;
  final DateTime time;

  /// From the chat: deleting it here leaves the chat's photo.
  final bool fromChat;

  factory PlanPic.fromJson(Map<String, Object?> json) => PlanPic(
    id: json['id']! as String,
    planId: json['planId']! as String,
    key: json['key']! as String,
    uploaderId: json['uploaderId']! as String,
    time: DateTime.parse(json['time']! as String),
    fromChat: json['fromChat'] == true,
  );
}

/// A photo of GriGri Pics, Grigri's own photos of crags, with its credit.
/// Served at `<site>/pics/<key>`.
class GrigriPic {
  const GrigriPic({
    required this.key,
    required this.crag,
    this.width = 0,
    this.height = 0,
    this.caption = '',
    this.author = '',
    this.license = '',
    this.source = '',
  });

  final String key;

  /// The crag (or climbing area) it shows.
  final String crag;
  final int width;
  final int height;
  final String caption;
  final String author;
  final String license;

  /// Where it comes from (its page).
  final String source;

  factory GrigriPic.fromJson(Map<String, Object?> json) => GrigriPic(
    key: json['key']! as String,
    crag: json['crag'] as String? ?? '',
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
    caption: json['caption'] as String? ?? '',
    author: json['author'] as String? ?? '',
    license: json['license'] as String? ?? '',
    source: json['source'] as String? ?? '',
  );
}

/// A plan's photos: its "Your Pics" (only for members) and its GriGri
/// Pics.
class PlanPics {
  const PlanPics({
    this.yours = const [],
    this.grigri = const [],
    this.member = false,
  });

  /// Oldest first.
  final List<PlanPic> yours;
  final List<GrigriPic> grigri;

  /// Whether I'm in the plan (only members see and add "Your Pics").
  final bool member;

  PlanPics copyWith({List<PlanPic>? yours}) =>
      PlanPics(yours: yours ?? this.yours, grigri: grigri, member: member);
}
