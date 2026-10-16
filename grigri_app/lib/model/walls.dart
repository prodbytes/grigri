import 'climbing.dart';

/// A reference photo of a wall (specs/route-finder.md): served at
/// `<site>/photos/<key>`, with its transform to the wall's first view
/// (row-major 3×3; the identity for the first).
class WallView {
  const WallView({
    required this.key,
    required this.width,
    required this.height,
    required this.h,
  });

  final String key;
  final int width;
  final int height;
  final List<double> h;

  factory WallView.fromJson(Map<String, Object?> json) => WallView(
    key: json['key']! as String,
    width: (json['width']! as num).toInt(),
    height: (json['height']! as num).toInt(),
    h: [for (final v in json['h']! as List) (v as num).toDouble()],
  );
}

/// A route on a wall: its bolts from the ground up, in the wall's first
/// view (0..1 of its width and height), and its grade.
class ClimbRoute {
  const ClimbRoute({
    required this.id,
    required this.name,
    required this.scale,
    required this.grade,
    required this.bolts,
    required this.addedBy,
  });

  final String id;
  final String name;
  final GradeScale scale;

  /// An index into [scale]'s grades.
  final int grade;
  final List<(double, double)> bolts;
  final String addedBy;

  String gradeLabel(GradeSystem system) {
    final grades = scale.grades(system);
    return grade >= 0 && grade < grades.length ? grades[grade] : '?';
  }

  static ClimbRoute? fromJson(Map<String, Object?> json) {
    final g = (json['grade'] as Map?)?.cast<String, Object?>();
    final scale = switch (g?['scale']) {
      'routes' => GradeScale.routes,
      'boulders' => GradeScale.boulders,
      _ => null,
    };
    if (scale == null) return null;
    return ClimbRoute(
      id: json['id']! as String,
      name: json['name']! as String,
      scale: scale,
      grade: (g!['grade']! as num).toInt(),
      bolts: [
        for (final p in (json['bolts']! as List).cast<List>())
          ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      addedBy: json['addedBy'] as String? ?? '',
    );
  }
}

/// A rock face the route finder knows: its reference photos and the routes
/// climbers drew on it.
class Wall {
  const Wall({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.views,
    required this.routes,
    this.cragId,
  });

  final String id;
  final String name;
  final String? cragId;
  final double lat;
  final double lon;

  /// The first is the one routes are drawn on.
  final List<WallView> views;
  final List<ClimbRoute> routes;

  WallView get base => views.first;

  factory Wall.fromJson(Map<String, Object?> json) => Wall(
    id: json['id']! as String,
    name: json['name']! as String,
    cragId: json['cragId'] as String?,
    lat: (json['lat']! as num).toDouble(),
    lon: (json['lon']! as num).toDouble(),
    views: [
      for (final v in json['views']! as List)
        WallView.fromJson((v as Map).cast()),
    ],
    routes: [
      for (final r in json['routes']! as List)
        ?ClimbRoute.fromJson((r as Map).cast()),
    ],
  );
}
