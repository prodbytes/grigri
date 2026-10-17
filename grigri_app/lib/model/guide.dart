/// A text of a climbing guide in the languages it was written in (English
/// and Catalan for the Costa Daurada guide).
class GuideText {
  const GuideText(this.texts);

  /// By language code: {"en": …, "ca": …}.
  final Map<String, String> texts;

  bool get isEmpty => texts.values.every((t) => t.isEmpty);

  /// The text in [language], else in English, else any.
  String of(String language) {
    final own = texts[language];
    if (own != null && own.isNotEmpty) return own;
    final en = texts['en'];
    if (en != null && en.isNotEmpty) return en;
    return texts.values.firstWhere((t) => t.isNotEmpty, orElse: () => '');
  }

  static GuideText fromJson(Object? json) => GuideText(
    json is Map
        ? {for (final e in json.entries) '${e.key}': '${e.value ?? ''}'}
        : json is String
        ? {'en': json}
        : const {},
  );
}

/// A notable climb a guide names: "Gargamel", "6a".
class GuideClimb {
  const GuideClimb({required this.name, this.grade = '', this.sector = ''});

  final String name;
  final String grade;
  final String sector;

  static GuideClimb fromJson(Map<String, Object?> json) => GuideClimb(
    name: json['name'] as String? ?? '',
    grade: json['grade'] as String? ?? '',
    sector: json['sector'] as String? ?? '',
  );
}

/// A yearly closure: no climbing on [sector] from [from] to [to] (months
/// and days, "01-01" to "06-30"), for [reason].
class GuideClosure {
  const GuideClosure({
    required this.sector,
    required this.from,
    required this.to,
    this.reason = const GuideText({}),
  });

  final String sector;
  final ({int month, int day}) from;
  final ({int month, int day}) to;
  final GuideText reason;

  /// Whether [day] falls in the closure (which may span the new year).
  bool covers(DateTime day) {
    final d = day.month * 100 + day.day;
    final a = from.month * 100 + from.day, b = to.month * 100 + to.day;
    return a <= b ? d >= a && d <= b : d >= a || d <= b;
  }

  static ({int month, int day}) _monthDay(Object? s) {
    final parts = '${s ?? ''}'.split('-');
    return (
      month: int.tryParse(parts.first) ?? 1,
      day: parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1,
    );
  }

  static GuideClosure fromJson(Map<String, Object?> json) => GuideClosure(
    sector: json['sector'] as String? ?? '',
    from: _monthDay(json['from']),
    to: _monthDay(json['to']),
    reason: GuideText.fromJson(json['reason']),
  );
}

/// One climbing area of a guide (Siurana, Margalef…): what it's like, how
/// to get there, the rock, the routes, the season and tips.
class GuideArea {
  const GuideArea({
    required this.id,
    required this.name,
    this.number = 0,
    this.subtitle = '',
    this.aliases = const [],
    this.lat,
    this.lon,
    this.km = 5,
    this.tagline = const GuideText({}),
    this.intro = const GuideText({}),
    this.access = const GuideText({}),
    this.climbing = const GuideText({}),
    this.rock = const GuideText({}),
    this.routes = const GuideText({}),
    this.season = const GuideText({}),
    this.tips = const GuideText({}),
    this.reading = const GuideText({}),
    this.sectors = const [],
    this.climbs = const [],
    this.closures = const [],
    this.accessMap = '',
  });

  final String id;
  final String name;

  /// Its number in the guide (and on its map).
  final int number;

  /// "Siurana de Prades", "Parc Natural".
  final String subtitle;

  /// Other names it goes by ("Montsant" for "El Montsant").
  final List<String> aliases;

  /// Its center, roughly; null when the guide has none.
  final double? lat;
  final double? lon;

  /// How far from [lat], [lon] its crags reach.
  final double km;

  final GuideText tagline;
  final GuideText intro;
  final GuideText access;
  final GuideText climbing;
  final GuideText rock;
  final GuideText routes;
  final GuideText season;
  final GuideText tips;
  final GuideText reading;

  /// The sectors the guide names.
  final List<String> sectors;
  final List<GuideClimb> climbs;
  final List<GuideClosure> closures;

  /// The guide's map of how to reach its sectors: a bundled asset, or ''.
  final String accessMap;

