import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/sector_index.dart';
import 'package:grigri_app/model/sector.dart';

import '../tool/build_sectors.dart' as build;

// Made-up sectors, not real ones.
final index = SectorIndex(const [
  Sector(id: 'a', name: 'Pared Gris', area: 'Valle Alto', country: 'Spain'),
  Sector(id: 'b', name: 'La Paret', area: 'Valle Alto', country: 'Spain'),
  Sector(id: 'c', name: 'Cova Pàl·lida', area: 'Roca Fosca', country: 'Spain'),
  Sector(id: 'd', name: 'Gris Est', area: 'Les Parets', country: 'France'),
]);

List<String> names(String q) => [for (final s in index.search(q)) s.name];

void main() {
  group('nearest', () {
    // Made-up places.
    final places = SectorIndex(const [
      Sector(id: 'a', name: 'North', lat: 42, lon: 1),
      Sector(id: 'b', name: 'South', lat: 40, lon: 1),
      Sector(id: 'c', name: 'Nowhere'),
      Sector(id: 'd', name: 'Dateline', lat: 0, lon: 179.9),
    ]);

    test('picks the closest place with a point', () {
      expect(places.nearest(41.2, 1.3)?.name, 'North');
      expect(places.nearest(40.4, 0.5)?.name, 'South');
    });

    test('wraps around the antimeridian', () {
      expect(places.nearest(0, -179.9)?.name, 'Dateline');
    });

    test('is null without any point', () {
      expect(
        SectorIndex(const [Sector(id: 'x', name: 'X')]).nearest(0, 0),
        isNull,
      );
    });
  });

  group('search', () {
    test('matches the start of any word, ignoring case and accents', () {
      expect(names('PAL'), ['Cova Pàl·lida']);
      expect(names('gris'), ['Gris Est', 'Pared Gris']);
    });

    test('names starting with the query come first, then where', () {
      // "La Paret" and "Pared Gris" match by name, "Gris Est" by area.
      expect(names('pare'), ['Pared Gris', 'La Paret', 'Gris Est']);
    });

    test('every word must match, the place too', () {
      expect(names('gris valle'), ['Pared Gris']);
      expect(names('gris nowhere'), isEmpty);
      expect(names('   '), isEmpty);
    });

    test('stops at the limit', () {
      expect(index.search('a', limit: 1), hasLength(1));
    });
  });

  test('the bundled index parses and finds the demo crags', () {
    final bundled = SectorIndex.parse(
      File(SectorIndex.asset).readAsStringSync(),
    );
    expect(bundled.search('siurana').first.name, 'Siurana');
    expect(bundled.search('pique').single.where, 'Siurana, Spain');
  });

  test('the build turns an Overpass answer into an index', () {
    final overpass = {
      'elements': [
        {
          'type': 'area',
          'id': 3600000001,
          'tags': {'name': 'España', 'name:en': 'Spain'},
        },
        {
          'type': 'node',
          'id': 11,
          'lat': 41.123456789,
          'lon': 0.5,
          'tags': {'climbing': 'crag', 'name': 'Pared Gris'},
        },
        {
          'type': 'way',
          'id': 12,
          'center': {'lat': 41.2, 'lon': 0.6},
          'tags': {'climbing': 'crag', 'name': 'Valle Alto'},
        },
        {
          'type': 'node',
          'id': 13,
          'tags': {'climbing': 'crag'},
        },
        {
          'type': 'node',
          'id': 14,
          'tags': {
            'leisure': 'sports_centre',
            'sport': 'climbing',
            'name': 'Bloc Club',
            'addr:city': 'Ciudad',
          },
        },
        {
          'type': 'relation',
          'id': 15,
          'tags': {'climbing': 'area', 'name': 'Valle Alto'},
          'members': [
            {'type': 'node', 'ref': 11, 'role': ''},
            {'type': 'way', 'ref': 12, 'role': ''},
          ],
        },
      ],
    };
    final sectors = build.sectorsFrom(overpass);
    expect(
      [for (final s in sectors) s.toRow()],
      [
        ['osm:n14', 'Bloc Club', 'Ciudad', 'Spain'],
        // A node's point, kept to 5 decimals; a way's center.
        ['osm:n11', 'Pared Gris', 'Valle Alto', 'Spain', 41.12346, 0.5],
        // The crag named like its area isn't said to be in itself.
        ['osm:w12', 'Valle Alto', '', 'Spain', 41.2, 0.6],
      ],
    );
    final again = SectorIndex.parse(build.indexJson(sectors));
    expect(again.length, 3);
    expect(
      again.search('pared').single.location?.name,
      'Pared Gris, Valle Alto, Spain',
    );
    expect(again.search('bloc').single.location, isNull);
    expect(build.query('ES'), contains('out center tags'));
    expect(again.attribution, contains('OpenStreetMap'));
    expect(build.query('ES'), contains('"ISO3166-1"="ES"'));
  });
}
