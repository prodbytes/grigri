import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/auth.dart';
import 'package:grigri_app/data/device_location.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/preferences.dart';
import 'package:grigri_app/data/sector_index.dart';
import 'package:grigri_app/main.dart';
import 'package:grigri_app/model/ad.dart';
import 'package:grigri_app/model/climber.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/location.dart';
import 'package:grigri_app/model/match_score.dart';
import 'package:grigri_app/model/pics.dart';
import 'package:grigri_app/model/plan.dart';
import 'package:grigri_app/model/premium.dart';
import 'package:grigri_app/ui/admin_screen.dart';
import 'package:grigri_app/ui/chat_media.dart';
import 'package:grigri_app/ui/chat_screen.dart';
import 'package:grigri_app/ui/common.dart';
import 'package:grigri_app/ui/plan_screen.dart';
import 'package:grigri_app/ui/profile_editor.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fakes.dart';

/// The app over [api] on a phone-sized screen, signed in unless
/// [signedIn] is false.
Future<GrigriStore> pumpApp(
  WidgetTester tester,
  FakeApi api, {
  bool signedIn = true,
  SignInMode mode = SignInMode.google,
  DeviceLocation deviceLocation = const DeviceLocation.none(),
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final store = storeFor(
    api,
    signedIn: signedIn,
    mode: mode,
    deviceLocation: deviceLocation,
  );
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
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the first sign-in makes the profile and opens the tabs', (
      tester,
    ) async {
      final api = sampleApi(profile: false);
      final store = await pumpApp(tester, api, signedIn: false);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(api.calls, isNot(contains('PUT /api/me')));
      // Google's name to start with.
      expect(store.me.name, 'Pat Quill');
    });

    testWidgets('signing out from Profile goes back to the sign-in screen', (
      tester,
    ) async {
      await pumpApp(tester, sampleApi());
      await tapTab(tester, 'Me');
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
      expect(find.text('Block Hall'), findsOneWidget);
      expect(find.text('Organized by'), findsWidgets);
      expect(find.text('Kit Marlow'), findsOneWidget);
      expect(find.text('Your grades'), findsWidgets);
    });

    testWidgets('a card shows its crag photo, credited; none without one', (
      tester,
    ) async {
      final api = sampleApi()
        ..covers['boulder-night'] = const DeckCover(
          key: 'crags/x/a.jpg',
          crag: 'Siurana',
          author: 'A. Example',
          license: 'CC BY-SA 4.0',
        );
      await pumpApp(tester, api);
      expect(find.byKey(const ValueKey('cover boulder-night')), findsOneWidget);
      expect(
        find.text('Siurana · Photo: A. Example, CC BY-SA 4.0'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Pass'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cover grey-cliffs')), findsNothing);
      expect(find.textContaining('Photo:'), findsNothing);
    });

    testWidgets('cards: the organizer +N, the date and time apart, no '
        'distance; no location, a hint', (tester) async {
      final api = sampleApi()..distanceKm['boulder-night'] = 12;
      await pumpApp(tester, api);
      // Kit organizes, with Sasha: "+1"; the group's list opens on a tap.
      expect(find.text('+1'), findsOneWidget);
      expect(find.textContaining('Sasha'), findsNothing);
      await tester.tap(find.byTooltip('Show the group'));
      await tester.pumpAndSettle();
      expect(find.text('ALSO IN THE GROUP'), findsOneWidget);
      expect(find.textContaining('Sasha'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide the group'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sasha'), findsNothing);
      expect(find.textContaining('km from you'), findsNothing);
      expect(find.text('19:00–22:00'), findsOneWidget);
      expect(
        find.text('Set where you climb to see plans near you first.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Set your location'), findsOneWidget);
    });

    testWidgets('with a location, no hint', (tester) async {
      final api = sampleApi();
      api.climbers['me'] = api.climbers['me']!.copyWith(
        location: const Location(name: 'Home crag', lat: 1, lon: 2),
      );
      await pumpApp(tester, api);
      expect(
        find.text('Set where you climb to see plans near you first.'),
        findsNothing,
      );
    });

    testWidgets('without a location, the app takes it from the device', (
      tester,
    ) async {
      final api = sampleApi();
      final device = FakeDeviceLocation((lat: 41.512, lon: 1.004));
      final store = await pumpApp(tester, api, deviceLocation: device);
      final saved = api.climbers['me']!.location;
      expect(saved?.name, 'Near Valle Alto, Spain');
      // Rounded to about 1 km.
      expect((saved?.lat, saved?.lon), (41.51, 1.0));
      expect(store.me.location, saved);
      expect(
        find.text('Set where you climb to see plans near you first.'),
        findsNothing,
      );
    });

    testWidgets('a location already set is left alone', (tester) async {
      final api = sampleApi();
      const home = Location(name: 'Home crag', lat: 1, lon: 2);
      api.climbers['me'] = api.climbers['me']!.copyWith(location: home);
      final device = FakeDeviceLocation((lat: 41.5, lon: 1));
      await pumpApp(tester, api, deviceLocation: device);
      expect(device.asked, 0);
      expect(api.climbers['me']!.location, home);
    });

    testWidgets('with areas but no location, the device still fills it', (
      tester,
    ) async {
      final api = sampleApi();
      const away = Location(name: 'Away', lat: 1, lon: 2);
      api.climbers['me'] = api.climbers['me']!.copyWith(areas: [away]);
      final device = FakeDeviceLocation((lat: 41.512, lon: 1.004));
      await pumpApp(tester, api, deviceLocation: device);
      expect(device.asked, 1);
      expect(api.climbers['me']!.location?.name, 'Near Valle Alto, Spain');
      expect(api.climbers['me']!.areas, [away]);
    });

    testWidgets('the profile screen shows my location and sets it at once', (
      tester,
    ) async {
      final api = sampleApi();
      final device = FakeDeviceLocation((lat: 41.512, lon: 1.004));
      await pumpApp(tester, api, deviceLocation: device);
      await tapTab(tester, 'Me');
      // Detected from the device by default.
      await tester.ensureVisible(find.text('Near Valle Alto, Spain'));
      expect(find.text('Near Valle Alto, Spain'), findsOneWidget);

      await tester.runAsync(SectorIndex.load);
      await tester.tap(find.text('Near Valle Alto, Spain'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'A crag or gym near there'),
        'margalef',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Margalef'));
      await tester.pumpAndSettle();
      // Saved without opening the editor.
      expect(api.climbers['me']!.location?.name, 'Margalef, Catalonia, Spain');
      expect(find.text('Margalef, Catalonia, Spain'), findsOneWidget);
    });

    testWidgets('when the device can\'t tell, the hint asks', (tester) async {
      final api = sampleApi();
      final device = FakeDeviceLocation(null);
      await pumpApp(tester, api, deviceLocation: device);
      expect(device.asked, 1);
      expect(api.climbers['me']!.location, isNull);
      expect(
        find.text('Set where you climb to see plans near you first.'),
        findsOneWidget,
      );
    });

    testWidgets('asking to join makes a pending request', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Ask to join'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/boulder-night/join'));
      expect(
        find.text("Asked to join. You'll get an alert when you're accepted."),
        findsOneWidget,
      );
      expect(find.text('Block Hall'), findsNothing);
      await tapTab(tester, 'Plans');
      expect(find.text('ASKED TO JOIN'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('a pending request nudges the group, then waits 12 hours', (
      tester,
    ) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      await store.like('crag-day');
      await tapTab(tester, 'Plans');
      expect(find.text('Pending'), findsOneWidget);
      await tester.tap(find.text('Nudge'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/crag-day/nudge'));
      expect(find.text('Nudge sent to Robin'), findsOneWidget);
      expect(
        api.noticesFor['robin']!.where((n) => n.kind == NoticeKind.nudge),
        hasLength(1),
      );
      // Now "Nudged", and disabled until the 12 hours are up.
      expect(find.text('Nudge'), findsNothing);
      final nudged = find.widgetWithText(TextButton, 'Nudged');
      expect(tester.widget<TextButton>(nudged).onPressed, isNull);
      expect(store.waiting.single.canNudge(DateTime.now()), isFalse);
      expect(
        store.waiting.single.canNudge(
          DateTime.now().add(JoinRequest.nudgeCooldown),
        ),
        isTrue,
      );
    });

    testWidgets('a refused nudge shows the server\'s words', (tester) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      await store.like('crag-day');
      await tapTab(tester, 'Plans');
      api.failNext = const ApiException(
        429,
        'you nudged the group less than 12 hours ago; try again later',
      );
      await tester.tap(find.text('Nudge'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'you nudged the group less than 12 hours ago; try again later',
        ),
        findsOneWidget,
      );
      expect(find.text('Nudge sent to Robin'), findsNothing);
      expect(find.text('Nudge'), findsOneWidget);
    });

    testWidgets('a declined request has no Nudge', (tester) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      await store.like('crag-day');
      api.requestsById['crag-day/me'] = api.requestsById['crag-day/me']!
          .copyWith(rejected: true);
      await store.refreshPlans();
      await tapTab(tester, 'Plans');
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Nudge'), findsNothing);
      expect(find.text('Nudged'), findsNothing);
    });

    testWidgets('the small share button shares the top plan, with a link', (
      tester,
    ) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final shared = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        shared.add(call.arguments as Map<Object?, Object?>);
        return 'dev.fluttercommunity.plus/share/success';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final api = sampleApi();
      await pumpApp(tester, api);
      expect(
        tester.getSize(find.byTooltip('Share this plan')).width,
        lessThan(tester.getSize(find.byTooltip('Ask to join')).width),
      );
      // Right of ✓, with ✕ and ✓ still centered on the screen.
      final share = tester.getCenter(find.byTooltip('Share this plan'));
      final pass = tester.getCenter(find.byTooltip('Pass'));
      final join = tester.getCenter(find.byTooltip('Ask to join'));
      expect(share.dx, greaterThan(join.dx));
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((pass.dx + join.dx) / 2, moreOrLessEquals(width / 2, epsilon: 1));
      await tester.tap(find.byTooltip('Share this plan'));
      await tester.pumpAndSettle();
      final text = shared.single['text']! as String;
      expect(
        text,
        startsWith('Climbing plan on Grigri: Bouldering at Block Hall, '),
      );
      expect(text, contains('19:00–22:00'));
      expect(text, endsWith('/app/'));
      // Sharing doesn't swipe: the plan is still on top.
      expect(find.text('Block Hall'), findsOneWidget);
      expect(api.calls.where((c) => c.contains('boulder-night')), isEmpty);
    });

    testWidgets('the card trims long notes and bios, in smaller text', (
      tester,
    ) async {
      final long = List.filled(40, 'Long approach, steep pockets.').join(' ');
      final api = sampleApi();
      final plan = api.plans['boulder-night']!;
      api
        ..addPlan(
          Plan(
            id: plan.id,
            organizerId: plan.organizerId,
            discipline: plan.discipline,
            place: plan.place,
            start: plan.start,
            end: plan.end,
            grades: plan.grades,
            memberIds: plan.memberIds,
            notes: long,
          ),
        )
        ..addClimber(Climber(id: 'kit', name: 'Kit Marlow', bio: long));
      await pumpApp(tester, api);
      final texts = tester.widgetList<Text>(find.text(long)).toList();
      expect(texts, hasLength(2));
      for (final t in texts) {
        expect(t.maxLines, 3);
        expect(t.overflow, TextOverflow.ellipsis);
      }
      final element = tester.element(find.text(long).first);
      expect(MediaQuery.textScalerOf(element).scale(10), closeTo(9, 0.001));
      // The whole profile, in its sheet, isn't trimmed.
      await tester.tap(find.text('Kit Marlow'));
      await tester.pumpAndSettle();
      final whole = tester
          .widgetList<Text>(find.text(long))
          .where((t) => t.maxLines == null);
      expect(whole, isNotEmpty);
    });

    testWidgets('demo plans and people say they are made up', (tester) async {
      const notice = 'Demo: made-up people and plans.';
      final api = sampleApi();
      final plan = api.plans['boulder-night']!;
      api
        ..addPlan(
          Plan(
            id: plan.id,
            organizerId: plan.organizerId,
            discipline: plan.discipline,
            place: plan.place,
            start: plan.start,
            end: plan.end,
            grades: plan.grades,
            memberIds: plan.memberIds,
            demo: true,
          ),
        )
        ..addClimber(const Climber(id: 'kit', name: 'Kit Marlow', demo: true));
      await pumpApp(tester, api);
      expect(find.text(notice), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);
      // Their profile says so too.
      await tester.tap(find.text('Kit Marlow'));
      await tester.pumpAndSettle();
      expect(find.text(notice), findsNWidgets(2));
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      // Real ones don't.
      await tester.tap(find.byTooltip('Pass'));
      await tester.pumpAndSettle();
      expect(find.text('Grey Cliffs'), findsOneWidget);
      expect(find.text(notice), findsNothing);
    });

    testWidgets('asking to join a demo plan matches at once', (tester) async {
      final api = sampleApi();
      final plan = api.plans['boulder-night']!;
      api.addPlan(
        Plan(
          id: plan.id,
          organizerId: plan.organizerId,
          discipline: plan.discipline,
          place: plan.place,
          start: plan.start,
          end: plan.end,
          grades: plan.grades,
          memberIds: plan.memberIds,
          demo: true,
        ),
      );
      final store = await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Ask to join'));
      await tester.pumpAndSettle();
      expect(find.text("It's a match!"), findsOneWidget);
      expect(find.textContaining("You'll get an alert"), findsNothing);
      expect(api.plans['boulder-night']!.memberIds, contains('me'));
      expect(store.waiting, isEmpty);
    });

    testWidgets('refresh brings back the plans I passed on', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Pass'));
      await tester.pumpAndSettle();
      expect(find.text('Block Hall'), findsNothing);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('DELETE /api/passes'));
      expect(find.text('Block Hall'), findsOneWidget);
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
    testWidgets('a nudge notification asks me to answer; it opens the chat', (
      tester,
    ) async {
      final api = sampleApi();
      api.nudgeAs('my-gym', 'jules');
      final store = await pumpApp(tester, api);
      // Counted with the other unread notices (the request and the nudge).
      expect(store.unreadNotices, 2);
      await tapTab(tester, 'Alerts');
      expect(
        find.text('Jules Fern is waiting for your answer'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'To join ${api.plans['my-gym']!.title} · accept or decline in the '
          'group chat',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Jules Fern is waiting for your answer'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('request my-gym/jules')),
        findsOneWidget,
      );
    });

    testWidgets('a request notification opens the chat; accepting matches', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tapTab(tester, 'Alerts');
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

  group('photos and videos in the chat', () {
    final mp4 = Uint8List.fromList([
      0,
      0,
      0,
      0x18,
      ...'ftypisom'.codeUnits,
      ...List.filled(20, 0),
    ]);

    /// The chat of crag-day (Robin's and mine), picking what [pick] gives.
    Future<(FakeApi, GrigriStore, List<String>)> openChat(
      WidgetTester tester,
      List<ChatMedia?> picks,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final api = sampleApi();
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: ['robin', 'me'],
      );
      final store = storeFor(api);
      await store.start();
      final errors = <String>[];
      final listening = store.errors.listen(errors.add);
      addTearDown(listening.cancel);
      final sources = <ChatMediaSource>[];
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatScreen(
              planId: 'crag-day',
              pick: (source) async {
                sources.add(source);
                return picks.removeAt(0);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (api, store, errors);
    }

    Future<void> attach(WidgetTester tester, String option) async {
      await tester.tap(find.byTooltip('Add a photo or video'));
      await tester.pumpAndSettle();
      // Photos and videos only: no other kind of file is offered.
      expect(find.text('Choose a photo'), findsOneWidget);
      expect(find.text('Choose a video'), findsOneWidget);
      await tester.tap(find.text(option));
      await tester.pumpAndSettle();
    }

    testWidgets('a photo with text, then a video alone, are uploaded and '
        'shown', (tester) async {
      final (api, _, errors) = await openChat(tester, [
        ChatMedia(png, MediaKind.image),
        ChatMedia(mp4, MediaKind.video),
      ]);
      await attach(tester, 'Choose a photo');
      expect(find.byKey(const ValueKey('picked media')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Our crag');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      final sent = api.calls.where((c) => c.startsWith('POST ')).toList();
      expect(sent, [
        'POST /api/plans/crag-day/media',
        'POST https://bucket.test/ (${api.uploads.keys.single})',
        'POST /api/plans/crag-day/messages',
      ]);
      expect(api.uploads.values.single, png);
      expect(api.progress, [0.5, 1.0]);
      expect(find.text('Our crag'), findsOneWidget);
      expect(
        find.byKey(ValueKey('photo ${api.uploads.keys.single}')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('picked media')), findsNothing);

      // Tapping the photo shows it whole.
      await tester.tap(
        find.byKey(ValueKey('photo ${api.uploads.keys.single}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await attach(tester, 'Choose a video');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      final video = api.uploads.keys.last;
      expect(video, endsWith('.mp4'));
      expect(find.byKey(ValueKey('video $video')), findsOneWidget);
      expect(api.allMessages.last.text, '');
      expect(errors, isEmpty);
    });

    testWidgets('other files and videos over the limit are refused before '
        'any upload', (tester) async {
      final big = Uint8List(maxVideoBytes + 1)..setAll(0, mp4);
      final (api, _, errors) = await openChat(tester, [
        ChatMedia(Uint8List.fromList('%PDF-1.7'.codeUnits), MediaKind.image),
        ChatMedia(big, MediaKind.video),
      ]);
      await attach(tester, 'Choose a photo');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(errors, [
        'Use a JPEG, PNG or WebP photo, or an MP4 or MOV video.',
      ]);
      await tester.tap(find.byTooltip('Remove the attachment'));
      await tester.pumpAndSettle();
      await attach(tester, 'Choose a video');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(errors.last, 'Videos can be at most 50 MB: send a shorter one.');
      expect(api.calls, isNot(contains('POST /api/plans/crag-day/media')));
      expect(api.uploads, isEmpty);
    });
  });

  group('plan photos: Your Pics and GriGri Pics', () {
    final jpeg = Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      ...List.filled(20, 0),
    ]);

    /// crag-day (Robin organizes; I'm in it), its screen picking [picks].
    Future<(FakeApi, GrigriStore)> openPlan(
      WidgetTester tester, {
      List<ChatMedia?> picks = const [],
      bool member = true,
      bool premium = false,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final api = sampleApi()..myPremium = Premium(active: premium);
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: member ? ['robin', 'me'] : ['robin'],
        point: () => (lat: 41.2577, lon: 0.9318),
      );
      api.grigriPics['crag-day'] = const [
        GrigriPic(
          key: 'crags/area-siurana/a.jpg',
          crag: 'Siurana',
          caption: 'The El Pati sector',
          author: 'A. Example',
          license: 'CC BY-SA 4.0',
          source: 'https://commons.wikimedia.org/wiki/File:Example.jpg',
        ),
      ];
      final store = storeFor(api);
      await store.start();
      final queue = [...picks];
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PlanScreen(
              planId: 'crag-day',
              pick: (source) async => queue.removeAt(0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (api, store);
    }

    testWidgets('members add a photo; it shows in Your Pics, and whoever '
        'added it deletes it', (tester) async {
      final (api, _) = await openPlan(
        tester,
        picks: [ChatMedia(jpeg, MediaKind.image)],
      );
      expect(find.text('YOUR PICS'), findsOneWidget);
      expect(
        find.text('No photos yet. Add one, or send one in the chat.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('add plan pic')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.startsWith('POST ')).toList(), [
        'POST /api/plans/crag-day/pics/upload',
        'POST https://bucket.test/ (${api.uploads.keys.single})',
        'POST /api/plans/crag-day/pics',
      ]);
      final pic = api.allPics.single;
      expect(find.byKey(ValueKey('pic ${pic.id}')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('pic ${pic.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Added by You'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete photo'));
      await tester.pumpAndSettle();
      expect(
        find.text("It leaves the plan's photos for everyone."),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(api.allPics, isEmpty);
      expect(find.byKey(ValueKey('pic ${pic.id}')), findsNothing);
    });

    testWidgets("someone else's chat photo: in Your Pics, not mine to delete", (
      tester,
    ) async {
      final (api, store) = await openPlan(tester);
      api.allPics.add(
        PlanPic(
          id: 'pic-robin',
          planId: 'crag-day',
          key: 'chat/crag-day/robin.jpg',
          uploaderId: 'robin',
          time: DateTime.utc(2030),
          fromChat: true,
        ),
      );
      await store.loadPics('crag-day');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pic pic-robin')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sent in the chat by'), findsOneWidget);
      expect(find.byTooltip('Delete photo'), findsNothing);
    });

    testWidgets('the route finder: on the plan for premium climbers only', (
      tester,
    ) async {
      await openPlan(tester);
      expect(find.byKey(const ValueKey('route finder')), findsNothing);
      await openPlan(tester, premium: true);
      expect(find.byKey(const ValueKey('route finder')), findsOneWidget);
      expect(find.text('Routes on the rock'), findsOneWidget);
    });

    testWidgets('GriGri Pics show their crag and credit; outsiders see no '
        'Your Pics', (tester) async {
      await openPlan(tester, member: false);
      expect(find.text('YOUR PICS'), findsNothing);
      expect(find.text('GRIGRI PICS'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('grigri crags/area-siurana/a.jpg')),
      );
      await tester.pumpAndSettle();
      expect(find.text('The El Pati sector'), findsOneWidget);
      expect(find.text('Photo: A. Example, CC BY-SA 4.0'), findsOneWidget);
    });

    testWidgets('a photo sent in the chat joins Your Pics', (tester) async {
      final (api, store) = await openPlan(tester);
      final upload = await api.newChatMedia('crag-day', 'image/jpeg');
      await api.uploadPhoto(upload, jpeg);
      api.calls.clear();
      expect(
        await store.send(
          'crag-day',
          '',
          media: ChatMedia(jpeg, MediaKind.image),
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('GET /api/plans/crag-day/pics'));
      expect(store.pics('crag-day')!.yours.single.fromChat, isTrue);
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
      expect((plan.lat, plan.lon), (41.2577, 0.9318));
      expect(plan.start!.hour, 9);
      expect(plan.end!.hour, 17);
      expect(plan.start!.weekday, DateTime.saturday);
      expect(plan.moreDays, isEmpty);
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

    testWidgets('a plan may leave its date open', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await openNewPlan(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sector, crag or gym'),
        'Open Wall',
      );
      await tester.tap(find.byTooltip('Leave the date open'));
      await tester.pumpAndSettle();
      expect(find.text('Date to be decided'), findsOneWidget);
      // No day, no hours and no more days.
      expect(find.text('Add a day'), findsNothing);
      expect(find.byType(RangeSlider), findsOneWidget);
      await publish(tester);
      final plan = api.plans.values.firstWhere((p) => p.place == 'Open Wall');
      expect(plan.start, isNull);
      expect(plan.end, isNull);
      expect(find.text('Date to be decided'), findsOneWidget);
    });

    testWidgets('a plan takes more days, at the same hours', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await openNewPlan(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sector, crag or gym'),
        'Long Weekend',
      );
      for (var i = 0; i < 2; i++) {
        final add = find.text('Add a day');
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(InputChip), findsNWidgets(2));
      // Removing one leaves the other.
      await tester.tap(
        find.descendant(
          of: find.byType(InputChip).first,
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsOneWidget);
      await publish(tester);
      final plan = api.plans.values.firstWhere(
        (p) => p.place == 'Long Weekend',
      );
      final first = plan.start!;
      final next = plan.moreDays.single;
      expect(next.start.difference(first).inDays, 2);
      expect((next.start.hour, next.end.hour), (9, 17));
      expect(find.textContaining('+1 day'), findsOneWidget);
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
      await tester.tap(find.text('Cancel the plan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('the others keep it.'), findsOneWidget);
      await tester.tap(find.text('Cancel it'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/crag-day/leave'));
      expect(find.text('Grey Cliffs'), findsNothing);
      expect(find.text('Wall Works'), findsOneWidget);
    });

    testWidgets('cancelling from the Plans list takes it out of Plans and '
        'Chats; the others keep it', (tester) async {
      final api = sampleApi();
      // I organize it, with Robin in it.
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        organizerId: 'me',
        memberIds: ['me', 'robin'],
      );
      await pumpApp(tester, api);
      await tapTab(tester, 'Plans');
      final menu = find.descendant(
        of: find.ancestor(
          of: find.text('Grey Cliffs'),
          matching: find.byType(Card),
        ),
        matching: find.byIcon(Icons.more_vert),
      );
      // Changing my mind keeps it.
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel the plan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('picked at random'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('POST /api/plans/crag-day/leave')));
      expect(find.text('Grey Cliffs'), findsOneWidget);
      // Cancelled: out of Plans and Chats.
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel the plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel it'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/plans/crag-day/leave'));
      expect(find.text('Grey Cliffs'), findsNothing);
      await tapTab(tester, 'Chats');
      expect(find.text('Grey Cliffs'), findsNothing);
      // Robin keeps it, and organizes it now.
      expect(api.plans['crag-day']!.memberIds, ['robin']);
      expect(api.plans['crag-day']!.organizerId, 'robin');
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
      await tapTab(tester, 'Alerts');
      expect(find.text('Nothing yet'), findsOneWidget);
      await tapTab(tester, 'Admin');
      expect(find.byKey(const ValueKey('admin climber me')), findsOneWidget);
    });
  });

  group('Premium', () {
    Future<void> openProfile(WidgetTester tester) async {
      await tapTab(tester, 'Me');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('premium card')),
        200,
      );
    }

    testWidgets('subscribing opens Stripe Checkout in the browser', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await openProfile(tester);
      expect(find.text('\$20 a month'), findsOneWidget);
      expect(find.text('\$200 a year'), findsOneWidget);
      await tester.ensureVisible(find.text('\$200 a year'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('\$200 a year'));
      await tester.pumpAndSettle();
      expect(api.opened, [Uri.parse('https://checkout.stripe.test/yearly')]);

      // Stripe told the API: checking again shows it.
      api.myPremium = Premium(
        active: true,
        plan: PremiumPlan.yearly,
        until: DateTime(2031, 5, 1),
      );
      await tester.ensureVisible(find.text("I've paid: check again"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("I've paid: check again"));
      await tester.pumpAndSettle();
      expect(find.text('Premium: renews on May 1, 2031'), findsOneWidget);
      await tester.ensureVisible(find.text('Manage subscription'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage subscription'));
      await tester.pumpAndSettle();
      expect(api.opened.last, Uri.parse('https://billing.stripe.test/portal'));
    });

    testWidgets('a cancelled subscription says when it ends', (tester) async {
      final api = sampleApi()
        ..myPremium = Premium(
          active: true,
          plan: PremiumPlan.monthly,
          until: DateTime(2030, 6, 1),
          ending: true,
        );
      await pumpApp(tester, api);
      await openProfile(tester);
      expect(find.text('Premium: ends on Jun 1, 2030'), findsOneWidget);
      expect(find.text('\$20 a month'), findsNothing);
    });

    testWidgets('without payments set up, it says Premium isn\'t available', (
      tester,
    ) async {
      final api = sampleApi()..premiumPrices = const {};
      await pumpApp(tester, api);
      await openProfile(tester);
      expect(find.text("Premium isn't available yet."), findsOneWidget);
      expect(find.text('\$20 a month'), findsNothing);
    });
  });

  group('Ads', () {
    Ad chalk({AdStatus status = AdStatus.approved}) => Ad(
      id: 'ad-chalk',
      ownerId: 'robin',
      text: 'Chalk sale this weekend',
      link: Uri.parse('https://chalk.example.com/sale'),
      status: status,
    );
    final premium = Premium(
      active: true,
      plan: PremiumPlan.monthly,
      until: DateTime(2031),
    );

    testWidgets('an approved ad comes up between plans; ✓ opens its link', (
      tester,
    ) async {
      final api = sampleApi()
        ..adEvery = 1
        ..addAd(chalk());
      await pumpApp(tester, api);
      expect(find.text('Block Hall'), findsOneWidget);
      await tester.tap(find.byTooltip('Pass'));
      await tester.pumpAndSettle();
      // After one plan: the ad, saying whose it is and where it goes.
      expect(find.text('Chalk sale this weekend'), findsOneWidget);
      expect(find.text('Ad by Robin Vale'), findsOneWidget);
      expect(find.text('chalk.example.com'), findsOneWidget);
      await tester.tap(find.byTooltip("Open the ad's link"));
      await tester.pumpAndSettle();
      expect(api.opened, [Uri.parse('https://chalk.example.com/sale')]);
      // Then the next plan, and the ad doesn't come back.
      expect(find.text('Grey Cliffs'), findsOneWidget);
      expect(find.text('Chalk sale this weekend'), findsNothing);
    });

    testWidgets('skipping an ad opens nothing; pending ads never show', (
      tester,
    ) async {
      final api = sampleApi()
        ..adEvery = 1
        ..addAd(chalk())
        ..addAd(
          Ad(
            id: 'ad-pending',
            ownerId: 'kit',
            text: 'Not reviewed yet',
            link: Uri.parse('https://kit.example.com'),
          ),
        );
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Pass'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Skip the ad'));
      await tester.pumpAndSettle();
      expect(api.opened, isEmpty);
      expect(find.text('Grey Cliffs'), findsOneWidget);
      expect(find.text('Not reviewed yet'), findsNothing);
    });

    test('ads keep their place as plans are swiped', () async {
      final api = sampleApi()
        ..adEvery = 2
        ..addAd(chalk());
      for (var i = 0; i < 3; i++) {
        api.addPlan(
          Plan(
            id: 'extra$i',
            organizerId: 'robin',
            discipline: Discipline.sport,
            place: 'Extra $i',
            start: inDays(5 + i),
            end: inDays(5 + i, 16),
            grades: const GradeRange(GradeScale.routes, 6, 12),
            memberIds: const ['robin'],
          ),
        );
      }
      final store = storeFor(api);
      await store.start();
      String shape() =>
          store.deck.map((i) => i is DeckAd ? 'ad' : 'plan').join(' ');
      expect(shape(), 'plan plan ad plan plan plan');
      await store.pass(store.discover.first.id);
      expect(shape(), 'plan ad plan plan plan');
      await store.pass(store.discover.first.id);
      expect(shape(), 'ad plan plan plan');
      await store.swipeAd((store.deck.first as DeckAd).ad, open: false);
      expect(shape(), 'plan plan plan');
    });

    testWidgets('the Ads tab is for Premium: add an ad, it waits for review', (
      tester,
    ) async {
      final plain = sampleApi();
      await pumpApp(tester, plain);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Ads'),
        ),
        findsNothing,
      );

      final api = sampleApi()..myPremium = premium;
      await pumpApp(tester, api);
      await tapTab(tester, 'Ads');
      expect(find.text('No ads yet'), findsOneWidget);
      await tester.tap(find.text('New ad'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Text over the ad'),
        'Guided days in the gorge',
      );
      await tester.enterText(
        find.byKey(const ValueKey('ad link')),
        'not a link',
      );
      await tester.tap(find.text('Send for review'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a web address, starting with https://'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('ad link')),
        'https://guides.example.com',
      );
      await tester.pumpAndSettle();
      // The preview shows the card as the deck will.
      expect(find.text('guides.example.com'), findsOneWidget);
      await tester.ensureVisible(find.text('Send for review'));
      await tester.tap(find.text('Send for review'));
      await tester.pumpAndSettle();
      expect(find.text('Sent: an admin will review it.'), findsOneWidget);
      expect(find.text('Waiting for review'), findsOneWidget);
      final saved = api.ads.values.single;
      expect(saved.text, 'Guided days in the gorge');
      expect(saved.link, Uri.parse('https://guides.example.com'));

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(api.ads, isEmpty);
      expect(find.text('No ads yet'), findsOneWidget);
    });

    testWidgets('admins approve ads and set how often they show', (
      tester,
    ) async {
      final api = sampleApi(admin: true)
        ..addAd(chalk(status: AdStatus.pending));
      await pumpApp(tester, api);
      await tapTab(tester, 'Admin');
      expect(find.widgetWithText(Tab, 'Users'), findsOneWidget);
      await tester.tap(find.widgetWithText(Tab, 'Ads'));
      await tester.pumpAndSettle();
      expect(find.text('Chalk sale this weekend'), findsOneWidget);
      // The card is tall: bring its buttons up from under the bar.
      await tester.drag(find.byType(AdminAdsView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(api.ads['ad-chalk']!.status, AdStatus.approved);
      expect(find.text('Chalk sale this weekend'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ad every')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('An ad after every 3 plans').last);
      await tester.pumpAndSettle();
      expect(api.adEvery, 3);
      expect(api.calls, contains('PUT /api/admin/ads/settings'));
    });
  });

  group('Admin', () {
    testWidgets('the tab is only there for admins', (tester) async {
      await pumpApp(tester, sampleApi());
      final labels = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((d) => d.label);
      expect(labels, ['Find', 'Plans', 'Chats', 'Alerts', 'Me']);
    });

    testWidgets('every tab keeps its label, an admin\'s six too', (
      tester,
    ) async {
      await pumpApp(tester, sampleApi(admin: true));
      // On a 360 dp wide phone. (The test font's glyphs are full squares,
      // too wide to measure whether labels fit; real fonts' do.)
      tester.view.physicalSize = const Size(936, 2028);
      await tester.pumpAndSettle();
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
      for (final label in ['Find', 'Plans', 'Chats', 'Alerts', 'Me', 'Admin']) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('admins list everyone, and block after a confirmation', (
      tester,
    ) async {
      final api = sampleApi(admin: true);
      await pumpApp(tester, api);
      await tapTab(tester, 'Admin');
      expect(api.calls, contains('GET /api/admin/climbers'));
      final jules = find.byKey(const ValueKey('admin climber jules'));
      expect(
        find.descendant(of: jules, matching: find.text('Jules Fern')),
        findsOneWidget,
      );
      // Never myself.
      final mine = find.byKey(const ValueKey('admin climber me'));
      expect(
        find.descendant(of: mine, matching: find.text('Block')),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: jules, matching: find.text('Block')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Block Jules Fern?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.contains('/block')), isEmpty);

      await tester.tap(
        find.descendant(of: jules, matching: find.text('Block')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Block').last);
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/admin/climbers/jules/block'));
      expect(api.blocked, {'jules'});
      expect(
        find.descendant(of: jules, matching: find.text('Blocked')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: jules, matching: find.text('Unblock')),
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/admin/climbers/jules/unblock'));
      expect(api.blocked, isEmpty);
      expect(
        find.descendant(of: jules, matching: find.text('Block')),
        findsOneWidget,
      );
    });

    testWidgets('a blocked climber sees only that, and can sign out', (
      tester,
    ) async {
      final api = sampleApi()..blocked.add('me');
      await pumpApp(tester, api);
      expect(find.text('Your account is blocked'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Unblocked meanwhile: trying again opens the app.
      api.blocked.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('blocked while using the app: the blocked screen', (
      tester,
    ) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      api.blocked.add('me');
      await store.refreshAll();
      await tester.pumpAndSettle();
      expect(find.text('Your account is blocked'), findsOneWidget);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('admins see the match score on the deck, with its reason', (
      tester,
    ) async {
      const great = MatchScore(
        score: 0.81,
        level: MatchLevel.great,
        reason: MatchReason.inGradesNearby,
      );
      await pumpApp(
        tester,
        sampleApi(admin: true)..matchScores['boulder-night'] = great,
      );
      expect(find.byKey(const ValueKey('match boulder-night')), findsOneWidget);
      expect(find.text('Match 81% · great'), findsOneWidget);
      expect(find.text('In your grades and nearby'), findsOneWidget);
    });

    testWidgets('nobody else sees a match score', (tester) async {
      await pumpApp(
        tester,
        sampleApi()
          ..matchScores['boulder-night'] = const MatchScore(
            score: 0.81,
            level: MatchLevel.great,
            reason: MatchReason.inGrades,
          ),
      );
      expect(find.byKey(const ValueKey('match boulder-night')), findsNothing);
      expect(find.textContaining('Match '), findsNothing);
    });

    testWidgets('six tabs fit a narrow phone', (tester) async {
      await pumpApp(tester, sampleApi(admin: true));
      // An overflow fails the test.
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      await tester.pumpAndSettle();
      for (final tab in ['Alerts', 'Admin', 'Find']) {
        await tapTab(tester, tab);
      }
      expect(find.byType(NavigationDestination), findsNWidgets(6));
    });
  });

  group('profile', () {
    testWidgets('the tabs are Find, Plans, Chats, Alerts, Me', (tester) async {
      await pumpApp(tester, sampleApi());
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      // Every label fits on one line on a 360 dp wide phone.
      final lines = {
        for (final label in ['Find', 'Plans', 'Chats', 'Alerts', 'Me'])
          tester
              .getSize(
                find.descendant(
                  of: find.byType(NavigationBar),
                  matching: find.text(label),
                ),
              )
              .height,
      };
      expect(lines, hasLength(1));
    });

    testWidgets('the age can be left out of the profile', (tester) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      await tapTab(tester, 'Me');
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

    testWidgets('where I climb: a location and areas, kept private', (
      tester,
    ) async {
      final api = sampleApi();
      final store = await pumpApp(tester, api);
      await tapTab(tester, 'Me');
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      final picker = find.widgetWithText(TextField, 'A crag or gym near there');
      // The index loads from the asset bundle, which needs real time.
      await tester.runAsync(SectorIndex.load);

      await tester.tap(find.text('Set your location'));
      await tester.pumpAndSettle();
      await tester.enterText(picker, 'boulder');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boulder gym'));
      await tester.pumpAndSettle();
      expect(find.text('Boulder gym, Barcelona, Spain'), findsOneWidget);

      // The device can't tell where it is (the default here): it says so.
      await tester.tap(find.text('Boulder gym, Barcelona, Spain'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't tell where you are. Search for a place instead."),
        findsOneWidget,
      );
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add an area'));
      await tester.tap(find.text('Add an area'));
      await tester.pumpAndSettle();
      await tester.enterText(picker, 'margalef');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Margalef'));
      await tester.pumpAndSettle();
      expect(find.text('Margalef, Catalonia, Spain'), findsOneWidget);

      await tester.tap(find.text('Save').first);
      await tester.pumpAndSettle();
      final saved = api.climbers['me']!;
      expect(saved.location?.name, 'Boulder gym, Barcelona, Spain');
      expect(saved.location?.lat, 41.3975);
      expect(saved.areas.map((a) => a.name), ['Margalef, Catalonia, Spain']);
      expect(api.calls.last, 'GET /api/discover');

      // Refreshes bring my profile back without them (they're private):
      // the app keeps mine.
      await store.refreshAll();
      await tester.pumpAndSettle();
      expect(store.me.location, saved.location);
      expect(store.me.areas, saved.areas);
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileEditor(),
          ),
        ),
      );
      expect(find.byTooltip('Add a gear photo'), findsNothing);
    });
  });

  group('the profile ends with my roles, from rbacr through the API', () {
    Future<void> openProfile(WidgetTester tester, FakeApi api) async {
      await pumpApp(tester, api);
      await tapTab(tester, 'Me');
      await tester.scrollUntilVisible(find.text('ROLES'), 200);
    }

    testWidgets('as the API gives them', (tester) async {
      await openProfile(tester, sampleApi()..roles = ['admin', 'root']);
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('or that I have none', (tester) async {
      await openProfile(tester, sampleApi()..roles = []);
      expect(find.text('No roles in Grigri yet.'), findsOneWidget);
    });

    testWidgets("or that rbacr didn't answer, with Retry", (tester) async {
      final api = sampleApi()..roles = null;
      await openProfile(tester, api);
      expect(find.text("Couldn't get your roles from rbacr."), findsOneWidget);
      api.roles = ['admin'];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('admin'), findsOneWidget);
    });
  });

  group('language', () {
    testWidgets(
      'follows the device, in English when the app lacks its language',
      (tester) async {
        tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await pumpApp(tester, sampleApi());
        expect(find.text('Suche'), findsOneWidget);
        expect(find.text('Pläne entdecken'), findsOneWidget);

        tester.platformDispatcher.localesTestValue = const [Locale('ja')];
        await tester.pumpAndSettle();
        expect(find.text('Discover plans'), findsOneWidget);
      },
    );

    testWidgets('picked in the profile, it switches the app at once', (
      tester,
    ) async {
      final store = await pumpApp(tester, sampleApi());
      await tapTab(tester, 'Me');
      await tester.scrollUntilVisible(find.text('System default'), 200);
      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();

      expect(store.locale, const Locale('es'));
      expect(find.text('Idioma'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Editar perfil'), -200);
      expect(find.text('Editar perfil'), findsOneWidget);
      await tapTab(tester, 'Buscar');
      expect(find.text('Descubre planes'), findsOneWidget);
      expect(find.text('Organiza'), findsWidgets);

      await tapTab(tester, 'Yo');
      await tester.scrollUntilVisible(find.text('Español'), 200);
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Idioma del sistema').last);
      await tester.pumpAndSettle();
      expect(store.locale, isNull);
      await tester.scrollUntilVisible(find.text('Edit profile'), -200);
      expect(find.text('Edit profile'), findsOneWidget);
    });

    testWidgets('texts the store words itself follow the language shown', (
      tester,
    ) async {
      final store = await pumpApp(tester, sampleApi());
      store.locale = const Locale('fr');
      await tester.pumpAndSettle();
      expect(store.climber('nobody').name, "Quelqu'un");
    });

    test('the pick is kept on the device', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final preferences = await Preferences.open();
      expect(preferences.language, isNull);
      GrigriStore open(Preferences p) => storeFor(sampleApi(), preferences: p);

      open(preferences).locale = const Locale('ca');
      await pumpEventQueue();
      expect(open(await Preferences.open()).locale, const Locale('ca'));

      open(preferences).locale = null;
      await pumpEventQueue();
      expect(open(await Preferences.open()).locale, isNull);

      // A language this version doesn't speak follows the device.
      await preferences.setLanguage('xx');
      expect(open(await Preferences.open()).locale, isNull);
    });
  });
}
