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
