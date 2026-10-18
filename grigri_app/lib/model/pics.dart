import 'dart:math' as math;
import 'dart:ui' show Size;

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

/// A smaller copy of a GriGri Pics photo (specs/pics.md, Sizes), served
/// at `<site>/pics/<key>`: [width] x [height] pixels.
class PicVariant {
  const PicVariant({
    required this.key,
    required this.width,
    required this.height,
  });

  final String key;
  final int width;
  final int height;

  /// The copies in a photo's JSON (`variants`), leaving out any that
  /// aren't well formed; none when there are none.
  static List<PicVariant> listFromJson(Object? json) => [
    if (json is List)
      for (final v in json.whereType<Map<Object?, Object?>>())
        if (v['key'] case final String key)
          if ((v['width'] as num?)?.toInt() case final int width when width > 0)
            if ((v['height'] as num?)?.toInt() case final int height
                when height > 0)
              PicVariant(key: key, width: width, height: height),
  ];
}

/// The key to load for a GriGri Pics photo ([key], with its smaller copies
/// [variants]) filling a [box] of logical pixels, cropped to cover it
/// (`BoxFit.cover`), at [devicePixelRatio], and [zoom]ed in (1: not at
/// all): the narrowest copy whose pixels cover what's shown, else the
/// photo itself. So it looks as sharp as the photo would, and anything
/// unknown (no copies yet, no size) gets the photo.
String picKeyFor(
  String key,
  List<PicVariant> variants, {
  required Size box,
  required double devicePixelRatio,
  double zoom = 1,
}) {
  if (variants.isEmpty ||
      !box.isFinite ||
      box.isEmpty ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return key;
  }
  PicVariant? best;
  for (final v in variants) {
    // Covering the box: the copy's width spans the box's width, or its
    // height the box's height, whichever needs more of it.
    final needed =
        math.max(box.width, box.height * v.width / v.height) *
        devicePixelRatio *
        zoom;
    if (v.width >= needed && (best == null || v.width < best.width)) {
      best = v;
    }
  }
  return best?.key ?? key;
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
    this.variants = const [],
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

  /// Its smaller copies, to show it small ([picKeyFor]); none until the
  /// loader has made them.
  final List<PicVariant> variants;

  factory GrigriPic.fromJson(Map<String, Object?> json) => GrigriPic(
    key: json['key']! as String,
    crag: json['crag'] as String? ?? '',
    width: (json['width'] as num?)?.toInt() ?? 0,
    height: (json['height'] as num?)?.toInt() ?? 0,
    caption: json['caption'] as String? ?? '',
    author: json['author'] as String? ?? '',
    license: json['license'] as String? ?? '',
    source: json['source'] as String? ?? '',
    variants: PicVariant.listFromJson(json['variants']),
  );
}

/// A plan's cover on the Discover deck: its best GriGri Pics photo, the
/// crag it shows and its credit.
class DeckCover {
  const DeckCover({
    required this.key,
    this.crag = '',
    this.author = '',
    this.license = '',
    this.variants = const [],
  });

  final String key;
  final String crag;
  final String author;
  final String license;

  /// The photo's smaller copies ([picKeyFor]).
  final List<PicVariant> variants;

  static DeckCover? fromJson(Object? json) {
    if (json is! Map || json['key'] is! String) return null;
    return DeckCover(
      key: json['key'] as String,
      crag: json['crag'] as String? ?? '',
      author: json['author'] as String? ?? '',
      license: json['license'] as String? ?? '',
      variants: PicVariant.listFromJson(json['variants']),
    );
  }
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
