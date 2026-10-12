import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/seed.dart';
import 'package:grigri_app/main.dart';

// The demo data (lib/data/seed.dart), on a fixed Monday.
final now = DateTime(2026, 10, 12, 10);

Future<GrigriStore> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final store = GrigriStore(demoState(now), clock: () => now);
  await tester.pumpWidget(GrigriApp(store: store));
  return store;
}

void main() {
  testWidgets('Discover shows the best-fitting plan first, highlighted', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('THE PLAN'), findsWidgets);
    expect(find.text('Siurana sport day'), findsOneWidget);
    expect(find.text('Marta Soler, 29'), findsOneWidget);
  });

  testWidgets(
    'joining a plan whose group accepts shows the match, then the chat',
    (tester) async {
      final store = await pumpApp(tester);
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
    final store = await pumpApp(tester);
    await tester.timedDrag(
      find.text('Siurana sport day'),
      const Offset(-600, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(store.state.passed, contains('siurana-saturday'));
    expect(find.text('Siurana sport day'), findsNothing);
  });

  testWidgets('accepting the last missing yes in Requests matches the group', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('WANTS TO JOIN'), findsWidgets);
    // Ines and Bruno for my plan first, then Noa for Thursday's.
    await tester.tap(find.byTooltip('Decline'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Decline'));
    await tester.pumpAndSettle();
    expect(find.text('Noa Levi, 24'), findsOneWidget);
    await tester.tap(find.byTooltip('Accept'));
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

    await tester.tap(find.byTooltip('Notifications').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text("You're in: Siurana sport day"), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(store.unreadNotices, 0);
  });

  testWidgets('a member can decline from the plan', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunday at Siurana'));
    await tester.pumpAndSettle();
    expect(find.text('ASKING TO JOIN'), findsOneWidget);
    await tester.tap(find.byTooltip('Decline Bruno Costa'));
    await tester.pumpAndSettle();
    expect(store.state.requests['my-sunday-siurana/bruno']!.rejected, isTrue);
    expect(find.text('Bruno Costa'), findsNothing);
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
}
