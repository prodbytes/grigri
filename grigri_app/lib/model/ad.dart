import 'plan.dart' show MediaKind;

/// Where an ad is in review (specs/ads.md).
enum AdStatus {
  pending,
  approved,
  rejected;

  static AdStatus fromName(Object? name) => switch (name) {
    'approved' => approved,
    'rejected' => rejected,
    _ => pending,
  };
}

/// A Premium climber's ad: a link, with text over a photo or video (or
/// text alone). Shown between plans on the Discover deck once an admin
/// approves it; accepting it opens [link] in the browser.
class Ad {
  const Ad({
    required this.id,
    required this.ownerId,
    required this.text,
    required this.link,
    this.mediaKind,
    this.mediaKey,
    this.status = AdStatus.pending,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String text;
  final Uri link;

  /// The photo or video, when it has one: its kind and photo-store key.
  final MediaKind? mediaKind;
  final String? mediaKey;

  final AdStatus status;
  final DateTime? createdAt;

  /// The link's site, to show: "shop.example.com".
  String get site =>
      link.host.startsWith('www.') ? link.host.substring(4) : link.host;

  static Ad? fromJson(Map<String, Object?> json) {
    final link = Uri.tryParse('${json['link']}');
    if (json['id'] is! String || link == null || !link.hasAuthority) {
      return null;
    }
    final media = json['media'];
    return Ad(
      id: json['id']! as String,
      ownerId: '${json['ownerId']}',
      text: (json['text'] as String?) ?? '',
      link: link,
      mediaKind: media is Map
          ? (media['kind'] == 'video' ? MediaKind.video : MediaKind.image)
          : null,
      mediaKey: media is Map ? media['key'] as String? : null,
      status: AdStatus.fromName(json['status']),
      createdAt: DateTime.tryParse('${json['createdAt']}')?.toLocal(),
    );
  }

  Ad copyWith({AdStatus? status}) => Ad(
    id: id,
    ownerId: ownerId,
    text: text,
    link: link,
    mediaKind: mediaKind,
    mediaKey: mediaKey,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}
