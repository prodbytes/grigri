/// A named point on the map: a crag, a gym or a town. A profile's
/// location and areas are these, and so is a plan's place when it was
/// picked from the sector index.
class Location {
  const Location({required this.name, required this.lat, required this.lon});

  /// "El Pati, Siurana, Spain".
  final String name;
  final double lat;
  final double lon;

  Map<String, Object> toJson() => {'name': name, 'lat': lat, 'lon': lon};

  static Location fromJson(Map<String, Object?> json) => Location(
    name: json['name']! as String,
    lat: (json['lat']! as num).toDouble(),
    lon: (json['lon']! as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is Location &&
      other.name == name &&
      other.lat == lat &&
      other.lon == lon;

  @override
  int get hashCode => Object.hash(name, lat, lon);
}
