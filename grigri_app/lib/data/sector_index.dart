import 'dart:convert';
import 'dart:math' show asin, cos, pi, sin, sqrt;

import 'package:flutter/services.dart';

import '../model/sector.dart';

/// The searchable list of climbing sectors, crags and gyms, searched on the
/// device: no server, see specs/sectors.md. Built from OpenStreetMap by
/// tool/build_sectors.dart into [asset].
class SectorIndex {
  SectorIndex(List<Sector> sectors, {this.attribution = ''})
    : _entries = [for (final s in sectors) _Entry(s)];

  static const asset = 'assets/sectors.json';

  /// Credit the data's license asks for, shown under the search.
  final String attribution;
  final List<_Entry> _entries;

  int get length => _entries.length;

  static SectorIndex? _loaded;

  /// The bundled index, read once it has loaded (the index itself is
  /// kept, not a pending load, so a load that never finished is retried).
  static Future<SectorIndex> load([AssetBundle? bundle]) async =>
      _loaded ??= parse(await (bundle ?? rootBundle).loadString(asset));

  /// An index file: `{"attribution": …, "sectors": [[id, name, area,
  /// country], …]}`.
  static SectorIndex parse(String json) {
    final map = (jsonDecode(json) as Map).cast<String, Object?>();
    return SectorIndex([
      for (final row in map['sectors']! as List) Sector.fromRow(row as List),
    ], attribution: map['attribution'] as String? ?? '');
  }

  /// The sectors matching [query]: every word of the query starts a word
  /// of the sector's name or where it is, ignoring case and accents.
  ///
  /// Without [near]: best matches first: names that start with the query,
  /// then names that contain its words, then the ones that match on where
  /// they are; shorter names first. An empty query finds nothing.
  ///
  /// [near] (where I am): **nearest first**, then as above; places without
  /// a point after every one with one. An empty query gives the nearest
  /// places. At most [limit].
  List<Sector> search(
    String query, {
    int limit = 20,
    ({double lat, double lon})? near,
  }) {
    final q = fold(query).trim();
    if (q.isEmpty) {
      return near == null ? const [] : _nearestFirst(near, limit);
    }
    final words = q.split(spaces);
    final ranked = <(int, double, Sector)>[];
    for (final e in _entries) {
      if (!words.every(
        (w) =>
            e.nameWords.any((a) => a.startsWith(w)) ||
            e.whereWords.any((a) => a.startsWith(w)),
      )) {
        continue;
      }
      final rank = e.name.startsWith(q)
          ? 0
          : words.every((w) => e.nameWords.any((a) => a.startsWith(w)))
          ? 1
          : 2;
      final km = near == null
          ? 0.0
          : (distanceKm(e.sector, near) ?? double.infinity);
      ranked.add((rank, km, e.sector));
    }
    ranked.sort((a, b) {
      final byDistance = a.$2.compareTo(b.$2);
      if (byDistance != 0) return byDistance;
      final byRank = a.$1.compareTo(b.$1);
      if (byRank != 0) return byRank;
      final byLength = a.$3.name.length.compareTo(b.$3.name.length);
      return byLength != 0 ? byLength : a.$3.name.compareTo(b.$3.name);
    });
    return [for (final r in ranked.take(limit)) r.$3];
  }

  /// The [limit] places with a point nearest [near].
  List<Sector> _nearestFirst(({double lat, double lon}) near, int limit) {
    final withPoint = [
      for (final e in _entries)
        if (distanceKm(e.sector, near) case final km?) (km, e.sector),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final p in withPoint.take(limit)) p.$2];
  }

  /// How far a sector is from [from], in km (great circle); null when it
  /// has no point.
  static double? distanceKm(Sector s, ({double lat, double lon}) from) {
    final lat = s.lat, lon = s.lon;
    if (lat == null || lon == null) return null;
    const r = 6371.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(lat - from.lat), dLon = rad(lon - from.lon);
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(from.lat)) * cos(rad(lat)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * asin(sqrt(h.clamp(0.0, 1.0)));
  }

  /// The place with a point closest to [lat], [lon]; null when none has
  /// one. Distances are flat-earth, near enough to pick the closest.
  Sector? nearest(double lat, double lon) {
    final cosLat = cos(lat * pi / 180);
    Sector? best;
    var bestD = double.infinity;
    for (final e in _entries) {
      final s = e.sector;
      if (s.lat == null || s.lon == null) continue;
      final dLat = s.lat! - lat;
      var dLon = (s.lon! - lon).abs();
      if (dLon > 180) dLon = 360 - dLon;
      dLon *= cosLat;
      final d = dLat * dLat + dLon * dLon;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  static final spaces = RegExp(r"[\s,'’()\-/·.]+");

  static const _plain = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
    'ß': 'ss', 'œ': 'oe', 'æ': 'ae', 'ł': 'l', 'š': 's', 'ž': 'z',
    'č': 'c', 'ř': 'r', 'ě': 'e', 'ů': 'u', 'ğ': 'g', 'ş': 's', 'ı': 'i',
  };

  /// [s] in lower case without accents, for matching: "Can Piqué" is
  /// "can pique".
  static String fold(String s) {
    final lower = s.toLowerCase();
    final out = StringBuffer();
    for (final ch in lower.split('')) {
      out.write(_plain[ch] ?? ch);
    }
    return out.toString();
  }
}

/// A sector with its words folded for matching, once.
class _Entry {
  _Entry(this.sector)
    : name = SectorIndex.fold(sector.name),
      nameWords = SectorIndex.fold(sector.name).split(SectorIndex.spaces),
      whereWords = SectorIndex.fold(sector.where).split(SectorIndex.spaces);

  final Sector sector;
  final String name;
  final List<String> nameWords;
  final List<String> whereWords;
}