  static GuideArea fromJson(Map<String, Object?> json) => GuideArea(
    id: json['id']! as String,
    name: json['name']! as String,
    number: (json['number'] as num?)?.toInt() ?? 0,
    subtitle: json['subtitle'] as String? ?? '',
    aliases: [for (final a in json['aliases'] as List? ?? const []) '$a'],
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
    km: (json['km'] as num?)?.toDouble() ?? 5,
    tagline: GuideText.fromJson(json['tagline']),
    intro: GuideText.fromJson(json['intro']),
    access: GuideText.fromJson(json['access']),
    climbing: GuideText.fromJson(json['climbing']),
    rock: GuideText.fromJson(json['rock']),
    routes: GuideText.fromJson(json['routes']),
    season: GuideText.fromJson(json['season']),
    tips: GuideText.fromJson(json['tips']),
    reading: GuideText.fromJson(json['reading']),
    sectors: [for (final s in json['sectors'] as List? ?? const []) '$s'],
    climbs: [
      for (final c in json['climbs'] as List? ?? const [])
        GuideClimb.fromJson((c as Map).cast()),
    ],
    closures: [
      for (final c in json['closures'] as List? ?? const [])
        GuideClosure.fromJson((c as Map).cast()),
    ],
    accessMap: json['accessMap'] as String? ?? '',
  );
}

/// A business or club a guide lists: guiding, gear, courses, activities.
class GuideService {
  const GuideService({
    required this.name,
    this.activities = '',
    this.address = '',
    this.phone = '',
    this.web = '',
    this.email = '',
  });

  final String name;
  final String activities;
  final String address;
  final String phone;
  final String web;
  final String email;

  static GuideService fromJson(Map<String, Object?> json) => GuideService(
    name: json['name'] as String? ?? '',
    activities: json['activities'] as String? ?? '',
    address: json['address'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    web: json['web'] as String? ?? '',
    email: json['email'] as String? ?? '',
  );
}

/// A book a guide recommends.
class GuideBook {
  const GuideBook({
    required this.title,
    this.authors = '',
    this.publisher = '',
    this.languages = '',
  });

  final String title;
  final String authors;
  final String publisher;
  final String languages;

  static GuideBook fromJson(Map<String, Object?> json) => GuideBook(
    title: json['title'] as String? ?? '',
    authors: json['authors'] as String? ?? '',
    publisher: json['publisher'] as String? ?? '',
    languages: json['languages'] as String? ?? '',
  );
}

/// A climbing guide to a region (specs/guides.md): its areas, its advice,
/// the services and books it lists, and its credits.
class ClimbingGuide {
  const ClimbingGuide({
    required this.id,
    required this.title,
    this.publisher = '',
    this.year = 0,
    this.map = '',
    this.credits = const {},
    this.intro = const GuideText({}),
    this.areas = const [],
    this.advice = const GuideText({}),
    this.services = const [],
    this.links = const [],
    this.bibliography = const [],
  });

  final String id;
  final GuideText title;
  final String publisher;
  final int year;

  /// The guide's map of its areas: a bundled asset, or ''.
  final String map;

  /// Who did what: {"text": …, "photos": …}.
  final Map<String, String> credits;
  final GuideText intro;
  final List<GuideArea> areas;
  final GuideText advice;
  final List<GuideService> services;

  /// Useful sites: (what it is, its address).
  final List<({GuideText label, String url})> links;
  final List<GuideBook> bibliography;

  static ClimbingGuide fromJson(Map<String, Object?> json) => ClimbingGuide(
    id: json['id']! as String,
    title: GuideText.fromJson(json['title']),
    publisher: json['publisher'] as String? ?? '',
    year: (json['year'] as num?)?.toInt() ?? 0,
    map: json['map'] as String? ?? '',
    credits: {
      for (final e in (json['credits'] as Map? ?? const {}).entries)
        '${e.key}': '${e.value}',
    },
    intro: GuideText.fromJson(json['intro']),
    areas: [
      for (final a in json['areas'] as List? ?? const [])
        GuideArea.fromJson((a as Map).cast()),
    ],
    advice: GuideText.fromJson(json['advice']),
    services: [
      for (final s in json['services'] as List? ?? const [])
        GuideService.fromJson((s as Map).cast()),
    ],
    links: [
      for (final l in json['links'] as List? ?? const [])
        (
          label: GuideText.fromJson((l as Map)['label']),
          url: l['url'] as String? ?? '',
        ),
    ],
    bibliography: [
      for (final b in json['bibliography'] as List? ?? const [])
        GuideBook.fromJson((b as Map).cast()),
    ],
  );
}
