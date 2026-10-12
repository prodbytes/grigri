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
          'tags': {'climbing': 'crag', 'name': 'Pared Gris'},
        },
        {
          'type': 'way',
          'id': 12,
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
        ['osm:n11', 'Pared Gris', 'Valle Alto', 'Spain'],
        // The area can be picked too; the crag named like it isn't said
        // to be in itself.
        ['osm:r15', 'Valle Alto', '', 'Spain'],
        ['osm:w12', 'Valle Alto', '', 'Spain'],
      ],
    );
    final again = SectorIndex.parse(build.indexJson(sectors));
    expect(again.length, 4);
    expect(again.attribution, contains('OpenStreetMap'));
    expect(build.query('ES'), contains('"ISO3166-1"="ES"'));
  });
}
