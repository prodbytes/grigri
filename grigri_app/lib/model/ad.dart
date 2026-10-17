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

/// Where an ad shows (specs/ads.md): a place's name and its box on the
/// map, from the place search. The API widens it a little when it picks
/// the deck's ads, so a town reaches the crags around it.
class AdRegion {
  const AdRegion({
    required this.name,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    this.label,
  });

  /// "Siurana, España".
  final String name;
  final double south;
  final double west;
  final double north;
  final double east;

  /// The place's full name, to tell it apart in search results
  /// ("Siurana, Cornudella de Montsant, Priorat, …"); not saved.
  final String? label;

  Map<String, Object> toJson() => {
    'name': name,
    'south': south,
    'west': west,
    'north': north,
    'east': east,
  };

  static AdRegion? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final box = [
      for (final k in ['south', 'west', 'north', 'east']) json[k],
    ];
    if (name is! String || box.any((v) => v is! num)) return null;
    final [south, west, north, east] = [
      for (final v in box) (v! as num).toDouble(),
    ];
    return AdRegion(
      name: name,
      south: south,
      west: west,
      north: north,
      east: east,
      label: json['label'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdRegion &&
      other.name == name &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(name, south, west, north, east);
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
    this.regions = const [],
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

  /// Where it shows; empty: everywhere.
  final List<AdRegion> regions;

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
    final regions = json['regions'];
    return Ad(
      id: json['id']! as String,
      ownerId: '${json['ownerId']}',
      text: (json['text'] as String?) ?? '',
      link: link,
      mediaKind: media is Map
          ? (media['kind'] == 'video' ? MediaKind.video : MediaKind.image)
          : null,
      mediaKey: media is Map ? media['key'] as String? : null,
      regions: [
        if (regions is List)
          for (final r in regions) ?AdRegion.fromJson(r),
      ],
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
    regions: regions,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}
