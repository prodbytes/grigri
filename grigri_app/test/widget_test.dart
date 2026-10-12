import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/seed.dart';
import 'package:grigri_app/main.dart';
import 'package:grigri_app/model/climber.dart';
import 'package:grigri_app/ui/common.dart';
import 'package:grigri_app/ui/profile_editor.dart';

// The demo data (lib/data/seed.dart), on a fixed Monday.
final now = DateTime(2026, 10, 12, 10);

Future<GrigriStore> pumpApp(
  WidgetTester tester, {
  bool siuranaFirst = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final store = GrigriStore(demoState(now), clock: () => now);
  if (siuranaFirst) passToSiurana(store);
  await tester.pumpWidget(GrigriApp(store: store));
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
    expect(find.text('Evening bouldering session'), findsOneWidget);
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
      find.text('Siurana sport day'),
      const Offset(-600, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(store.state.passed, contains('siurana-saturday'));
    expect(find.text('Siurana sport day'), findsNothing);
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
    expect(find.text("You're in: Siurana sport day"), findsOneWidget);
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
    await tester.tap(find.text('Sunday at Siurana'));
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

  testWidgets('a new plan shows up in Plans', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New plan'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Gym night',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Crag or gym'),
      'Climbing gym',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Gym night'), findsOneWidget);
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
}
