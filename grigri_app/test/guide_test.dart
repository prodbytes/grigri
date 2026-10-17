// The bundled climbing guides (specs/guides.md): complete in English and
// Catalan, their maps bundled, and the area a plan is in.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/guides.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/plan.dart';
import 'package:grigri_app/ui/l10n.dart';
import 'package:grigri_app/ui/plan_guide.dart';

final guides = Guides([
  for (final a in Guides.assets) Guides.parse(File(a).readAsStringSync()),
]);
final guide = guides.guides.single;

void main() {
  group('the Costa Daurada guide', () {
    test('has its 11 areas, numbered as in the guide, each with a point', () {
      expect(guide.areas, hasLength(11));
      expect(
        [for (final a in guide.areas) a.number],
        [for (var i = 1; i <= 11; i++) i],
      );
      expect(guide.areas.map((a) => a.id).toSet(), hasLength(11));
      for (final a in guide.areas) {
        expect(a.lat, isNotNull, reason: a.name);
        expect(a.lon, isNotNull, reason: a.name);
      }
    });

    test('every text is in English and Catalan', () {
      final texts = {
        'title': guide.title,
        'intro': guide.intro,
        'advice': guide.advice,
        for (final a in guide.areas) ...{
          '${a.id}.tagline': a.tagline,
          '${a.id}.intro': a.intro,
          '${a.id}.access': a.access,
          '${a.id}.climbing': a.climbing,
          '${a.id}.rock': a.rock,
          '${a.id}.season': a.season,
          '${a.id}.tips': a.tips,
          '${a.id}.reading': a.reading,
        },
      };
      for (final MapEntry(:key, :value) in texts.entries) {
        expect(value.texts['en'], isNotEmpty, reason: key);
        expect(value.texts['ca'], isNotEmpty, reason: key);
      }
    });

    test('its maps are bundled', () {
      final maps = [guide.map, for (final a in guide.areas) a.accessMap]
        ..removeWhere((m) => m.isEmpty);
      expect(maps, hasLength(5));
      for (final m in maps) {
        expect(File(m).existsSync(), isTrue, reason: m);
      }
    });

    test('a text falls back to English in the languages it lacks', () {
      final siurana = guide.areas.first;
      expect(siurana.rock.of('ca'), 'Calcària.');
      expect(siurana.rock.of('de'), 'Limestone.');
    });

    test("Els Cogullons' Mola Roquerola is closed for nesting, Jan–Jun", () {
      final closure = guide.areas
          .firstWhere((a) => a.id == 'els-cogullons')
          .closures
          .single;
      expect(closure.sector, 'Mola Roquerola');
      expect(closure.covers(DateTime(2026, 1, 1)), isTrue);
      expect(closure.covers(DateTime(2026, 6, 30)), isTrue);
      expect(closure.covers(DateTime(2026, 7, 1)), isFalse);
      expect(closure.covers(DateTime(2026, 12, 31)), isFalse);
    });
  });

  group('the area a place is in', () {
    String? at({
      double? lat,
      double? lon,
      String place = '',
      String area = '',
    }) => guides.areaFor(lat: lat, lon: lon, place: place, area: area)?.area.id;

    test('by its point: the nearest area that reaches it', () {
      expect(at(lat: 41.2577, lon: 0.9318), 'siurana');
      // El Falcó: 0.9 km from Arbolí, 1.9 km from Siurana.
      expect(at(lat: 41.25079, lon: 0.94491), 'arboli');
      expect(at(lat: 41.29722, lon: 0.77505), 'margalef');
      expect(at(lat: 41.32034, lon: 1.0653), 'els-cogullons');
    });

    test('by its point: none when no area reaches it', () {
      expect(at(lat: 41.5933, lon: 1.8375), isNull); // Montserrat
      expect(at(lat: 41.3975, lon: 2.1915), isNull); // Barcelona
    });

    test('without a point: by the area named in its place or area', () {
      expect(at(place: 'El Pati', area: 'Siurana, Spain'), 'siurana');
      expect(at(place: 'Montsant'), 'montsant');
      expect(at(place: 'La Riba'), 'la-riba');
      expect(at(place: 'Arboli'), 'arboli');
    });

    test('without a point: by a sector the guide names', () {
      expect(at(place: 'Fraguerau'), 'ulldemolins');
      expect(at(place: 'mola roquerola'), 'els-cogullons');
    });

    test('without a point: none for a place the guide lacks', () {
      expect(at(place: 'Montserrat', area: 'Catalonia'), isNull);
      expect(at(), isNull);
    });
  });

  group('on the plan screen', () {
    Widget app(Widget child, {Locale locale = const Locale('en')}) =>
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ListView(children: [child])),
        );
    Plan plan({String place = 'Can Torxa', double? lat, double? lon}) => Plan(
      id: 'p1',
      organizerId: 'c1',
      discipline: Discipline.sport,
      place: place,
      grades: const GradeRange(GradeScale.routes, 6, 12),
      memberIds: const ['c1'],
      area: 'Margalef, Spain',
      lat: lat,
      lon: lon,
    );

    testWidgets("shows the area's guide card, which opens its page", (
      tester,
    ) async {
      await tester.pumpWidget(
        app(PlanGuideSection(plan: plan(), guides: guides)),
      );
      await tester.pumpAndSettle();
      expect(find.text('AREA GUIDE'), findsOneWidget);
      expect(find.text('Margalef'), findsOneWidget);
      expect(find.text('Conglomerate and limestone'), findsOneWidget);

      await tester.tap(find.text('Margalef'));
      await tester.pumpAndSettle();
      expect(find.byType(GuideAreaScreen), findsOneWidget);
      expect(find.text('ACCESS'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Tomàtic'), 300);
      expect(find.text('7a+'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Patronat de Turisme'),
        300,
      );

      await tester.scrollUntilVisible(find.text('The whole guide'), 200);
      await tester.ensureVisible(find.text('The whole guide'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('The whole guide'));
      await tester.pumpAndSettle();
      expect(find.byType(GuideScreen), findsOneWidget);
      expect(find.text('Siurana'), findsOneWidget);
      await tester.scrollUntilVisible(find.text("L'Hospitalet"), 300);
      await tester.scrollUntilVisible(find.text('Canoa & Kaiak Siurana'), 300);
    });

    testWidgets('in Catalan, shows the guide in Catalan', (tester) async {
      await tester.pumpWidget(
        app(
          PlanGuideSection(plan: plan(), guides: guides),
          locale: const Locale('ca'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GUIA DE LA ZONA'), findsOneWidget);
      expect(find.text('Conglomerada amb calcària'), findsOneWidget);
    });

    testWidgets('shows nothing for a place no guide covers', (tester) async {
      await tester.pumpWidget(
        app(
          PlanGuideSection(
            plan: plan(place: 'Montserrat', lat: 41.5933, lon: 1.8375),
            guides: guides,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AREA GUIDE'), findsNothing);
    });
  });
}
