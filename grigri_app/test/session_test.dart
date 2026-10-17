import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/auth.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/http_api.dart';
import 'package:grigri_app/data/session_storage.dart';
import 'package:grigri_app/main.dart';
import 'package:grigri_app/model/pics.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';

FakeGoogle googleOf(GrigriStore store) =>
    (store.auth as SessionAuth).method as FakeGoogle;

Future<GrigriStore> pumpApp(WidgetTester tester, GrigriStore store) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GrigriApp(store: store));
  await store.start();
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('sessions', () {
    test('signing in with Google starts one session and keeps it', () async {
      final api = sampleApi();
      final store = storeFor(api, signedIn: false);
      await store.start();
      expect(store.phase, Phase.signedOut);
      expect(api.calls, isEmpty);

      await store.auth.signIn();
      await store.start();
      expect(api.calls.where((c) => c == 'POST /api/session'), hasLength(1));
      expect(api.sessionBodies.single, {'idToken': 'google-id-token'});
      final token = keptToken(store);
      expect(api.sessions[token], 'pat@example.com');
      expect(await store.auth.headers(), {'Authorization': 'Bearer $token'});
      expect(store.phase, Phase.ready);
      expect(api.calls.skip(1).first, 'GET /api/me');
    });

    test('every call carries the session token, never Google\'s', () async {
      final seen = <http.Request>[];
      late final Auth auth;
      final api = HttpGrigriApi(
        origin: Uri.parse('https://grigri.test'),
        headers: () => auth.headers(),
        client: MockClient((request) async {
          seen.add(request);
          final body = request.url.path == '/api/session'
              ? {'token': 's3ssion', 'expiresAt': '2027-10-12T00:00:00Z'}
              : {'climber': null, 'admin': false};
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final storage = MemorySessionStorage();
      auth = SessionAuth(method: FakeGoogle(), sessions: api, storage: storage);
      await auth.start();
      await auth.signIn();
      await api.me();
      await api.me();
      expect(storage.token, 's3ssion');
      expect(seen.map((r) => r.url.path), [
        '/api/session',
        '/api/me',
        '/api/me',
      ]);
      expect(jsonDecode(seen.first.body), {'idToken': 'google-id-token'});
      for (final r in seen.skip(1)) {
        expect(r.headers['Authorization'], 'Bearer s3ssion');
      }
    });

    test('a kept session starts signed in, without asking Google', () async {
      final api = sampleApi();
      final token = api.openSession('pat@example.com');
      final store = storeFor(api, storage: MemorySessionStorage(token));
      await store.start();
      expect(store.phase, Phase.ready);
      expect(api.calls.first, 'GET /api/me');
      expect(api.calls, isNot(contains('POST /api/session')));
      expect(await store.auth.headers(), {'Authorization': 'Bearer $token'});
    });

    test('a 401 forgets the session and signs out', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      final errors = <String>[];
      store.errors.listen(errors.add);
      // The session ended on the server (a year unused, or signed out
      // everywhere).
      api.sessions.clear();
      await store.refreshDiscover();
      await Future<void>.delayed(Duration.zero);
      expect(store.phase, Phase.signedOut);
      expect(keptToken(store), isNull);
      expect(await store.auth.headers(), isEmpty);
      expect(googleOf(store).signOuts, 1);
      expect(errors, ['Signed out: please sign in again.']);
    });

    test('signing out ends the session on the server and here', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      final token = keptToken(store)!;
      await store.signOut();
      expect(api.calls.last, 'DELETE /api/session');
      expect(api.sessions, isNot(contains(token)));
      expect(keptToken(store), isNull);
      expect(store.phase, Phase.signedOut);
      expect(googleOf(store).signOuts, 1);
    });

    test('signing out works even when the server can\'t be told', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      api.sessions.clear();
      await store.signOut();
      expect(keptToken(store), isNull);
      expect(store.phase, Phase.signedOut);
    });

    test('signing out everywhere ends all my sessions', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      api.openSession('pat@example.com'); // another phone
      final other = api.openSession('kit@example.com');
      await store.signOutEverywhere();
      expect(api.calls.last, 'DELETE /api/sessions');
      expect(api.sessions.keys, [other]);
      expect(keptToken(store), isNull);
      expect(store.phase, Phase.signedOut);
    });

    test('signing out everywhere that fails stays signed in', () async {
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      final errors = <String>[];
      store.errors.listen(errors.add);
      api.failNext = const ApiException(0, 'Couldn\'t reach the server.');
      await store.signOutEverywhere();
      await Future<void>.delayed(Duration.zero);
      expect(store.phase, Phase.ready);
      expect(keptToken(store), isNotNull);
      expect(errors, ['Couldn\'t sign out everywhere. Try again.']);
    });

    test('a build without a Google client ID still offers Google, '
        'and signing in fails', () async {
      final api = sampleApi();
      final auth = SessionAuth(
        method: GoogleSignInMethod(webClientId: ''),
        sessions: api,
        storage: MemorySessionStorage(),
      );
      await auth.start();
      expect(auth.mode, SignInMode.google);
      await auth.signIn();
      expect(auth.signedIn, isFalse);
      expect(auth.error, SignInError.google);
      expect(api.calls, isNot(contains('POST /api/session')));
    });

    test('a refused session start shows an error and keeps nothing', () async {
      final api = sampleApi();
      final store = storeFor(api, signedIn: false);
      await store.start();
      api.failNext = const ApiException(401, 'signed out');
      await store.auth.signIn();
      expect(store.auth.signedIn, isFalse);
      expect(store.auth.error, SignInError.session);
      expect(keptToken(store), isNull);
      expect(store.phase, Phase.signedOut);
    });
  });

  group('Sign in with Apple', () {
    test('trades Apple\'s token, nonce, code and name for a session', () async {
      final api = sampleApi();
      final apple = FakeApple();
      final store = storeFor(api, signedIn: false, apple: apple);
      await store.start();
      expect(store.auth.appleAvailable, isTrue);
      await store.auth.signInWithApple();
      await store.start();
      expect(api.sessionBodies.single, {
        'appleIdToken': 'apple-id-token',
        'nonce': 'made-up-nonce-0123456789',
        'authorizationCode': 'made-up-code',
        'name': 'Pat Quill',
      });
      expect(keptToken(store), isNotNull);
      expect(store.phase, Phase.ready);
    });

    test('later sign-ins send no name (Apple gives it only once)', () {
      const later = AppleCredential(
        user: AuthUser(),
        idToken: 'apple-id-token',
        nonce: 'made-up-nonce-0123456789',
        authorizationCode: '',
      );
      expect(later.sessionBody, {
        'appleIdToken': 'apple-id-token',
        'nonce': 'made-up-nonce-0123456789',
      });
    });

    test('cancelling is quiet: no error, no session', () async {
      final api = sampleApi();
      final apple = FakeApple()..next = null;
      final store = storeFor(api, signedIn: false, apple: apple);
      await store.start();
      await store.auth.signInWithApple();
      expect(apple.sheets, 1);
      expect(store.auth.error, isNull);
      expect(store.auth.signedIn, isFalse);
      expect(api.calls, isNot(contains('POST /api/session')));
    });

    test('a failure shows Apple\'s sign-in error', () async {
      final api = sampleApi();
      final apple = FakeApple()..error = StateError('made-up failure');
      final store = storeFor(api, signedIn: false, apple: apple);
      await store.start();
      await store.auth.signInWithApple();
      expect(store.auth.error, SignInError.apple);
      expect(store.auth.signedIn, isFalse);
    });

    test('not offered where Apple isn\'t available', () async {
      final apple = FakeApple(available: false);
      final store = storeFor(sampleApi(), signedIn: false, apple: apple);
      await store.start();
      expect(store.auth.appleAvailable, isFalse);
      await store.auth.signInWithApple();
      expect(apple.sheets, 0);
    });
  });

  group('sessions on screen', () {
    testWidgets('the sign-in screen offers Apple next to Google on iOS', (
      tester,
    ) async {
      final api = sampleApi();
      final store = await pumpApp(
        tester,
        storeFor(api, signedIn: false, apple: FakeApple()),
      );
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in with Apple'), findsOneWidget);
      await tester.tap(find.text('Sign in with Apple'));
      await tester.pumpAndSettle();
      expect(api.sessionBodies.single['appleIdToken'], 'apple-id-token');
      expect(store.auth.signedIn, isTrue);
    });

    testWidgets('no Apple button without Apple', (tester) async {
      await pumpApp(tester, storeFor(sampleApi(), signedIn: false));
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in with Apple'), findsNothing);
    });

    testWidgets('a failed Apple sign-in says so', (tester) async {
      final apple = FakeApple()..error = StateError('made-up failure');
      await pumpApp(
        tester,
        storeFor(sampleApi(), signedIn: false, apple: apple),
      );
      await tester.tap(find.text('Sign in with Apple'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn\'t sign in with Apple. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('a kept session skips the sign-in screen', (tester) async {
      await pumpApp(tester, storeFor(sampleApi()));
      expect(find.text('Sign in with Google'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the sign-in screen: the landing page, with a crag photo', (
      tester,
    ) async {
      final api = sampleApi()
        ..catalog.addAll(const [
          GrigriPic(
            key: 'crags/a/1.jpg',
            crag: 'Peña Alta',
            author: 'Ana Roca',
            license: 'CC BY 4.0',
          ),
          GrigriPic(key: 'crags/b/1.jpg', crag: 'Valle Gris'),
        ]);
      final store = await pumpApp(tester, storeFor(api, signedIn: false));
      expect(find.text('Find a climbing plan.'), findsOneWidget);
      expect(find.text('100% free'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Photo: Ana Roca, CC BY 4.0'), findsOneWidget);
      expect(find.text('Valle Gris'), findsOneWidget);
      expect(find.text('Mara, Jonas and 1 more'), findsOneWidget);
      // The demo card swipes away, and the next plan, at another crag,
      // comes in.
      for (final ms in [2300, 800, 700, 400]) {
        await tester.pump(Duration(milliseconds: ms));
      }
      expect(find.text('Iker and Lea'), findsOneWidget);
      expect(find.text('Peña Alta'), findsOneWidget);
      expect(find.text('How it works', skipOffstage: false), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Join free with Google'), 300);
      await tester.tap(find.text('Join free with Google'));
      await tester.pumpAndSettle();
      // The last call signs in too.
      expect(store.phase, Phase.ready);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('an ended session goes back to the sign-in screen', (
      tester,
    ) async {
      final api = sampleApi();
      final store = await pumpApp(tester, storeFor(api));
      api.sessions.clear();
      await store.refreshPlans();
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(keptToken(store), isNull);
    });

    testWidgets('Sign out everywhere, from Profile, after a confirmation', (
      tester,
    ) async {
      final api = sampleApi();
      final store = await pumpApp(tester, storeFor(api));
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Me'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out everywhere'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out everywhere?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('DELETE /api/sessions')));

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out everywhere'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sign out everywhere'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('DELETE /api/sessions'));
      expect(api.sessions, isEmpty);
      expect(keptToken(store), isNull);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });
  });
}
