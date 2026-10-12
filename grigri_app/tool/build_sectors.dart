// Builds the sector index (assets/sectors.json) from OpenStreetMap, through
// the public Overpass API: the climbing crags, sectors and gyms of the
// given countries. See specs/sectors.md.
//
//   flutter pub get
//   dart run tool/build_sectors.dart assets/sectors.json ES FR IT PT
//
// It writes the file only when every country came through.
//
// The data is © OpenStreetMap contributors, under the ODbL: the app shows
// the attribution, and the index stays open.
import 'dart:convert';
import 'dart:io';

import 'package:grigri_app/model/sector.dart';

/// Public Overpass servers, tried in order: when one can't be reached or
/// is busy, the next one gets the query.
const overpassServers = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
];
const attribution = '© OpenStreetMap contributors (ODbL)';

Future<void> main(List<String> args) async {
  final countries = args.skip(1).toList();
  if (args.isEmpty ||
      countries.isEmpty ||
      countries.any((c) => !RegExp(r'^[A-Z]{2}$').hasMatch(c))) {
    stderr.writeln(
      'usage: dart run tool/build_sectors.dart assets/sectors.json ES FR …',
    );
    exit(64);
  }
  final sectors = <Sector>[];
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..userAgent = 'grigri-sector-index/1';
  try {
    for (final country in countries) {
      stderr.write('$country… ');
      final response = await _query(client, query(country));
      final found = sectorsFrom(response);
      stderr.writeln('${found.length}');
      // A crag on a border comes with both countries: keep the first.
      final known = {for (final s in sectors) s.id};
      sectors.addAll(found.where((s) => !known.contains(s.id)));
    }
  } finally {
    client.close();
  }
  File(args.first).writeAsStringSync(indexJson(sectors));
  stderr.writeln('${sectors.length} sectors in ${args.first}');
}

/// The Overpass query for one country (an ISO 3166-1 code): the country's
/// name; its climbing places (areas, crags, sectors, boulders and gyms,
/// however they're tagged), but not single routes; and the climbing areas
/// with their members, to tell each sector which crag it's in.
String query(String country) =>
    '''
[out:json][timeout:600];
area["ISO3166-1"="$country"][admin_level=2]->.c;
.c out tags;
(
  nwr["climbing"~"^(area|crag|boulder|gym)\$"]["name"](area.c);
  nwr["sport"="climbing"]["name"][!"climbing"](area.c);
);
out tags;
rel["climbing"="area"](area.c);
out body;
''';

/// [query]'s answer from the first of [overpassServers] that gives one.
Future<Map<String, Object?>> _query(HttpClient client, String query) async {
  final failures = <String>[];
  for (final server in overpassServers) {
    try {
      return await _queryServer(client, Uri.parse(server), query);
    } on Exception catch (e) {
      failures.add('$server: $e');
      stderr.write('(${Uri.parse(server).host} failed, next) ');
    }
  }
  throw HttpException('no Overpass server answered:\n${failures.join('\n')}');
}

Future<Map<String, Object?>> _queryServer(
  HttpClient client,
  Uri server,
  String query,
) async {
  final request = await client.postUrl(server);
  request.headers.contentType = ContentType(
    'application',
    'x-www-form-urlencoded',
    charset: 'utf-8',
  );
  request.write('data=${Uri.encodeQueryComponent(query)}');
  final response = await request.close();
  final body = await response
      .transform(utf8.decoder)
      .join()
      .timeout(const Duration(minutes: 12));
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
    if (type == 'area') continue;
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
  return sectors.values.toList()..sort((a, b) {
    final byName = a.name.compareTo(b.name);
    return byName != 0 ? byName : a.id.compareTo(b.id);
  });
}

/// The index file the app reads (SectorIndex.parse).
String indexJson(List<Sector> sectors) =>
    '${jsonEncode({
      'attribution': attribution,
      'sectors': [for (final s in sectors) s.toRow()],
    })}\n';
