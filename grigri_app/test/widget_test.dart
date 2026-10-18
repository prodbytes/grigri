import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/app_store.dart';
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
import 'package:grigri_app/model/report.dart';
import 'package:grigri_app/ui/admin_screen.dart';
import 'package:grigri_app/ui/chat_media.dart';
import 'package:grigri_app/ui/chat_screen.dart';
import 'package:grigri_app/ui/common.dart';
import 'package:grigri_app/ui/gear_editor.dart';
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
  AppStore? appStore,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final store = storeFor(
    api,
    signedIn: signedIn,
    mode: mode,
    deviceLocation: deviceLocation,
    appStore: appStore,
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

    testWidgets('deleting my account asks first, then lands on sign-in', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tapTab(tester, 'Me');
      final delete = find.widgetWithText(TextButton, 'Delete account');
      await tester.scrollUntilVisible(delete, 300);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      // What goes, and Apple's subscriptions are cancelled in Settings.
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining('your profile and photos'), findsOneWidget);
      expect(find.textContaining("iPhone's Settings"), findsOneWidget);
      // Cancel keeps the account.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('DELETE /api/me')));
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      // The button waits for the box to be ticked.
      final confirm = find.widgetWithText(FilledButton, 'Delete for good');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.text("I understand this can't be undone"));
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(api.calls, contains('DELETE /api/me'));
      expect(api.meId, isNull);
      expect(api.sessions, isEmpty);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('a failed delete says so and keeps me signed in', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tapTab(tester, 'Me');
      final delete = find.widgetWithText(TextButton, 'Delete account');
      await tester.scrollUntilVisible(delete, 300);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text("I understand this can't be undone"));
      await tester.pumpAndSettle();
      api.failNext = const ApiException(503, 'Stripe is down');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete for good'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't delete your account. Try again."),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(api.meId, isNotNull);
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

    testWidgets('an open plan says so, and asking to join it matches at once', (
      tester,
    ) async {
      final api = sampleApi();
      final plan = api.plans['boulder-night']!;
      api.addPlan(plan.copyWith(type: PlanType.open));
      final store = await pumpApp(tester, api);
      expect(find.text('Open: join at once'), findsOneWidget);
      await tester.tap(find.byTooltip('Ask to join'));
      await tester.pumpAndSettle();
      expect(find.text("It's a match!"), findsOneWidget);
      expect(api.plans['boulder-night']!.memberIds, contains('me'));
      expect(store.waiting, isEmpty);
    });

    testWidgets("a private plan's card says Shared at the top", (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      final pill = find.byKey(const ValueKey('type boulder-night'));
      expect(pill, findsOneWidget);
      expect(
        find.descendant(of: pill, matching: find.text('Shared')),
        findsOneWidget,
      );
    });

    testWidgets('a guided plan shows its price on the card', (tester) async {
      final api = sampleApi();
      final plan = api.plans['boulder-night']!;
      api.addPlan(
        plan.copyWith(
          type: PlanType.guided,
          price: () => const Price(amount: 45, currency: 'EUR'),
        ),
      );
      await pumpApp(tester, api);
      expect(find.textContaining('Guided ·'), findsOneWidget);
      expect(find.textContaining('45'), findsWidgets);
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

    testWidgets('the gear section checks the group\'s gear against what the '
        'plan needs, and says discreetly what\'s missing', (tester) async {
      await openPlan(tester);
      final gear = find.byKey(const ValueKey('plan gear'));
      await tester.scrollUntilVisible(
        gear,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // Sport, for two: I have a rope and quickdraws; Robin listed none.
      expect(
        find.descendant(of: gear, matching: find.text('No gear listed')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: gear, matching: find.text('Rope · Quickdraws')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Some gear is missing: Belay device, Harness, Climbing shoes',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Crash pad'), findsNothing);
    });

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
      // The plan screen is a lazy list: scrolled to its end, below the
      // area guide, everything has been built.
      Future<void> toTheEnd() async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
        await tester.pumpAndSettle();
      }

      await openPlan(tester);
      await toTheEnd();
      expect(find.byKey(const ValueKey('route finder')), findsNothing);
      await openPlan(tester, premium: true);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('route finder')),
        300,
      );
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
      // The editor's list builds lazily: scroll until the button is built.
      await tester.dragUntilVisible(
        button,
        find.byType(ListView).last,
        const Offset(0, -300),
      );
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

    testWidgets('without Premium, Guided is off in the editor', (tester) async {
      await pumpApp(tester, sampleApi());
      await openNewPlan(tester);
      final guided = find.byKey(const ValueKey('type guided'));
      await tester.dragUntilVisible(
        guided,
        find.byType(ListView).last,
        const Offset(0, -300),
      );
      expect(tester.widget<ChoiceChip>(guided).onSelected, isNull);
      expect(find.text('Guided plans are for Grigri Premium.'), findsOneWidget);
    });

    testWidgets('a guided plan needs a price; an open one says who joins', (
      tester,
    ) async {
      // Guided plans are Premium's.
      final api = sampleApi()..myPremium = const Premium(active: true);
      await pumpApp(tester, api);
      await openNewPlan(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sector, crag or gym'),
        'Guide Wall',
      );
      final guided = find.byKey(const ValueKey('type guided'));
      await tester.dragUntilVisible(
        guided,
        find.byType(ListView).last,
        const Offset(0, -300),
      );
      await tester.tap(find.byKey(const ValueKey('type open')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Anyone can join at once'), findsOneWidget);
      await tester.tap(guided);
      await tester.pumpAndSettle();
      expect(find.textContaining('Only you answer'), findsOneWidget);
      await publish(tester);
      expect(
        find.text('Enter a price above 0, with at most two decimals'),
        findsOneWidget,
      );
      expect(api.plans.values.where((p) => p.place == 'Guide Wall'), isEmpty);
      await tester.enterText(find.byKey(const ValueKey('price')), '45,50');
      await publish(tester);
      final plan = api.plans.values.firstWhere((p) => p.place == 'Guide Wall');
      expect(plan.type, PlanType.guided);
      expect(plan.price, const Price(amount: 45.5, currency: 'EUR'));
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
      await tester.scrollUntilVisible(
        find.text('Cancel the plan'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
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
      // Opening the profile uses rbacr's kept answer.
      expect(api.calls, contains('GET /api/premium'));
      expect(api.calls, isNot(contains('GET /api/premium?fresh=1')));
      expect(find.text('\$20 a month'), findsOneWidget);
      expect(find.text('\$200 a year'), findsOneWidget);
      await tester.ensureVisible(find.text('\$200 a year'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('\$200 a year'));
      await tester.pumpAndSettle();
      expect(api.opened, [Uri.parse('https://checkout.stripe.test/yearly')]);

      // Back from Checkout: asked afresh, not paid yet.
      api.calls.clear();
      await StoreScope.read(
        tester.element(find.byKey(const ValueKey('premium card'))),
      ).refreshPremium();
      await tester.pumpAndSettle();
      expect(api.calls, contains('GET /api/premium?fresh=1'));

      // Stripe told the API: checking again shows it.
      api.myPremium = Premium(
        active: true,
        plan: PremiumPlan.yearly,
        until: DateTime(2031, 5, 1),
        source: PremiumSource.stripe,
      );
      await tester.ensureVisible(find.text("I've paid: check again"));
      await tester.pumpAndSettle();
      api.calls.clear();
      await tester.tap(find.text("I've paid: check again"));
      await tester.pumpAndSettle();
      expect(api.calls.first, 'GET /api/premium?fresh=1');
      expect(find.text('Premium: renews on May 1, 2031'), findsOneWidget);
      // Premium showed: later refreshes use the kept answer again.
      api.calls.clear();
      await StoreScope.read(
        tester.element(find.byKey(const ValueKey('premium card'))),
      ).refreshPremium();
      await tester.pumpAndSettle();
      expect(api.calls, contains('GET /api/premium'));
      expect(api.calls, isNot(contains('GET /api/premium?fresh=1')));
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

    // The first one: the Premium card's (Profile also ends with a
    // "Privacy policy" link of its own).
    Future<void> tapText(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'on iOS: App Store prices, its terms, no Stripe; buying makes me Premium',
      (tester) async {
        final api = sampleApi();
        final appStore = FakeAppStore();
        await pumpApp(tester, api, appStore: appStore);
        await openProfile(tester);
        // The App Store's localized prices, not Stripe's, and no Stripe.
        expect(find.text('\$19.99 a month'), findsOneWidget);
        expect(find.text('\$199.99 a year'), findsOneWidget);
        expect(find.text('\$20 a month'), findsNothing);
        expect(find.textContaining('Stripe'), findsNothing);
        expect(find.text("I've paid: check again"), findsNothing);
        // Apple's required disclosures, next to the buttons.
        expect(
          find.textContaining(
            'auto-renewing subscription: \$19.99 a month, \$199.99 a year',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Manage or cancel it in your App Store account'),
          findsOneWidget,
        );
        await tapText(tester, 'Privacy policy');
        await tapText(tester, 'Terms of use (EULA)');
        expect(api.opened, [privacyPolicyUrl, appleEulaUrl]);
        expect(find.text('Restore purchases'), findsOneWidget);

        await tapText(tester, '\$199.99 a year');
        // Bought for my account, sent to the API, then finished.
        expect(appStore.bought, [
          'com.nu01.grigri.premium.yearly for ${api.appleAccountToken}',
        ]);
        expect(api.appleTransactions, [
          'jws|com.nu01.grigri.premium.yearly|${api.appleAccountToken}',
        ]);
        expect(appStore.completed, hasLength(1));
        expect(find.text('Premium: renews on May 1, 2031'), findsOneWidget);
        // Managed in the App Store, not Stripe's portal.
        await tapText(tester, 'Manage subscription');
        expect(api.opened.last, appStoreSubscriptionsUrl);
        expect(api.calls, isNot(contains('POST /api/premium/portal')));
        expect(api.calls, isNot(contains('POST /api/premium/checkout')));
      },
    );

    testWidgets('on iOS: cancelling the App Store sheet changes nothing', (
      tester,
    ) async {
      final api = sampleApi();
      final appStore = FakeAppStore()..outcome = StorePurchaseStatus.canceled;
      await pumpApp(tester, api, appStore: appStore);
      await openProfile(tester);
      await tapText(tester, '\$19.99 a month');
      expect(api.appleTransactions, isEmpty);
      expect(find.text('\$19.99 a month'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '\$19.99 a month'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('on iOS: no products, no buttons; the App Store is down', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api, appStore: FakeAppStore(prices: {}));
      await openProfile(tester);
      expect(
        find.text("The App Store can't be reached right now."),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('premium card')),
          matching: find.byType(FilledButton),
        ),
        findsNothing,
      );
      expect(find.text('Restore purchases'), findsOneWidget);
    });

    testWidgets('on iOS: Restore purchases sends my subscription to the API', (
      tester,
    ) async {
      final api = sampleApi();
      final appStore = FakeAppStore();
      await pumpApp(tester, api, appStore: appStore);
      await openProfile(tester);
      // Nothing to restore yet.
      await tapText(tester, 'Restore purchases');
      expect(
        find.text('No App Store subscription to restore.'),
        findsOneWidget,
      );
      appStore.owned = [
        StorePurchase(
          productId: 'com.nu01.grigri.premium.monthly',
          status: StorePurchaseStatus.restored,
          signedTransaction:
              'jws|com.nu01.grigri.premium.monthly|${api.appleAccountToken}',
        ),
      ];
      await tapText(tester, 'Restore purchases');
      expect(api.appleTransactions, hasLength(1));
      expect(find.text('Premium: renews on May 1, 2031'), findsOneWidget);
    });

    testWidgets("on iOS: another account's purchase is refused, and finished", (
      tester,
    ) async {
      final api = sampleApi();
      final appStore = FakeAppStore();
      await pumpApp(tester, api, appStore: appStore);
      await openProfile(tester);
      const theirs = StorePurchase(
        productId: 'com.nu01.grigri.premium.monthly',
        status: StorePurchaseStatus.purchased,
        signedTransaction:
            'jws|com.nu01.grigri.premium.monthly|'
            '11111111-2222-8333-8444-555555555555',
        needsCompleting: true,
      );
      appStore.report([theirs]);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'this App Store purchase was made from another Grigri account',
        ),
        findsOneWidget,
      );
      expect(appStore.completed, [theirs]);
      expect(find.text('\$19.99 a month'), findsOneWidget);
    });

    testWidgets(
      'on iOS: a purchase that failed on its way to the API is left for later',
      (tester) async {
        final api = sampleApi();
        final appStore = FakeAppStore();
        await pumpApp(tester, api, appStore: appStore);
        await openProfile(tester);
        api.failNext = const ApiException(503, 'try later');
        await tapText(tester, '\$19.99 a month');
        expect(appStore.completed, isEmpty);
        // StoreKit hands it over again (next launch): now it goes through.
        appStore.report([
          StorePurchase(
            productId: 'com.nu01.grigri.premium.monthly',
            status: StorePurchaseStatus.purchased,
            signedTransaction:
                'jws|com.nu01.grigri.premium.monthly|${api.appleAccountToken}',
            needsCompleting: true,
          ),
        ]);
        await tester.pumpAndSettle();
        expect(appStore.completed, hasLength(1));
        expect(find.text('Premium: renews on May 1, 2031'), findsOneWidget);
      },
    );

    testWidgets(
      'on iOS: a subscription bought through Stripe shows, without a link out',
      (tester) async {
        final api = sampleApi()
          ..myPremium = Premium(
            active: true,
            plan: PremiumPlan.monthly,
            until: DateTime(2030, 6, 1),
            source: PremiumSource.stripe,
          );
        await pumpApp(tester, api, appStore: FakeAppStore());
        await openProfile(tester);
        expect(find.text('Premium: renews on Jun 1, 2030'), findsOneWidget);
        expect(find.text('Manage subscription'), findsNothing);
      },
    );

    testWidgets(
      'elsewhere, an App Store subscription is managed in the App Store',
      (tester) async {
        final api = sampleApi()
          ..myPremium = Premium(
            active: true,
            plan: PremiumPlan.monthly,
            until: DateTime(2030, 6, 1),
            source: PremiumSource.apple,
          );
        await pumpApp(tester, api);
        await openProfile(tester);
        await tapText(tester, 'Manage subscription');
        expect(api.opened, [appStoreSubscriptionsUrl]);
      },
    );
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

    test('ads come about every adEvery plans, a little at random', () async {
      final api = sampleApi()
        ..adEvery = 10
        ..addAd(chalk());
      for (var i = 0; i < 6; i++) {
        api.addAd(
          Ad(
            id: 'ad-$i',
            ownerId: 'robin',
            text: 'Ad $i',
            link: Uri.parse('https://ad$i.example.com'),
            status: AdStatus.approved,
          ),
        );
      }
      for (var i = 0; i < 60; i++) {
        api.addPlan(
          Plan(
            id: 'many$i',
            organizerId: 'robin',
            discipline: Discipline.sport,
            place: 'Many $i',
            start: inDays(5 + i % 20),
            end: inDays(5 + i % 20, 16),
            grades: const GradeRange(GradeScale.routes, 6, 12),
            memberIds: const ['robin'],
          ),
        );
      }
      final store = storeFor(api, random: math.Random(7));
      await store.start();
      List<int> gaps() {
        final out = <int>[];
        var run = 0;
        for (final item in store.deck) {
          if (item is DeckAd) {
            out.add(run);
            run = 0;
          } else {
            run++;
          }
        }
        return out;
      }

      final first = gaps();
      expect(first.length, greaterThanOrEqualTo(4));
      for (final g in first) {
        expect(g, inInclusiveRange(7, 13));
      }
      expect(first.toSet().length, greaterThan(1), reason: 'randomized');
      // Stable as the deck rebuilds.
      expect(gaps(), first);
    });

    test('a skipped ad never comes back; an opened one does after ⟳', () async {
      final api = sampleApi()
        ..adEvery = 1
        ..addAd(chalk())
        ..addAd(
          Ad(
            id: 'ad-rope',
            ownerId: 'robin',
            text: 'Rope sale',
            link: Uri.parse('https://rope.example.com'),
            status: AdStatus.approved,
          ),
        );
      final store = storeFor(api);
      await store.start();
      List<String> ads() => [
        for (final i in store.deck)
          if (i is DeckAd) i.ad.id,
      ];
      expect(ads(), contains('ad-chalk'));
      await store.swipeAd(api.ads['ad-chalk']!, open: false);
      await store.swipeAd(api.ads['ad-rope']!, open: true);
      expect(api.skippedAds, {'ad-chalk'});
      expect(ads(), isEmpty);
      await store.refreshDiscover(again: true);
      expect(ads(), ['ad-rope']);
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
      await tester.ensureVisible(find.text('Send for review'));
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

      // Where it shows: everywhere, until a region is added.
      expect(find.textContaining('Everywhere.'), findsOneWidget);
      const gorge = AdRegion(
        name: 'Gorge Valley, Spain',
        label: 'Gorge Valley, Somewhere County, Spain',
        south: 41.2,
        west: 0.9,
        north: 41.3,
        east: 1.0,
      );
      api.places['Gorge Valley'] = [gorge];
      await tester.ensureVisible(find.text('Add a region'));
      await tester.tap(find.text('Add a region'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('region search')),
        'Gorge Valley',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(
        find.text('Gorge Valley, Somewhere County, Spain'),
        findsOneWidget,
      );
      await tester.tap(find.text('Gorge Valley, Spain'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ad region Gorge Valley, Spain')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Send for review'));
      await tester.tap(find.text('Send for review'));
      await tester.pumpAndSettle();
      expect(find.text('Sent: an admin will review it.'), findsOneWidget);
      expect(find.text('Waiting for review'), findsOneWidget);
      expect(find.text('Shows in Gorge Valley, Spain'), findsOneWidget);
      final saved = api.ads.values.single;
      expect(saved.text, 'Guided days in the gorge');
      expect(saved.link, Uri.parse('https://guides.example.com'));
      expect(saved.regions, [gorge]);

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
      expect(api.calls.where((c) => c.contains('/admin/climbers/')), isEmpty);

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

      await tester.tap(find.widgetWithText(TextButton, 'Save'));
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
      // Gear has its own editor now.
      expect(find.byTooltip('Add a gear photo'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(asked, [640]);
      expect(
        api.calls
            .where(
              (c) =>
                  c.contains('photos') ||
                  c.contains('bucket') ||
                  c == 'PUT /api/me',
            )
            .toList(),
        [
          'POST /api/photos',
          'POST https://bucket.test/ (me/profile-3)',
          'PUT /api/me',
        ],
      );
      expect(store.me.photo, 'me/profile-3');
      expect(store.me.gear, me.gear);
    });

    testWidgets('the gear editor: gear the group shares and my own, and '
        'photos, uploaded then saved with the profile', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final api = sampleApi();
      api.climbers['me'] = me.copyWith(photo: 'me/profile-0');
      final store = storeFor(api);
      await store.start();
      final asked = <double>[];
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GearEditor(
              pick: (source, maxSide) async {
                asked.add(maxSide);
                return png;
              },
            ),
          ),
        ),
      );
      expect(find.text('FOR THE GROUP'), findsOneWidget);
      expect(find.text('YOUR OWN'), findsOneWidget);
      await tester.tap(find.text('Harness'));
      await tester.tap(find.text('Quickdraws'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(asked, [1080, 1080]);
      // Two photos picked, the first removed: the other's POST
      // /api/photos and upload, then the profile with its key, keeping my
      // photo.
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
        'POST https://bucket.test/ (me/gear-3)',
        'PUT /api/me',
      ]);
      expect(store.me.photo, 'me/profile-0');
      expect(store.me.gear, {Gear.rope, Gear.harness});
      expect(store.me.gearPhotos, ['me/gear-3']);
      expect(api.uploads['me/gear-3'], png);
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
            home: GearEditor(),
          ),
        ),
      );
      expect(find.byTooltip('Add a gear photo'), findsNothing);
    });

    testWidgets('the grade system is its own section, with examples', (
      tester,
    ) async {
      final store = storeFor(sampleApi());
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
      final page = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('🧗 6a  🪨 7A'),
        200,
        scrollable: page,
      );
      // A section of its own, the disciplines in the next one.
      expect(find.text('GRADE SYSTEM'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('WHAT YOU CLIMB')).dy,
        greaterThan(tester.getTopLeft(find.text('🧗 6a  🪨 7A')).dy),
      );
      expect(find.text('🧗 6a  🪨 7A'), findsOneWidget);
      expect(find.text('🧗 5.10b  🪨 V6'), findsOneWidget);
      await tester.tap(find.text('American'));
      await tester.pumpAndSettle();
      expect(store.gradeSystem, GradeSystem.american);
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

  testWidgets('the Profile tab has a gear card that opens the gear editor', (
    tester,
  ) async {
    final api = sampleApi();
    api.climbers['me'] = me.copyWith(gear: {});
    await pumpApp(tester, api);
    await tapTab(tester, 'Me');
    await tester.scrollUntilVisible(find.text('Add your gear'), 200);
    expect(find.textContaining('Add the gear you own'), findsOneWidget);
    await tester.tap(find.text('Add your gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crash pad'));
    await tester.tap(find.text('Climbing shoes'));
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(api.climbers['me']!.gear, {Gear.crashPad, Gear.shoes});
    expect(find.text('Edit gear'), findsOneWidget);
    expect(find.text('Crash pad'), findsOneWidget);
    expect(find.text('Climbing shoes'), findsOneWidget);
  });

  testWidgets('the profile ends with the privacy policy and support links', (
    tester,
  ) async {
    final api = sampleApi();
    await pumpApp(tester, api);
    await tapTab(tester, 'Me');
    await tester.scrollUntilVisible(find.text('Support'), 200);
    await tester.ensureVisible(find.text('Support'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy policy'), findsOneWidget);

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();
    expect(api.opened.map((url) => url.path), [
      '/privacy.html',
      '/support.html',
    ]);
    expect(
      api.opened.every((url) => url.scheme == 'https' && url.host.isNotEmpty),
      isTrue,
    );
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
      await tester.ensureVisible(find.text('Español'));
      await tester.pumpAndSettle();
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

  group('reporting and blocking (specs/moderation.md)', () {
    Finder topCardMenu(String planId) => find.descendant(
      of: find.byKey(ValueKey('top-plan:$planId')),
      matching: find.byKey(const ValueKey('moderation menu')),
    );

    testWidgets('a plan is reported from its screen with a reason, then '
        'thanks; the deck\'s card has no menu', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      expect(topCardMenu('boulder-night'), findsNothing);
      final store = storeFor(api);
      await store.start();
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PlanScreen(planId: 'boulder-night'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('moderation menu')));
      await tester.pumpAndSettle();
      expect(find.text('Block Kit Marlow'), findsOneWidget);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Why are you reporting this?'), findsOneWidget);
      // No reason yet: nothing to send.
      final send = find.widgetWithText(FilledButton, 'Send report');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      await tester.tap(find.text('Spam'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('report text')),
        'Selling gear, not climbing',
      );
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/reports'));
      final report = api.reports.single;
      expect(report.kind, ReportKind.plan);
      expect(report.targetId, 'boulder-night');
      expect(report.subjectId, 'kit');
      expect(report.reason, ReportReason.spam);
      expect(report.text, 'Selling gear, not climbing');
      expect(find.text("Thanks, we'll review it within 24 hours."), findsOne);
    });

    testWidgets('blocking from a profile sheet takes their plans off my deck; '
        'Profile → Blocked people unblocks', (tester) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('top-plan:boulder-night')),
          matching: find.text('Kit Marlow'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byKey(const ValueKey('moderation menu')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Kit Marlow'));
      await tester.pumpAndSettle();
      expect(find.text('Block Kit Marlow?'), findsOneWidget);
      expect(find.textContaining("They aren't told."), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/blocks/kit'));
      expect(api.personBlocks, {'kit'});
      expect(find.text('Kit Marlow is blocked.'), findsOneWidget);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Block Hall'), findsNothing);
      expect(find.text('Grey Cliffs'), findsOneWidget);

      await tapTab(tester, 'Me');
      final entry = find.byKey(const ValueKey('blocked people'));
      await tester.scrollUntilVisible(entry, 200);
      // The "blocked" snackbar would cover it.
      ScaffoldMessenger.of(tester.element(entry)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('blocked kit'));
      expect(
        find.descendant(of: row, matching: find.text('Kit Marlow')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: row, matching: find.text('Unblock')),
      );
      await tester.pumpAndSettle();
      expect(api.calls, contains('DELETE /api/blocks/kit'));
      expect(api.personBlocks, isEmpty);
      expect(find.text("You haven't blocked anyone."), findsOneWidget);
    });

    testWidgets("a long press on someone's message reports it, or blocks "
        'them: their messages then hide', (tester) async {
      final api = sampleApi();
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: ['robin', 'me'],
      );
      api.say('crag-day', 'robin', 'Something rude');
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      await tester.tap(find.text('Grey Cliffs'));
      await tester.pumpAndSettle();
      final message = api.allMessages.last;

      await tester.longPress(find.text('Something rude'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Send report'));
      await tester.pumpAndSettle();
      final report = api.reports.single;
      expect(report.kind, ReportKind.message);
      expect(report.targetId, message.id);
      expect(report.planId, 'crag-day');
      expect(report.reason, ReportReason.harassment);

      await tester.longPress(find.text('Something rude'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Robin Vale'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();
      expect(api.personBlocks, {'robin'});
      expect(find.text('Something rude'), findsNothing);
    });

    testWidgets('blocking from a request card declines the request', (
      tester,
    ) async {
      final api = sampleApi();
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      await tester.tap(find.text('Wall Works'));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('request my-gym/jules'));
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey('moderation menu')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Jules Fern'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();
      expect(api.requestsById['my-gym/jules']!.rejected, isTrue);
      expect(find.text('WANTS TO JOIN · YOUR ANSWER'), findsNothing);
    });

    testWidgets('my own things have no Report or Block', (tester) async {
      await pumpApp(tester, sampleApi());
      await tapTab(tester, 'Plans');
      await tester.tap(find.text('Wall Works').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('moderation menu')), findsNothing);
    });

    testWidgets('an ad on the deck is reported from its ⋮', (tester) async {
      final api = sampleApi()
        ..adEvery = 1
        ..addAd(
          Ad(
            id: 'ad-1',
            ownerId: 'sasha',
            text: 'Chalk sale',
            link: Uri.parse('https://example.com/chalk'),
            status: AdStatus.approved,
          ),
        );
      await pumpApp(tester, api);
      await tester.tap(find.byTooltip('Pass'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('top-ad:ad-1')),
          matching: find.byKey(const ValueKey('moderation menu')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inappropriate content'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Send report'));
      await tester.pumpAndSettle();
      expect(api.reports.single.kind, ReportKind.ad);
      expect(api.reports.single.subjectId, 'sasha');
    });

    testWidgets('the filter\'s refusal is worded by the app', (tester) async {
      final api = sampleApi();
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: ['robin', 'me'],
      );
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      await tester.tap(find.text('Grey Cliffs'));
      await tester.pumpAndSettle();
      api.failNext = const ApiException(
        400,
        "objectionable: text has words Grigri doesn't allow; please keep it "
        'friendly',
      );
      await tester.enterText(find.byType(TextField), 'something');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Please keep it friendly: that has words Grigri doesn't allow.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('admins are told, see what was reported, and dismiss, '
        'remove or block', (tester) async {
      final api = sampleApi(admin: true);
      Report report(String id, ReportKind kind, String subject, String text) =>
          Report(
            id: id,
            kind: kind,
            targetId: '$id-target',
            subjectId: subject,
            reporterId: 'jules',
            reason: ReportReason.harassment,
            text: 'Not nice',
            time: DateTime.now().toUtc(),
            content: ReportContent(text: text),
          );
      api.reports.addAll([
        report('r1', ReportKind.plan, 'kit', 'Plan notes one'),
        report('r2', ReportKind.message, 'robin', 'Message two'),
        report('r3', ReportKind.profile, 'sasha', 'Bio three'),
      ]);
      (api.noticesFor['me'] ??= []).add(
        Notice(
          id: 'reports',
          kind: NoticeKind.report,
          planId: '',
          planTitle: '',
          time: DateTime.now().toUtc(),
        ),
      );
      await pumpApp(tester, api);
      await tapTab(tester, 'Alerts');
      expect(find.text('New reports to review'), findsOneWidget);
      await tester.tap(find.text('New reports to review'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('GET /api/admin/reports'));
      final r1 = find.byKey(const ValueKey('report r1'));
      expect(
        find.descendant(of: r1, matching: find.text('Plan notes one')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: r1, matching: find.text('Reported by Jules Fern')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: r1, matching: find.text('Harassment')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(of: r1, matching: find.text('Dismiss')));
      await tester.pumpAndSettle();
      expect(api.resolved, ['r1 dismiss']);
      expect(r1, findsNothing);

      final r2 = find.byKey(const ValueKey('report r2'));
      await tester.tap(
        find.descendant(of: r2, matching: find.text('Remove content')),
      );
      await tester.pumpAndSettle();
      expect(api.resolved, ['r1 dismiss', 'r2 remove']);

      final r3 = find.byKey(const ValueKey('report r3'));
      await tester.tap(
        find.descendant(of: r3, matching: find.text('Block climber')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Block Sasha Brook?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Block'));
      await tester.pumpAndSettle();
      expect(api.resolved.last, 'r3 block');
      expect(api.blocked, {'sasha'});
      expect(find.text('No reports to review.'), findsOneWidget);
    });
  });

  group('the Grigri team chat', () {
    const welcome =
        "Thanks for climbing with Grigri! We'd love to hear what you think: "
        "what works, what doesn't, what you'd like next. Write to us here "
        'anytime.';

    testWidgets('is on top of Chats, with its welcome, even with no plans', (
      tester,
    ) async {
      final api = FakeApi()
        ..meId = 'me'
        ..addClimber(me);
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      final tile = find.byKey(const ValueKey('team chat'));
      expect(
        find.descendant(of: tile, matching: find.text('Grigri team')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.text(welcome)),
        findsOneWidget,
      );
      // The plans' empty state stays below it.
      expect(find.text('No chats yet'), findsOneWidget);
      expect(
        tester.getTopLeft(tile).dy,
        lessThan(tester.getTopLeft(find.text('No chats yet')).dy),
      );

      // Opening it: the welcome first; nothing was stored for it.
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('team welcome')), findsOneWidget);
      expect(find.text(welcome), findsOneWidget);
      expect(api.allTeamMessages, isEmpty);
      expect(api.calls, isNot(contains('POST /api/team/messages')));

      await tester.enterText(
        find.byKey(const ValueKey('team input')),
        'Love it, could you add a map?',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/team/messages'));
      expect(api.allTeamMessages.single.text, 'Love it, could you add a map?');
      expect(find.text('Love it, could you add a map?'), findsOneWidget);
    });

    testWidgets("the team's answer shows as Grigri team, and badges Chats", (
      tester,
    ) async {
      final api = sampleApi();
      api.teamWrites('me', 'Is there a dark mode?');
      api.teamWrites('me', 'Not yet, but soon!', adminId: 'robin');
      await pumpApp(tester, api);
      // A badge on Chats for the answer.
      final chats = find.ancestor(
        of: find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Chats'),
        ),
        matching: find.byType(NavigationDestination),
      );
      expect(
        tester
            .widgetList<Badge>(
              find.descendant(of: chats, matching: find.byType(Badge)),
            )
            .any((b) => b.isLabelVisible),
        isTrue,
      );
      await tapTab(tester, 'Chats');
      await tester.tap(find.byKey(const ValueKey('team chat')));
      await tester.pumpAndSettle();
      expect(find.text('Not yet, but soon!'), findsOneWidget);
      // Never which admin: Robin's name isn't anywhere.
      expect(find.textContaining('Robin'), findsNothing);
      expect(find.text('Grigri team'), findsWidgets);
      // Opening it read it.
      expect(api.calls, contains('POST /api/team/read'));
    });

    testWidgets("admins see each climber's team chat and answer as the team", (
      tester,
    ) async {
      final api = sampleApi(admin: true);
      api.teamWrites('kit', 'The deck is great!');
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      final kitChat = find.byKey(const ValueKey('team chat kit'));
      await tester.scrollUntilVisible(kitChat, 200);
      expect(find.text('TEAM CHATS'), findsOneWidget);
      expect(
        find.descendant(of: kitChat, matching: find.text('The deck is great!')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: kitChat, matching: find.text('To answer')),
        findsOneWidget,
      );
      await tester.tap(kitChat);
      await tester.pumpAndSettle();
      expect(find.text('The deck is great!'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('team input')),
        'Thanks, Kit!',
      );
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('POST /api/admin/team/kit/messages'));
      final answer = api.allTeamMessages.last;
      expect(answer.fromTeam, isTrue);
      expect(answer.adminId, 'me');
      // The admins see who answered.
      expect(find.text('You for the team'), findsOneWidget);
    });

    testWidgets("nobody but admins sees others' team chats", (tester) async {
      final api = sampleApi();
      api.teamWrites('kit', 'Just for the team');
      await pumpApp(tester, api);
      await tapTab(tester, 'Chats');
      expect(find.text('TEAM CHATS'), findsNothing);
      expect(find.text('Just for the team'), findsNothing);
      expect(api.calls, isNot(contains('GET /api/admin/team')));
    });
  });
}
