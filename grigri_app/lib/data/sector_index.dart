import 'dart:convert';

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

  static Future<SectorIndex>? _loading;

  /// The bundled index, read once.
  static Future<SectorIndex> load([AssetBundle? bundle]) => _loading ??=
      (bundle ?? rootBundle).loadString(asset).then((json) => parse(json));

  /// An index file: `{"attribution": …, "sectors": [[id, name, area,
  /// country], …]}`.
  static SectorIndex parse(String json) {
    final map = (jsonDecode(json) as Map).cast<String, Object?>();
    return SectorIndex([
      for (final row in map['sectors']! as List) Sector.fromRow(row as List),
    ], attribution: map['attribution'] as String? ?? '');
  }

  /// The sectors matching [query], best first: every word of the query
  /// starts a word of the sector's name or where it is, ignoring case and
  /// accents. Names that start with the query come first, then names
  /// that contain its words, then the ones that match on where they are.
  List<Sector> search(String query, {int limit = 20}) {
    final q = fold(query).trim();
    if (q.isEmpty) return const [];
    final words = q.split(spaces);
    final ranked = <(int, Sector)>[];
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
      ranked.add((rank, e.sector));
    }
    ranked.sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      if (byRank != 0) return byRank;
      final byLength = a.$2.name.length.compareTo(b.$2.name.length);
      return byLength != 0 ? byLength : a.$2.name.compareTo(b.$2.name);
    });
    return [for (final r in ranked.take(limit)) r.$2];
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
