import 'location.dart';

/// A climbing sector, crag or gym in the sector index: what a plan's
/// "where", and a profile's location and areas, pick from.
class Sector {
  const Sector({
    required this.id,
    required this.name,
    this.area = '',
    this.country = '',
    this.lat,
    this.lon,
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

  /// Where it is on the map; null when the index doesn't say.
  final double? lat;
  final double? lon;

  /// "Siurana, Spain".
  String get where => [area, country].where((s) => s.isNotEmpty).join(', ');

  /// "El Pati, Siurana, Spain".
  String get fullName => [name, where].where((s) => s.isNotEmpty).join(', ');

  /// As a profile's location or area; null without a point.
  Location? get location => lat == null || lon == null
      ? null
      : Location(name: fullName, lat: lat!, lon: lon!);

  /// One row of the index file: `[id, name, area, country, lat, lon]`
  /// (the point left out when unknown).
  List<Object> toRow() => [
    id,
    name,
    area,
    country,
    if (lat != null && lon != null) ...[lat!, lon!],
  ];

  static Sector fromRow(List<Object?> row) => Sector(
    id: row[0]! as String,
    name: row[1]! as String,
    area: row.length > 2 ? row[2] as String? ?? '' : '',
    country: row.length > 3 ? row[3] as String? ?? '' : '',
    lat: row.length > 5 ? (row[4] as num?)?.toDouble() : null,
    lon: row.length > 5 ? (row[5] as num?)?.toDouble() : null,
  );
}
