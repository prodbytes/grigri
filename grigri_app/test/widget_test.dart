import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/roles.dart';
import 'package:grigri_app/data/seed.dart';
import 'package:grigri_app/main.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/climber.dart';
import 'package:grigri_app/ui/common.dart';
import 'package:grigri_app/ui/profile_editor.dart';
import 'package:rbacr/rbacr.dart';

// The demo data (lib/data/seed.dart), on a fixed Monday.
final now = DateTime(2026, 10, 12, 10);

Future<GrigriStore> pumpApp(
  WidgetTester tester, {
  bool siuranaFirst = false,
  Roles roles = const Roles.none(),
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final store = GrigriStore(demoState(now), clock: () => now);
  if (siuranaFirst) passToSiurana(store);
  await tester.pumpWidget(GrigriApp(store: store, roles: roles));
  return store;
}

/// Passes the two sooner plans, so Siurana's (whose only member, Marta,
/// accepts) tops the Discover deck.
void passToSiurana(GrigriStore store) => store
  ..pass('tuesday-bouldering')
  ..pass('after-work-leads');

/// A tiny valid PNG, standing in for a picked photo.
final photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAwS2OUAAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('Discover shows the best-fitting plan first, highlighted', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('THE PLAN'), findsWidgets);
    expect(find.text('Boulder gym'), findsOneWidget);
    expect(find.text('Lena Vogel, 26'), findsOneWidget);
    expect(find.text('Your grades'), findsWidgets);
  });

  testWidgets(
    'joining a plan whose group accepts shows the match, then the chat',
    (tester) async {
      final store = await pumpApp(tester, siuranaFirst: true);
      await tester.tap(find.byTooltip('Ask to join'));
      await tester.pumpAndSettle();
      expect(find.text("It's a match!"), findsOneWidget);
      expect(store.plan('siurana-saturday')!.memberIds, contains('me'));

      await tester.tap(find.text('Open the group chat'));
      await tester.pumpAndSettle();
      expect(find.text('Message the group'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Count me in!');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Count me in!'), findsOneWidget);
    },
  );

  testWidgets('dragging a card left passes on the plan', (tester) async {
    final store = await pumpApp(tester, siuranaFirst: true);
    await tester.timedDrag(
      find.text('El Pati'),
      const Offset(-600, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(store.state.passed, contains('siurana-saturday'));
    expect(find.text('El Pati'), findsNothing);
  });

  testWidgets('the tabs are Discover, Plans, Chats, Notifications, Profile', (
    tester,
  ) async {
    await pumpApp(tester);
    // They fit a narrow phone (an overflow fails the test).
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label);
    expect(labels, ['Discover', 'Plans', 'Chats', 'Notifications', 'Profile']);
  });

  testWidgets('a request notification opens the chat, to accept there', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Noa Levi wants to join'), findsOneWidget);
    expect(store.unreadNotices, 0);
    await tester.tap(find.text('Noa Levi wants to join'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('request thursday-bouldering/noa'));
    expect(
      find.descendant(of: card, matching: find.text('Lena said yes')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Lena said yes · waiting for You'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: card, matching: find.text('Accept')));
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsOneWidget);
    expect(store.plan('thursday-bouldering')!.memberIds, ['lena', 'me', 'noa']);
  });

  testWidgets('a pending request turns accepted, with a notification', (
    tester,
  ) async {
    var time = now;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final store = GrigriStore(
      demoState(now),
      clock: () => time,
      answerAfter: const Duration(seconds: 10),
    );
    passToSiurana(store);
    await tester.pumpWidget(GrigriApp(store: store));

    await tester.tap(find.byTooltip('Ask to join'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.text('ASKED TO JOIN'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    // The "Asked to join" note goes away.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    time = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsOneWidget);
    await tester.tap(find.text('Keep swiping'));
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Accepted'), findsNWidgets(2));

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text("You're in: El Pati"), findsOneWidget);
    // Mine, and the demo's three requests to join my plans.
    expect(find.text('New'), findsNWidgets(4));
    expect(store.unreadNotices, 0);
  });

  testWidgets('one member declining in the chat turns them down', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.text('2 to answer'), findsOneWidget);
    await tester.tap(find.text('Siurana'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('request my-sunday-siurana/bruno'));
    await tester.tap(find.descendant(of: card, matching: find.text('Decline')));
    await tester.pumpAndSettle();
    expect(store.state.requests['my-sunday-siurana/bruno']!.rejected, isTrue);
    expect(
      find.descendant(of: card, matching: find.text('Declined')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Accept')),
      findsNothing,
    );
  });

  testWidgets('the chat calls out on top who still needs my answer', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siurana'));
    await tester.pumpAndSettle();
    expect(find.text('WANTS TO JOIN · YOUR ANSWER'), findsNWidgets(2));
    // The request cards show the newcomers' grades, written as grades.
    expect(find.textContaining(RegExp(r'^Sport \d')), findsWidgets);
    expect(find.textContaining('Closure'), findsNothing);

    await tester.tap(find.byTooltip('Decline Bruno Costa'));
    await tester.pumpAndSettle();
    expect(store.state.requests['my-sunday-siurana/bruno']!.rejected, isTrue);
    expect(
      find.byKey(const ValueKey('callout my-sunday-siurana/bruno')),
      findsNothing,
    );
    // The card in the messages stays, as the record.
    final card = find.byKey(const ValueKey('request my-sunday-siurana/bruno'));
    expect(
      find.descendant(of: card, matching: find.text('Declined')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Accept Inés Prado'));
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsOneWidget);
    await tester.tap(find.text('Keep swiping'));
    await tester.pumpAndSettle();
    expect(find.text('WANTS TO JOIN · YOUR ANSWER'), findsNothing);
    expect(store.plan('my-sunday-siurana')!.memberIds, ['me', 'ines']);
  });

  testWidgets('after my yes the callout goes, the card waits for the rest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final demo = demoState(now);
    final store = GrigriStore(
      GrigriState(
        meId: demo.meId,
        climbers: demo.climbers,
        plans: demo.plans,
        requests: demo.requests,
        messages: demo.messages,
        // Inés joins my plan, then doesn't answer Bruno.
        policies: {...demo.policies, 'ines': Policy.undecided},
        passed: demo.passed,
        notices: demo.notices,
      ),
      clock: () => now,
    )..accept('my-sunday-siurana/ines');
    await tester.pumpWidget(GrigriApp(store: store));
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Siurana'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 said yes'), findsNothing);
    expect(find.text('0 of 2 said yes'), findsOneWidget);

    await tester.tap(find.byTooltip('Accept Bruno Costa'));
    await tester.pumpAndSettle();
    expect(find.text("It's a match!"), findsNothing);
    expect(find.text('WANTS TO JOIN · YOUR ANSWER'), findsNothing);
    final card = find.byKey(const ValueKey('request my-sunday-siurana/bruno'));
    expect(
      find.descendant(
        of: card,
        matching: find.text('You said yes · waiting for Inés'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the age can be left out of the profile', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('You, 30'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Age (optional)'),
      '',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.me.age, isNull);
    expect(find.text('You'), findsWidgets);
    expect(find.text('You, 30'), findsNothing);
  });

  Future<void> openNewPlan(WidgetTester tester) async {
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
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
    final store = await pumpApp(tester);
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
    expect(find.text('Siurana, Spain'), findsOneWidget);
    await publish(tester);
    final plan = store.myPlans.firstWhere((p) => p.place == 'El Pati');
    expect(plan.sectorId, 'demo:el-pati');
    expect(plan.area, 'Siurana, Spain');
    expect(plan.start.hour, 9);
    expect(plan.end.hour, 17);
    expect(find.text('El Pati'), findsOneWidget);
  });

  testWidgets('a place the index lacks is typed in by hand', (tester) async {
    final store = await pumpApp(tester);
    await openNewPlan(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Sector, crag or gym'),
      'Secret wall',
    );
    await tester.pumpAndSettle();
    await publish(tester);
    final plan = store.myPlans.firstWhere((p) => p.place == 'Secret wall');
    expect(plan.sectorId, isNull);
    expect(plan.area, isEmpty);
  });

  testWidgets('grades switch between European and American', (tester) async {
    final store = await pumpApp(tester);
    await openNewPlan(tester);
    expect(find.text('6a–6c+'), findsOneWidget);
    await tester.tap(find.text('American'));
    await tester.pumpAndSettle();
    expect(find.text('5.10b–5.11c'), findsOneWidget);
    expect(store.gradeSystem, GradeSystem.american);
  });

  testWidgets('the profile has no when or where, and shows the gear', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('You, 30'), findsOneWidget);
    expect(find.text('CLIMBS'), findsOneWidget);
    expect(find.text('GEAR'), findsOneWidget);
    expect(find.text('WHEN'), findsNothing);
    expect(find.text('WHERE'), findsNothing);
    expect(find.textContaining('years climbing'), findsNothing);
  });

  testWidgets('a profile photo and gear photos are saved with the profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final store = GrigriStore(demoState(now), clock: () => now);
    final asked = <double>[];
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: MaterialApp(
          home: ProfileEditor(
            pick: (source, maxSide) async {
              asked.add(maxSide);
              return photo;
            },
          ),
        ),
      ),
    );
    expect(find.text('Home area'), findsNothing);
    expect(find.text('Years climbing'), findsNothing);
    expect(find.text('WHEN YOU CLIMB'), findsNothing);
    expect(find.text('WHERE YOU CLIMB'), findsNothing);

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
    expect(store.me.photo, photo);
    expect(store.me.gearPhotos, [photo]);
  });

  testWidgets('gear photos stop at the most a profile keeps', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final store = GrigriStore(demoState(now), clock: () => now);
    store.updateProfile(
      store.me.copyWith(gearPhotos: List.filled(Climber.maxGearPhotos, photo)),
    );
    await tester.pumpWidget(
      StoreScope(
        store: store,
        child: const MaterialApp(home: ProfileEditor()),
      ),
    );
    expect(find.byTooltip('Add a gear photo'), findsNothing);
  });

  group('the profile ends with my roles, from rbacr', () {
    Future<void> openProfile(WidgetTester tester, Roles roles) async {
      await pumpApp(tester, roles: roles);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('ROLES'), 200);
    }

    testWidgets('as Grigri roles and global ones', (tester) async {
      await openProfile(
        tester,
        Roles(
          () async => const Me(
            email: 'pat.example@example.com',
            root: false,
            globalRoles: ['staff'],
            roles: {
              'grigri': ['premium', 'free'],
              'tabscan': ['owner'],
            },
          ),
        ),
      );
      expect(find.text('free'), findsOneWidget);
      expect(find.text('premium'), findsOneWidget);
      expect(find.text('staff'), findsOneWidget);
      expect(find.text('owner'), findsNothing);
      expect(find.text('As pat.example@example.com'), findsOneWidget);
    });

    testWidgets('or that nobody is signed in', (tester) async {
      await openProfile(tester, const Roles.none());
      expect(
        find.text('Not signed in: your roles show here once you sign in.'),
        findsOneWidget,
      );
    });

    testWidgets("or that rbacr didn't answer, with Retry", (tester) async {
      var calls = 0;
      await openProfile(
        tester,
        Roles(() async {
          if (++calls == 1) throw const RbacrException('unreachable');
          return const Me(
            email: 'pat.example@example.com',
            root: false,
            globalRoles: [],
            roles: {},
          );
        }),
      );
      expect(find.text("Couldn't get your roles from rbacr."), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('No roles in Grigri yet.'), findsOneWidget);
    });
  });
}
