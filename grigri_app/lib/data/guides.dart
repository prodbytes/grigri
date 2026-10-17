import 'dart:convert';

import 'package:flutter/services.dart';

import '../model/guide.dart';
import '../model/sector.dart';
import 'sector_index.dart';

/// The climbing guides bundled with the app (specs/guides.md): static
/// files read on the device, so they cost nothing to serve.
class Guides {
  Guides(this.guides);

  static const assets = ['assets/guides/costa-daurada.json'];

  final List<ClimbingGuide> guides;

  static Guides? _loaded;

  /// The bundled guides, read once (the guides themselves are kept, not a
  /// pending load, so a load that never finished is retried).
  static Future<Guides> load([AssetBundle? bundle]) async => _loaded ??= Guides(
    [for (final a in assets) parse(await (bundle ?? rootBundle).loadString(a))],
  );

  static ClimbingGuide parse(String json) =>
      ClimbingGuide.fromJson((jsonDecode(json) as Map).cast());

  /// The guide and area a place is in, or null.
  ///
  /// With a point: the nearest area whose crags reach it ([GuideArea.km]
  /// from its center). Without one: the area named in [place] or [area]
  /// (whole words, ignoring case and accents), or the one whose sectors
  /// include [place].
  ({ClimbingGuide guide, GuideArea area})? areaFor({
    double? lat,
    double? lon,
    String place = '',
    String area = '',
  }) {
    final all = [
      for (final g in guides)
        for (final a in g.areas) (guide: g, area: a),
    ];
    if (lat != null && lon != null) {
      ({ClimbingGuide guide, GuideArea area})? best;
      var bestKm = double.infinity;
      for (final x in all) {
        final a = x.area;
        if (a.lat == null || a.lon == null) continue;
        final km = SectorIndex.distanceKm(
          Sector(id: a.id, name: a.name, lat: a.lat, lon: a.lon),
          (lat: lat, lon: lon),
        )!;
        if (km <= a.km && km < bestKm) {
          best = x;
          bestKm = km;
        }
      }
      return best;
    }
    final words = ' ${_words('$place $area')} ';
    for (final x in all) {
      final names = [x.area.name, ...x.area.aliases];
      if (names.any((n) => words.contains(' ${_words(n)} '))) return x;
    }
    final name = _words(place);
    if (name.isEmpty) return null;
    for (final x in all) {
      if (x.area.sectors.any((s) => _words(s) == name)) return x;
    }
    return null;
  }

  /// Folded and single-spaced: "L'Olla" → "l olla".
  static String _words(String s) =>
      SectorIndex.fold(s)
          .split(SectorIndex.spaces)
          .where((w) => w.isNotEmpty)
          .join(' ');
}
