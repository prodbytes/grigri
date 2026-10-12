import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/seed.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/plan.dart';

// The demo data's made-up climbers (lib/data/seed.dart), on a fixed Monday.
final now = DateTime(2026, 10, 12, 10);

GrigriStore demo() => GrigriStore(demoState(now), clock: () => now);

void main() {
  group('discover', () {
    test('shows upcoming open plans I am not in, best fits first', () {
      final store = demo();
      final ids = store.discover.map((p) => p.id).toList();
      expect(ids, isNot(contains('my-sunday-siurana')));
      expect(ids, isNot(contains('thursday-bouldering')));
      // Siurana: my grades, my weekend time and my place.
      expect(ids.first, 'siurana-saturday');
      // Margalef's 7a–7c doesn't overlap my 6a–6c+: the worst fit.
      expect(ids.last, 'margalef-project');
    });

    test('a pass takes the plan out of the deck', () {
      final store = demo()..pass('after-work-leads');
      expect(
        store.discover.map((p) => p.id),
        isNot(contains('after-work-leads')),
      );
    });
  });

  group('swiping right on a plan', () {
    test('matches when its only member accepts', () {
      final store = demo();
      final match = store.like('siurana-saturday');
      expect(match, isNotNull);
      expect(match!.plan.memberIds, ['marta', 'me']);
      expect(match.newcomer.id, 'me');
      expect(store.myPlans.map((p) => p.id), contains('siurana-saturday'));
      expect(
        store.messages('siurana-saturday').last.text,
        contains('You joined'),
      );
    });

    test('matches a group only when every member accepts', () {
      final store = demo();
      final match = store.like('montserrat-multipitch');
      // Tomás accepts everyone, Ravi those whose trad grades overlap: mine do.
      expect(match!.plan.memberIds, ['tomas', 'ravi', 'me']);
    });

    test('waits while a member hasn\'t decided', () {
      final store = demo();
      expect(store.like('margalef-project'), isNull);
      expect(store.waiting.map((r) => r.planId), ['margalef-project']);
      expect(
        store.discover.map((p) => p.id),
        isNot(contains('margalef-project')),
      );
    });

    test('is turned down by one member\'s no', () {
      final store = demo();
      // Without trad grades, Ravi (grades must overlap) says no.
      store.updateProfile(
        store.me.copyWith(
          levels: {...store.me.levels}..remove(Discipline.trad),
        ),
      );
      expect(store.like('montserrat-multipitch'), isNull);
      expect(store.waiting, isEmpty);
      expect(store.plan('montserrat-multipitch')!.memberIds, ['tomas', 'ravi']);
    });
  });

  group('reviewing requests', () {
    test('lists people asking to join plans I am in', () {
      final store = demo();
      expect(store.toReview.map((r) => r.id), [
        'my-sunday-siurana/ines',
        'my-sunday-siurana/bruno',
        'thursday-bouldering/noa',
      ]);
    });

    test('accepting the last missing member matches them into the group', () {
      final store = demo();
      final match = store.accept('thursday-bouldering/noa');
      expect(match!.newcomer.id, 'noa');
      expect(match.plan.memberIds, ['lena', 'me', 'noa']);
      expect(
        store.toReview.map((r) => r.id),
        isNot(contains('thursday-bouldering/noa')),
      );
    });

    test('a newcomer must accept the requests still open', () {
      final store = demo();
      // Ines joins my plan, then Bruno must be accepted by both of us:
      // Ines (a made-up climber who accepts everyone) does it herself.
      expect(store.accept('my-sunday-siurana/ines')!.newcomer.id, 'ines');
      final match = store.accept('my-sunday-siurana/bruno');
      expect(match!.plan.memberIds, ['me', 'ines', 'bruno']);
    });

    test('rejecting turns them down for good', () {
      final store = demo()..reject('my-sunday-siurana/bruno');
      expect(
        store.toReview.map((r) => r.id),
        isNot(contains('my-sunday-siurana/bruno')),
      );
      expect(store.plan('my-sunday-siurana')!.memberIds, ['me']);
    });

    test('a full plan takes nobody else', () {
      final store = demo();
      store.updatePlan(store.plan('my-sunday-siurana')!.copyWith(spots: 2));
      store.accept('my-sunday-siurana/ines');
      expect(store.accept('my-sunday-siurana/bruno'), isNull);
      expect(store.plan('my-sunday-siurana')!.memberIds, ['me', 'ines']);
    });
  });

  group('plans', () {
    test('a new plan is mine, and its own group', () {
      final store = demo();
      final plan = store.createPlan(
        title: 'Gym session',
        discipline: Discipline.gym,
        place: 'Climbing gym',
        area: 'Barcelona',
        start: now.add(const Duration(days: 2)),
        hours: 2,
        grades: const GradeRange(GradeScale.french, 6, 10),
        spots: 3,
      );
      expect(plan.organizerId, 'me');
      expect(store.myPlans.map((p) => p.id), contains(plan.id));
    });

    test('when the organizer leaves, the next member organizes', () {
      final store = demo()..accept('my-sunday-siurana/ines');
      store.leave('my-sunday-siurana');
      final plan = store.plan('my-sunday-siurana')!;
      expect(plan.organizerId, 'ines');
      // Bruno's request no longer waits for me: Ines, the only member
      // left, accepts him.
      expect(plan.memberIds, ['ines', 'bruno']);
      expect(store.discover.map((p) => p.id), isNot(contains(plan.id)));
    });

    test('when the last member leaves, the plan is gone', () {
      final store = demo()..leave('my-sunday-siurana');
      expect(store.plan('my-sunday-siurana'), isNull);
      expect(store.messages('my-sunday-siurana'), isEmpty);
    });
  });

  group('answers that take a while', () {
    late DateTime time;
    GrigriStore slow() {
      time = now;
      return GrigriStore(
        demoState(now),
        clock: () => time,
        answerAfter: const Duration(seconds: 10),
      );
    }

    test('a request is pending, then accepted, with a notification', () {
      final store = slow();
      expect(store.like('siurana-saturday'), isNull);
      expect(store.waiting.map((r) => r.planId), ['siurana-saturday']);
      expect(store.settle(), isEmpty);

      time = now.add(const Duration(seconds: 10));
      final notices = store.settle();
      expect(notices.single.kind, NoticeKind.accepted);
      expect(notices.single.planTitle, 'Siurana sport day');
      expect(store.waiting, isEmpty);
      expect(store.myPlans.map((p) => p.id), contains('siurana-saturday'));
      expect(store.unreadNotices, 1);
      // The seeded one, from two days ago, comes last.
      expect(store.notices.first.planId, 'siurana-saturday');

      store.readNotices();
      expect(store.unreadNotices, 0);
    });

    test('one member\'s no declines it, with a notification', () {
      final store = slow();
      store.updateProfile(
        store.me.copyWith(
          levels: {...store.me.levels}..remove(Discipline.trad),
        ),
      );
      store.like('montserrat-multipitch');
      time = now.add(const Duration(minutes: 1));
      expect(store.settle().single.kind, NoticeKind.declined);
      expect(store.waiting, isEmpty);
      expect(store.declined.map((r) => r.planId), ['montserrat-multipitch']);

      store.dismiss('montserrat-multipitch/me');
      expect(store.declined, isEmpty);
      expect(
        store.discover.map((p) => p.id),
        isNot(contains('montserrat-multipitch')),
      );
    });

    test('nobody is notified of answers to others\' requests', () {
      final store = slow()..reject('my-sunday-siurana/bruno');
      store.accept('thursday-bouldering/noa');
      expect(store.unreadNotices, 0);
    });
  });

  test('chat messages are kept in order, blank ones dropped', () {
    final store = demo()
      ..send('thursday-bouldering', '  See you there  ')
      ..send('thursday-bouldering', '   ');
    final last = store.messages('thursday-bouldering').last;
    expect(last.text, 'See you there');
    expect(last.authorId, 'me');
  });

  test('the state survives a round trip through JSON', () {
    final store = demo()
      ..like('siurana-saturday')
      ..like('margalef-project');
    expect(store.unreadNotices, 1);
    final json = jsonEncode(store.state.toJson());
    final again = GrigriStore(
      GrigriState.fromJson((jsonDecode(json) as Map).cast()),
      clock: () => now,
    );
    expect(jsonEncode(again.state.toJson()), json);
    expect(again.me.levels[Discipline.sport]!.label, '6a–6c+');
  });
}
