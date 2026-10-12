import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/auth.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/main.dart';
import 'package:grigri_app/model/climber.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/ui/common.dart';
import 'package:grigri_app/ui/profile_editor.dart';

import 'support/fakes.dart';

/// The app over [api] on a phone-sized screen, signed in unless
/// [signedIn] is false.
Future<GrigriStore> pumpApp(
  WidgetTester tester,
  FakeApi api, {
  bool signedIn = true,
  SignInMode mode = SignInMode.google,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final store = storeFor(api, signedIn: signedIn, mode: mode);
  await tester.pumpWidget(GrigriApp(store: store));
  await store.start();
  await tester.pumpAndSettle();
  return store;
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
      matching: find.byType(NavigationDestination),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('signing in', () {
    testWidgets('signed out, the sign-in screen offers Google only', (
      tester,
    ) async {
      await pumpApp(tester, sampleApi(), signedIn: false);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Dev sign-in'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a build without a client ID says sign-in is not set up', (
      tester,
    ) async {
      await pumpApp(
        tester,
        sampleApi(),
        signedIn: false,
        mode: SignInMode.unconfigured,
      );
      expect(find.textContaining('Sign-in isn\'t set up'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('the local dev sign-in takes an email', (tester) async {
      final api = sampleApi();
      final store = await pumpApp(
        tester,
        api,
        signedIn: false,
        mode: SignInMode.dev,
      );
      await tester.enterText(find.byType(TextField), 'pat@example.com');
      await tester.tap(find.text('Dev sign-in'));
      await tester.pumpAndSettle();
      expect(store.auth.user!.email, 'pat@example.com');
      expect(find.text('Discover plans'), findsOneWidget);
    });

    testWidgets('the first sign-in creates the profile before the tabs', (
      tester,
    ) async {
      final api = sampleApi(profile: false);
      final store = await pumpApp(tester, api, signedIn: false);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.text('Create your profile'), findsOneWidget);
      // Google's name to start with.
      expect(find.widgetWithText(TextFormField, 'Pat Quill'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('PUT /api/me'));
      expect(store.me.name, 'Pat Quill');
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('signing out from Profile goes back to the sign-in screen', (
      tester,
    ) async {
      await pumpApp(tester, sampleApi());
      await tapTab(tester, 'Profile');
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Reset the demo data'), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('a 401 signs out', (tester) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      api.failNext = const ApiException(401, 'Unauthorized');
      await store.refreshDiscover();
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Signed out: please sign in again.'), findsOneWidget);
    });
  });

  group('Discover', () {
    testWidgets('shows the best-fitting plan first, highlighted', (
      tester,
    ) async {
      await pumpApp(tester, sampleApi());
      expect(find.text('THE PLAN'), findsWidgets);
      expect(find.text('Block Hall'), findsOneWidget);
      expect(find.text('Kit Marlow'), findsOneWidget);
      expect(find.text('Your grades'), findsWidgets);
    });

    testWidgets('asking to join makes a pending request', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Ask to join'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/boulder-night/join'));
      expect(find.textContaining('Asked to join: pending'), findsOneWidget);
      expect(find.text('Block Hall'), findsNothing);
      await tapTab(tester, 'Plans');
      expect(find.text('ASKED TO JOIN'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('dragging a card left passes on the plan', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tester.timedDrag(
        find.text('Block Hall'),
        const Offset(-600, 0),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/boulder-night/pass'));
      expect(find.text('Block Hall'), findsNothing);
      expect(find.text('Grey Cliffs'), findsOneWidget);
    });

    testWidgets('the server\'s error shows at the bottom', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      api.failNext = const ApiException(409, 'You already asked.');
      await tester.tap(find.byTooltip('Ask to join'));
      await tester.pumpAndSettle();
      expect(find.text('You already asked.'), findsOneWidget);
    });

    testWidgets('a group\'s yes found by the refresh shows the match', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      // Pass Bouldering night, ask to join Robin's crag day.
      await tester.tap(find.byTooltip('Pass'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ask to join'));
      await tester.pumpAndSettle();
      api.acceptAs('robin', 'crag-day', 'me');
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text("It's a match!"), findsOneWidget);
      await tester.tap(find.text('Keep swiping'));
      await tester.pumpAndSettle();
      await tapTab(tester, 'Plans');
      expect(find.text('Grey Cliffs'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
    });
  });

  group('requests in the chat', () {
    testWidgets('a request notification opens the chat; accepting matches', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tapTab(tester, 'Notifications');
      expect(find.text('Jules Fern wants to join'), findsOneWidget);
      expect(api.calls, contains('POST /api/notices/read'));
      await tester.tap(find.text('Jules Fern wants to join'));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('request my-gym/jules'));
      expect(
        find.descendant(of: card, matching: find.text('waiting for You')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: card, matching: find.text('Accept')),
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/requests/my-gym/jules/accept'));
      expect(find.text("It's a match!"), findsOneWidget);
      expect(api.plans['my-gym']!.memberIds, ['me', 'jules']);
    });

    testWidgets('the chat calls out on top who still needs my answer', (
      tester,
    ) async {
      final api = sampleApi()..ask('my-gym', 'kit');
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      await tester.tap(find.text('Wall Works'));
      await tester.pumpAndSettle();
      expect(find.text('WANTS TO JOIN · YOUR ANSWER'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Decline Kit Marlow'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/requests/my-gym/kit/reject'));
      expect(find.byKey(const ValueKey('callout my-gym/kit')), findsNothing);
      // The card in the messages stays, as the record.
      final card = find.byKey(const ValueKey('request my-gym/kit'));
      expect(
        find.descendant(of: card, matching: find.text('Declined')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Accept Jules Fern'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/requests/my-gym/jules/accept'));
      expect(find.text("It's a match!"), findsOneWidget);
      await tester.tap(find.text('Keep swiping'));
      await tester.pumpAndSettle();
      expect(find.text('WANTS TO JOIN · YOUR ANSWER'), findsNothing);
    });

    testWidgets('declining in the chat turns them down', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      expect(find.text('1 to answer'), findsOneWidget);
      await tester.tap(find.text('Wall Works'));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('request my-gym/jules'));
      await tester.tap(
        find.descendant(of: card, matching: find.text('Decline')),
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/requests/my-gym/jules/reject'));
      expect(
        find.descendant(of: card, matching: find.text('Declined')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('Accept')),
        findsNothing,
      );
    });

    testWidgets('messages are sent, and new ones come in while it\'s open', (
      tester,
    ) async {
      final api = sampleApi();
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: ['robin', 'me'],
      );
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      await tester.tap(find.text('Grey Cliffs'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Count me in!');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/crag-day/messages'));
      expect(find.text('Count me in!'), findsOneWidget);

      api.say('crag-day', 'robin', 'Great, see you at 9');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Great, see you at 9'), findsOneWidget);
      expect(api.calls, contains('GET /api/plans/crag-day/messages?after'));
    });
  });

  group('plans', () {
    Future<void> openNewPlan(WidgetTester tester) async {
      await tapTab(tester, 'Plans');
      await tester.tap(find.text('New plan'));
      await tester.pumpAndSettle();
    }

    Future<void> publish(WidgetTester tester) async {
      final button = find.text('Publish the plan');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('a new plan picks its sector from the search', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await openNewPlan(tester);
      expect(find.widgetWithText(TextFormField, 'Title'), findsNothing);
      expect(find.text('GROUP SIZE'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sector, crag or gym'),
        'pati',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('El Pati'));
      await tester.pumpAndSettle();
      await publish(tester);
      expect(api.calls, contains('POST /api/plans'));
      final plan = api.plans.values.firstWhere((p) => p.place == 'El Pati');
      expect(plan.sectorId, 'demo:el-pati');
      expect(plan.area, isNotEmpty);
      expect(plan.start.hour, 9);
      expect(plan.end.hour, 17);
      expect(find.text('El Pati'), findsOneWidget);
    });

    testWidgets('a place the index lacks is typed in by hand', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await openNewPlan(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sector, crag or gym'),
        'Hidden Slab',
      );
      await tester.pumpAndSettle();
      await publish(tester);
      final plan = api.plans.values.firstWhere((p) => p.place == 'Hidden Slab');
      expect(plan.sectorId, isNull);
      expect(plan.area, isEmpty);
      expect(find.text('Hidden Slab'), findsOneWidget);
    });

    testWidgets('grades switch between European and American, on the device', (
      tester,
    ) async {
      final store = await pumpApp(tester, sampleApi());
      await openNewPlan(tester);
      expect(find.text('6a–6c+'), findsOneWidget);
      await tester.tap(find.text('American'));
      await tester.pumpAndSettle();
      expect(find.text('5.10b–5.11c'), findsOneWidget);
      expect(store.gradeSystem, GradeSystem.american);
    });

    testWidgets('leaving a plan takes it out of Plans', (tester) async {
      final api = sampleApi();
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: ['robin', 'me'],
      );
      await pumpApp(tester, api);
      await tapTab(tester, 'Plans');
      await tester.tap(find.text('Grey Cliffs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave the plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/crag-day/leave'));
      expect(find.text('Grey Cliffs'), findsNothing);
      expect(find.text('Wall Works'), findsOneWidget);
    });
  });

  group('empty', () {
    testWidgets('every tab says what to do when there is nothing yet', (
      tester,
    ) async {
      final api = FakeApi(admin: true)
        ..meId = 'me'
        ..addClimber(me);
      await pumpApp(tester, api);
      expect(find.text('No plans to join right now'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'New plan'), findsOneWidget);
      await tapTab(tester, 'Plans');
      expect(find.text('No plans yet'), findsOneWidget);
      await tapTab(tester, 'Chats');
      expect(find.text('No chats yet'), findsOneWidget);
      await tester.tap(find.text('Find a plan'));
      await tester.pumpAndSettle();
      expect(find.text('No plans to join right now'), findsOneWidget);
      await tapTab(tester, 'Notifications');
      expect(find.text('Nothing yet'), findsOneWidget);
      await tapTab(tester, 'Admin');
      expect(find.text('No open requests'), findsOneWidget);
    });
  });

  group('Admin', () {
    testWidgets('the tab is only there for admins', (tester) async {
      await pumpApp(tester, sampleApi());
      final labels = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((d) => d.label);
      expect(labels, [
        'Discover',
        'Plans',
        'Chats',
        'Notifications',
        'Profile',
      ]);
    });

    testWidgets('admins approve any request', (tester) async {
      final api = sampleApi(admin: true)..ask('boulder-night', 'jules');
      await pumpApp(tester, api);
      await tapTab(tester, 'Admin');
      final tile = find.byKey(const ValueKey('admin boulder-night/jules'));
      expect(
        find.descendant(of: tile, matching: find.text('0 of 2 said yes')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: tile, matching: find.text('Approve')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Approve'));
      await tester.pumpAndSettle();
      expect(
        api.calls,
        contains('POST /api/admin/requests/boulder-night/jules/accept'),
      );
      expect(api.plans['boulder-night']!.memberIds, contains('jules'));
      expect(find.text('Jules Fern joined Block Hall.'), findsOneWidget);
      expect(tile, findsNothing);
    });

    testWidgets('admins reject any request, after a confirmation', (
      tester,
    ) async {
      final api = sampleApi(admin: true);
      await pumpApp(tester, api);
      await tapTab(tester, 'Admin');
      final tile = find.byKey(const ValueKey('admin my-gym/jules'));
      await tester.tap(
        find.descendant(of: tile, matching: find.text('Reject')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.contains('reject')), isEmpty);
      await tester.tap(
        find.descendant(of: tile, matching: find.text('Reject')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(
        api.calls,
        contains('POST /api/admin/requests/my-gym/jules/reject'),
      );
      expect(api.requestsById['my-gym/jules']!.rejected, isTrue);
      expect(find.text('No open requests'), findsOneWidget);
    });

    testWidgets('six tabs fit a narrow phone', (tester) async {
      await pumpApp(tester, sampleApi(admin: true));
      // An overflow fails the test.
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      await tester.pumpAndSettle();
      for (final tab in ['Notifications', 'Admin', 'Discover']) {
        await tapTab(tester, tab);
      }
      expect(find.byType(NavigationDestination), findsNWidgets(6));
    });
  });

  group('profile', () {
    testWidgets('the tabs are Discover, Plans, Chats, Notifications, Profile', (
      tester,
    ) async {
      await pumpApp(tester, sampleApi());
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('the age can be left out of the profile', (tester) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      await tapTab(tester, 'Profile');
      expect(find.text('Pat Quill, 30'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Age (optional)'),
        '',
      );
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      expect(store.me.age, isNull);
      expect(api.climbers['me']!.age, isNull);
      expect(find.text('Pat Quill, 30'), findsNothing);
    });

    testWidgets('photos are uploaded, then saved with the profile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final api = sampleApi();
      final store = storeFor(api);
      await store.start();
      final asked = <double>[];
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            home: ProfileEditor(
              pick: (source, maxSide) async {
                asked.add(maxSide);
                return png;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Add a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Change your photo'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byTooltip('Add a gear photo'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.byTooltip('Add a gear photo'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Add a gear photo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose a photo'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Remove gear photo 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();

      expect(asked, [640, 1080, 1080]);
      // Two photos: each a POST /api/photos, then the upload; then the
      // profile with their keys.
      final photoCalls = api.calls
          .where(
            (c) =>
                c.contains('photos') ||
                c.contains('bucket') ||
                c == 'PUT /api/me',
          )
          .toList();
      expect(photoCalls, [
        'POST /api/photos',
        'POST https://bucket.test/ (me/profile-3)',
        'POST /api/photos',
        'POST https://bucket.test/ (me/gear-4)',
        'PUT /api/me',
      ]);
      expect(store.me.photo, 'me/profile-3');
      expect(store.me.gearPhotos, ['me/gear-4']);
      expect(api.uploads['me/gear-4'], png);
    });

    testWidgets('gear photos stop at the most a profile keeps', (tester) async {
      final api = sampleApi();
      api.climbers['me'] = me.copyWith(
        gearPhotos: List.generate(Climber.maxGearPhotos, (i) => 'me/gear-$i'),
      );
      final store = storeFor(api);
      await store.start();
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(home: ProfileEditor()),
        ),
      );
      expect(find.byTooltip('Add a gear photo'), findsNothing);
    });
  });
}
