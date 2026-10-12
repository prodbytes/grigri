import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/config.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/http_api.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/plan.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';

final site = Uri.parse('https://grigri.test');

const planJson = {
  'id': 'p1',
  'organizerId': 'robin',
  'discipline': 'sport',
  'place': 'Grey Cliffs',
  'area': 'Northvale, Nowhere',
  'start': '2026-10-17T07:00:00.000Z',
  'end': '2026-10-17T14:00:00.000Z',
  'grades': {'scale': 'routes', 'min': 6, 'max': 12},
  'memberIds': ['robin'],
  'notes': '',
};

const robinJson = {
  'id': 'robin',
  'name': 'Robin Vale',
  'bio': '',
  'levels': {
    // The old scale name is still read.
    'sport': {'scale': 'french', 'min': 10, 'max': 16},
  },
  'gear': ['rope', 'jetpack'],
  'gearPhotos': ['robin/gear-1'],
};

/// An HttpGrigriApi whose server is [handler]; [seen] collects requests.
HttpGrigriApi apiWith(
  Future<http.Response> Function(http.Request request) handler, {
  List<http.Request>? seen,
  Map<String, String> headers = const {'Authorization': 'Bearer t0ken'},
}) => HttpGrigriApi(
  origin: site,
  headers: () async => headers,
  client: MockClient((request) {
    seen?.add(request);
    return handler(request);
  }),
);

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('HttpGrigriApi', () {
    test(
      'calls <site>/api with the bearer token, and reads the shapes',
      () async {
        final seen = <http.Request>[];
        final api = apiWith(
          (_) async => json({
            'plans': [planJson],
            'climbers': {'robin': robinJson},
          }),
          seen: seen,
        );
        final list = await api.discover();
        expect(seen.single.method, 'GET');
        expect(seen.single.url.toString(), 'https://grigri.test/api/discover');
        expect(seen.single.headers['Authorization'], 'Bearer t0ken');
        final plan = list.plans.single;
        expect(plan.discipline, Discipline.sport);
        expect(plan.grades, const GradeRange(GradeScale.routes, 6, 12));
        expect(plan.start, DateTime.utc(2026, 10, 17, 7).toLocal());
        final robin = list.climbers['robin']!;
        expect(
          robin.levels[Discipline.sport]!.label(GradeSystem.european),
          '6c–7c',
        );
        expect(
          robin.levels[Discipline.sport]!.label(GradeSystem.american),
          '5.11b–5.12d',
        );
        // Gear this version doesn't know is skipped.
        expect(robin.gear, {Gear.rope});
        expect(robin.gearPhotos, ['robin/gear-1']);
        expect(robin.age, isNull);
      },
    );

    test(
      'sends plans without id, organizer and members, dates in UTC',
      () async {
        final seen = <http.Request>[];
        final api = apiWith((_) async => json({'plan': planJson}), seen: seen);
        final draft = Plan.fromJson(planJson);
        await api.createPlan(draft);
        final body = jsonDecode(seen.single.body) as Map;
        expect(seen.single.url.path, '/api/plans');
        expect(
          seen.single.headers['Content-Type'],
          startsWith('application/json'),
        );
        expect(body.containsKey('id'), isFalse);
        expect(body.containsKey('organizerId'), isFalse);
        expect(body.containsKey('memberIds'), isFalse);
        expect(body['start'], '2026-10-17T07:00:00.000Z');
        expect(body['end'], '2026-10-17T14:00:00.000Z');
        expect(body.containsKey('title'), isFalse);
        expect(body.containsKey('spots'), isFalse);
        expect(body.containsKey('sectorId'), isFalse);
      },
    );

    test('names requests by plan and climber, and reads a match', () async {
      final seen = <http.Request>[];
      final api = apiWith(
        (_) async => json({
          'match': {'plan': planJson, 'newcomerId': 'pat'},
        }),
        seen: seen,
      );
      final match = await api.accept('p1', 'pat');
      expect(seen.single.method, 'POST');
      expect(seen.single.url.path, '/api/requests/p1/pat/accept');
      expect(match!.newcomerId, 'pat');
      expect(match.plan.id, 'p1');

      await api.adminReject('p1', 'pat');
      expect(seen.last.url.path, '/api/admin/requests/p1/pat/reject');
    });

    test('polls messages after a time', () async {
      final seen = <http.Request>[];
      final api = apiWith(
        (_) async => json({'messages': [], 'climbers': {}}),
        seen: seen,
      );
      await api.messages('p1', after: DateTime.utc(2026, 10, 12, 10, 0, 0, 5));
      expect(seen.single.url.path, '/api/plans/p1/messages');
      expect(
        seen.single.url.queryParameters['after'],
        '2026-10-12T10:00:00.005Z',
      );
    });

    test('an error carries the server\'s message and status', () async {
      final api = apiWith(
        (_) async => json({'error': 'That plan is full.'}, 409),
      );
      await expectLater(
        api.join('p1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', 'That plan is full.'),
        ),
      );
      final noProfile = apiWith(
        (_) async => json({'error': 'no profile'}, 409),
      );
      await expectLater(
        noProfile.requests(),
        throwsA(
          isA<ApiException>().having((e) => e.noProfile, 'no profile', true),
        ),
      );
    });

    test('a server that can\'t be reached is an error too', () async {
      final api = apiWith((_) async => throw http.ClientException('offline'));
      await expectLater(
        api.me(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 0)),
      );
    });

    test(
      'starts a session with the Google ID token, without a bearer',
      () async {
        final seen = <http.Request>[];
        final api = apiWith(
          (_) async => json({'token': 's3ssion', 'expiresAt': '2027-10-12'}),
          seen: seen,
        );
        expect(await api.createSession(idToken: 'id-t0ken'), 's3ssion');
        expect(seen.single.method, 'POST');
        expect(seen.single.url.toString(), 'https://grigri.test/api/session');
        expect(jsonDecode(seen.single.body), {'idToken': 'id-t0ken'});
        expect(seen.single.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('the dev mode starts a session with an email', () async {
      final seen = <http.Request>[];
      final api = apiWith((_) async => json({'token': 's3ssion'}), seen: seen);
      await api.createSession(devUser: 'pat@example.com');
      expect(jsonDecode(seen.single.body), {'devUser': 'pat@example.com'});
      expect(seen.single.headers.containsKey('X-Grigri-Dev-User'), isFalse);
    });

    test('a refused session start is a 401', () async {
      final api = apiWith((_) async => json({'error': 'signed out'}, 401));
      await expectLater(
        api.createSession(idToken: 'bad'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    });

    test('signs out with the session it ends', () async {
      final seen = <http.Request>[];
      final api = apiWith((_) async => json({}), seen: seen);
      await api.deleteSession('s3ssion');
      await api.deleteSessions('s3ssion');
      expect(seen.map((r) => '${r.method} ${r.url.path}'), [
        'DELETE /api/session',
        'DELETE /api/sessions',
      ]);
      for (final r in seen) {
        expect(r.headers['Authorization'], 'Bearer s3ssion');
      }
    });

    test('photos: a presigned POST with its fields, then the file', () async {
      final seen = <http.Request>[];
      final client = MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/api/photos') {
          return json({
            'key': 'pat/profile-1',
            'url': 'https://bucket.test/',
            'fields': {'key': 'pat/profile-1', 'Policy': 'made-up'},
          });
        }
        return http.Response('', 204);
      });
      final api = HttpGrigriApi(
        origin: site,
        headers: () async => {'Authorization': 'Bearer t0ken'},
        client: client,
      );
      final upload = await api.newPhoto(PhotoKind.profile, 'image/png');
      expect(jsonDecode(seen.first.body), {
        'kind': 'profile',
        'contentType': 'image/png',
      });
      await api.uploadPhoto(upload, png);
      final post = seen.last;
      expect(post.url.toString(), 'https://bucket.test/');
      expect(post.headers.containsKey('Authorization'), isFalse);
      final body = latin1.decode(post.bodyBytes);
      // The fields first, then the file.
      expect(body.indexOf('name="key"'), lessThan(body.indexOf('name="file"')));
      expect(
        body.indexOf('name="Policy"'),
        lessThan(body.indexOf('name="file"')),
      );
      expect(
        api.photoUrl('pat/profile-1').toString(),
        'https://grigri.test/photos/pat/profile-1',
      );
    });
  });

  group('config', () {
    test('the web uses its own origin; apps their stage\'s site', () {
      expect(
        AppConfig.resolveOrigin(
          apiUrl: '',
          stage: 'prod',
          web: true,
          page: Uri.parse('https://grigri.nu01.com/app/#/x'),
        ).toString(),
        'https://grigri.nu01.com',
      );
      expect(
        AppConfig.resolveOrigin(
          apiUrl: '',
          stage: 'prod',
          web: false,
        ).toString(),
        'https://grigri.nu01.com',
      );
      expect(
        AppConfig.resolveOrigin(apiUrl: '', stage: 'rc', web: false).toString(),
        'https://rc.grigri.nu01.com',
      );
      expect(
        AppConfig.resolveOrigin(apiUrl: '', stage: '', web: false).toString(),
        'https://rc.grigri.nu01.com',
      );
      expect(
        AppConfig.resolveOrigin(
          apiUrl: 'http://10.0.2.2:4566/api',
          stage: '',
          web: false,
        ).toString(),
        'http://10.0.2.2:4566',
      );
    });

    test('the dev sign-in is only for local builds without a client ID', () {
      final local = Uri.parse('https://localhost:7189');
      bool dev(String stage, String id, Uri origin) =>
          AppConfig.isDevSignIn(stage: stage, webClientId: id, origin: origin);
      expect(dev('', '', local), isTrue);
      expect(dev('local', '', local), isTrue);
      expect(dev('', 'web-id.apps.googleusercontent.com', local), isFalse);
      expect(dev('rc', '', local), isFalse);
      expect(dev('prod', '', local), isFalse);
      expect(dev('', '', Uri.parse('https://rc.grigri.nu01.com')), isFalse);
      expect(dev('', '', Uri.parse('https://grigri.nu01.com')), isFalse);
    });
  });

  test('photo types come from the bytes', () {
    expect(photoContentType(png), 'image/png');
    expect(
      photoContentType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])),
      'image/jpeg',
    );
    expect(
      photoContentType(
        Uint8List.fromList([
          ...'RIFF'.codeUnits,
          0,
          0,
          0,
          0,
          ...'WEBP'.codeUnits,
        ]),
      ),
      'image/webp',
    );
    expect(photoContentType(Uint8List.fromList([1, 2, 3])), isNull);
  });

  group('store', () {
    test('signed in without a profile, it asks for one first', () async {
      final store = storeFor(sampleApi(profile: false));
      await store.start();
      expect(store.phase, Phase.needsProfile);
    });

    test('loads everything once signed in', () async {
      final store = storeFor(sampleApi());
      await store.start();
      expect(store.phase, Phase.ready);
      expect(store.discover.map((p) => p.id), ['boulder-night', 'crag-day']);
      expect(store.myPlans.map((p) => p.id), ['my-gym']);
      expect(store.toReview.map((r) => r.id), ['my-gym/jules']);
      expect(store.unreadNotices, 1);
      expect(store.admin, isFalse);
    });

    test('a declined request shows until I dismiss it', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      await store.like('crag-day');
      expect(store.waiting.map((r) => r.planId), ['crag-day']);
      api.requestsById['crag-day/me'] = api.requestsById['crag-day/me']!
          .copyWith(rejected: true);
      await store.refreshPlans();
      expect(store.declined.map((r) => r.planId), ['crag-day']);
      await store.dismiss(store.declined.single);
      expect(store.declined, isEmpty);
      expect(api.calls, contains('POST /api/requests/crag-day/me/dismiss'));
    });

    test('a group\'s yes is announced once', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      final matches = <Match>[];
      store.matches.listen(matches.add);
      await store.like('crag-day');
      api.acceptAs('robin', 'crag-day', 'me');
      await store.refreshNotices();
      await store.refreshNotices();
      await Future<void>.delayed(Duration.zero);
      expect(matches.map((m) => m.plan.id), ['crag-day']);
      expect(matches.single.newcomer.id, 'me');
    });

    test('a 409 "no profile" goes back to creating one', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      api.failNext = const ApiException(409, 'no profile');
      await store.refreshDiscover();
      expect(store.phase, Phase.needsProfile);
    });

    test('signing out forgets everything', () async {
      final store = storeFor(sampleApi());
      await store.start();
      await store.signOut();
      expect(store.phase, Phase.signedOut);
      expect(store.myPlans, isEmpty);
      expect(store.notices, isEmpty);
    });
  });
}
