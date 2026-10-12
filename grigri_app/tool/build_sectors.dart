// Builds the sector index (assets/sectors.json) from OpenStreetMap, through
// the public Overpass API: the climbing crags, sectors and gyms of the
// given countries. See specs/sectors.md.
//
//   dart run tool/build_sectors.dart ES FR IT PT > assets/sectors.json
//
// The data is © OpenStreetMap contributors, under the ODbL: the app shows
// the attribution, and the index stays open.
import 'dart:convert';
import 'dart:io';

import 'package:grigri_app/model/sector.dart';

const overpass = 'https://overpass-api.de/api/interpreter';
const attribution = '© OpenStreetMap contributors (ODbL)';

Future<void> main(List<String> countries) async {
  if (countries.isEmpty ||
      countries.any((c) => !RegExp(r'^[A-Z]{2}$').hasMatch(c))) {
    stderr.writeln('usage: dart run tool/build_sectors.dart ES FR … > out');
    exit(64);
  }
  final sectors = <Sector>[];
  final client = HttpClient();
  try {
    for (final country in countries) {
      stderr.write('$country… ');
      final response = await _query(client, query(country));
      final found = sectorsFrom(response);
      stderr.writeln('${found.length}');
      sectors.addAll(found);
    }
  } finally {
    client.close();
  }
  stdout.write(indexJson(sectors));
}

/// The Overpass query for one country (an ISO 3166-1 code): the country's
/// name, its crags and climbing gyms, and the climbing areas with their
/// members, to tell each sector which crag it's in.
String query(String country) =>
    '''
[out:json][timeout:600];
area["ISO3166-1"="$country"][admin_level=2]->.c;
.c out tags;
(
  nwr["climbing"="crag"](area.c);
  nwr["sport"="climbing"]["leisure"="sports_centre"](area.c);
  nwr["climbing"="gym"](area.c);
);
out tags;
rel["climbing"="area"](area.c);
out body;
''';

Future<Map<String, Object?>> _query(HttpClient client, String query) async {
  final request = await client.postUrl(Uri.parse(overpass));
  request.headers.contentType = ContentType(
    'application',
    'x-www-form-urlencoded',
    charset: 'utf-8',
  );
  request.headers.set('User-Agent', 'grigri-sector-index/1');
  request.write('data=${Uri.encodeQueryComponent(query)}');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw HttpException('Overpass answered ${response.statusCode}: $body');
  }
  return (jsonDecode(body) as Map).cast();
}

/// The sectors in one country's Overpass answer, by name.
List<Sector> sectorsFrom(Map<String, Object?> overpass) {
  final elements = [
    for (final e in overpass['elements']! as List)
      (e as Map).cast<String, Object?>(),
  ];
  Map<String, Object?> tags(Map<String, Object?> e) =>
      (e['tags'] as Map? ?? const {}).cast();
  String? nameOf(Map<String, Object?> e) {
    final t = tags(e);
    final name = (t['name'] ?? t['name:en']) as String?;
    return name == null || name.trim().isEmpty ? null : name.trim();
  }

  var country = '';
  // The area each crag is a member of, by element id ("n123").
  final areaOf = <String, String>{};
  for (final e in elements) {
    final t = tags(e);
    if (e['type'] == 'area') {
      country = (t['name:en'] ?? t['name'] ?? '') as String;
    } else if (e['type'] == 'relation' && t['climbing'] == 'area') {
      final area = nameOf(e);
      if (area == null) continue;
      for (final m in (e['members'] as List? ?? []).cast<Map>()) {
        areaOf['${(m['type'] as String)[0]}${m['ref']}'] = area;
      }
    }
  }

  final sectors = <String, Sector>{};
  for (final e in elements) {
    final t = tags(e);
    final type = e['type'];
    if (type == 'area' || (type == 'relation' && t['climbing'] == 'area')) {
      continue;
    }
    final name = nameOf(e);
    if (name == null) continue;
    final key = '${(type! as String)[0]}${e['id']}';
    final isGym = t['climbing'] == 'gym' || t['leisure'] == 'sports_centre';
    final area = isGym
        ? (t['addr:city'] as String? ?? '')
        : (areaOf[key] ?? t['is_in'] as String? ?? '');
    sectors[key] = Sector(
      id: 'osm:$key',
      name: name,
      area: area == name ? '' : area,
      country: country,
    );
  }
  return sectors.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// The index file the app reads (SectorIndex.parse).
String indexJson(List<Sector> sectors) =>
    '${jsonEncode({
      'attribution': attribution,
      'sectors': [for (final s in sectors) s.toRow()],
    })}\n';
