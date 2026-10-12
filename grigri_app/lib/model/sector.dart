/// A climbing sector, crag or gym in the sector index: what a plan's
/// "where" picks from.
class Sector {
  const Sector({
    required this.id,
    required this.name,
    this.area = '',
    this.country = '',
  });

  /// Stable across rebuilds of the index: the OpenStreetMap element, e.g.
  /// "osm:n123456".
  final String id;

  /// "El Pati".
  final String name;

  /// What it's part of: the crag or area for a sector ("Siurana"), the
  /// town for a gym.
  final String area;

  /// "Spain".
  final String country;

  /// "Siurana, Spain".
  String get where => [area, country].where((s) => s.isNotEmpty).join(', ');

  /// One row of the index file: `[id, name, area, country]`.
  List<String> toRow() => [id, name, area, country];

  static Sector fromRow(List<Object?> row) => Sector(
    id: row[0]! as String,
    name: row[1]! as String,
    area: row.length > 2 ? row[2] as String? ?? '' : '',
    country: row.length > 3 ? row[3] as String? ?? '' : '',
  );
}
