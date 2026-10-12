import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/plan.dart';
import 'grigri_store.dart';

/// The demo data the app starts with, until there's a backend: me, a few
/// made-up climbers (never real people) with their plans, and requests to
/// review. Dates are relative to [now], so the plans are always upcoming.
GrigriState demoState(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);

  /// The next given weekday (1 = Monday) at least [after] days ahead, at
  /// [hour]. Built from calendar days, not added hours, so it's right
  /// across daylight saving changes.
  DateTime next(int weekday, int hour, {int after = 1}) {
    var offset = after;
    while (DateTime(day.year, day.month, day.day + offset).weekday != weekday) {
      offset++;
    }
    return DateTime(day.year, day.month, day.day + offset, hour);
  }

  GradeRange french(String min, String max) => GradeRange(
    GradeScale.routes,
    GradeScale.routes.european.indexOf(min),
    GradeScale.routes.european.indexOf(max),
  );
  GradeRange v(String min, String max) => GradeRange(
    GradeScale.boulders,
    GradeScale.boulders.american.indexOf(min),
    GradeScale.boulders.american.indexOf(max),
  );

  const meId = 'me';
  final climbers = [
    Climber(
      id: meId,
      name: 'You',
      age: 30,
      bio: 'Edit your profile: tell people how you like to climb.',
      levels: {
        Discipline.sport: french('6a', '6c+'),
        Discipline.trad: french('5c', '6a'),
        Discipline.bouldering: v('V2', 'V5'),
        Discipline.gym: french('6a', '7a'),
      },
      gear: const {Gear.rope, Gear.quickdraws},
    ),
    Climber(
      id: 'marta',
      name: 'Marta Soler',
      age: 29,
      bio: 'Limestone lover. I like long days, early starts and a good bocata.',
      levels: {Discipline.sport: french('6b', '7a+')},
      gear: const {Gear.rope, Gear.quickdraws, Gear.car},
    ),
    Climber(
      id: 'tomas',
      name: 'Tomás Ibarra',
      age: 34,
      bio: 'Multipitch and conglomerate. Happy to lead the trad pitches.',
      levels: {
        Discipline.trad: french('5c', '6c'),
        Discipline.sport: french('6a', '6c'),
      },
      gear: const {Gear.rope, Gear.rack, Gear.car},
    ),
    Climber(
      id: 'ravi',
      name: 'Ravi Nair',
      age: 38,
      bio: 'Slow and steady. Belays with snacks.',
      levels: {Discipline.trad: french('5b', '6b')},
      gear: const {Gear.rack},
    ),
    Climber(
      id: 'kofi',
      name: 'Kofi Mensah',
      age: 31,
      bio: 'Projecting season. Looking for patient belayers.',
      levels: {Discipline.sport: french('7a', '7c+')},
      gear: const {Gear.rope, Gear.quickdraws, Gear.car},
    ),
    Climber(
      id: 'lena',
      name: 'Lena Vogel',
      age: 26,
      bio: 'Boulder gym rat on weeknights, Fontainebleau dreamer.',
      levels: {
        Discipline.bouldering: v('V3', 'V6'),
        Discipline.gym: french('6b', '7a'),
      },
      gear: const {Gear.crashPad},
    ),
    Climber(
      id: 'noa',
      name: 'Noa Levi',
      age: 24,
      bio: 'New to outdoor bouldering, keen to learn.',
      levels: {Discipline.bouldering: v('V1', 'V4')},
    ),
    Climber(
      id: 'ines',
      name: 'Inés Prado',
      age: 27,
      bio: 'Coming back after a finger injury, so moderate routes please.',
      levels: {
        Discipline.sport: french('5c', '6b'),
        Discipline.gym: french('5c', '6b+'),
      },
      gear: const {Gear.quickdraws},
    ),
    Climber(
      id: 'bruno',
      name: 'Bruno Costa',
      age: 33,
      bio: 'After-work leads and weekend sport trips.',
      levels: {
        Discipline.sport: french('6a+', '6c+'),
        Discipline.gym: french('6a+', '7a'),
      },
      gear: const {Gear.rope, Gear.car},
    ),
  ];

  final plans = [
    Plan(
      id: 'siurana-saturday',
      organizerId: 'marta',
      discipline: Discipline.sport,
      place: 'El Pati',
      area: 'Siurana, Spain',
      sectorId: 'demo:el-pati',
      start: next(DateTime.saturday, 8),
      end: next(DateTime.saturday, 17),
      grades: french('6a', '7a'),
      memberIds: const ['marta'],
      notes: 'Car from Barcelona at 6:30, two seats free.',
    ),
    Plan(
      id: 'montserrat-multipitch',
      organizerId: 'tomas',
      discipline: Discipline.trad,
      place: 'Montserrat',
      area: 'Catalonia',
      start: next(DateTime.sunday, 7),
      end: next(DateTime.sunday, 15),
      grades: french('5c', '6b'),
      memberIds: const ['tomas', 'ravi'],
      notes: 'Two ropes of two. Approach is 1 h; bring a headlamp.',
    ),
    Plan(
      id: 'margalef-project',
      organizerId: 'kofi',
      discipline: Discipline.sport,
      place: 'Margalef',
      area: 'Catalonia',
      start: next(DateTime.friday, 9),
      end: next(DateTime.friday, 17),
      grades: french('7a', '7c'),
      memberIds: const ['kofi'],
      notes: 'Mostly belaying and trying hard. Campsite Friday night.',
    ),
    Plan(
      id: 'tuesday-bouldering',
      organizerId: 'lena',
      discipline: Discipline.bouldering,
      place: 'Boulder gym',
      area: 'Barcelona',
      start: next(DateTime.tuesday, 19),
      end: next(DateTime.tuesday, 22),
      grades: v('V2', 'V5'),
      memberIds: const ['lena', 'noa'],
    ),
    Plan(
      id: 'after-work-leads',
      organizerId: 'bruno',
      discipline: Discipline.gym,
      place: 'Climbing gym',
      area: 'Barcelona',
      start: next(DateTime.wednesday, 19),
      end: next(DateTime.wednesday, 21),
      grades: french('6a', '6c+'),
      memberIds: const ['bruno'],
    ),
    // Mine: two people want to join.
    Plan(
      id: 'my-sunday-siurana',
      organizerId: meId,
      discipline: Discipline.sport,
      place: 'Siurana',
      area: 'Catalonia',
      start: next(DateTime.sunday, 9, after: 7),
      end: next(DateTime.sunday, 17, after: 7),
      grades: french('6a', '6c'),
      memberIds: const [meId],
      notes: 'Relaxed day of 6s. I have a rope and draws.',
    ),
    // A group I'm in, where one more wants to join.
    Plan(
      id: 'thursday-bouldering',
      organizerId: 'lena',
      discipline: Discipline.bouldering,
      place: 'Boulder gym',
      area: 'Barcelona',
      start: next(DateTime.thursday, 19),
      end: next(DateTime.thursday, 22),
      grades: v('V2', 'V6'),
      memberIds: const ['lena', meId],
    ),
  ];

  final requests = [
    const JoinRequest(planId: 'my-sunday-siurana', climberId: 'ines'),
    const JoinRequest(planId: 'my-sunday-siurana', climberId: 'bruno'),
    const JoinRequest(
      planId: 'thursday-bouldering',
      climberId: 'noa',
      acceptedBy: {'lena'},
    ),
  ];
  // When each asked: their card in the chat, and my notification.
  final asked = {
    'my-sunday-siurana/ines': now.subtract(const Duration(hours: 20)),
    'my-sunday-siurana/bruno': now.subtract(const Duration(hours: 3)),
    'thursday-bouldering/noa': now.subtract(const Duration(hours: 6)),
  };
  String name(String id) => climbers.firstWhere((c) => c.id == id).name;
  String title(String id) => plans.firstWhere((p) => p.id == id).title;

  final thursday = plans.last.start;
  final messages = [
    Message(
      planId: 'thursday-bouldering',
      authorId: null,
      text: 'You joined the plan 🎉',
      time: now.subtract(const Duration(days: 2)),
    ),
    Message(
      planId: 'thursday-bouldering',
      authorId: 'lena',
      text: 'Welcome! New set on the overhang wall, so bring skin 😄',
      time: now.subtract(const Duration(days: 2, hours: -1)),
    ),
    Message(
      planId: 'thursday-bouldering',
      authorId: 'lena',
      text:
          'Meet at the entrance at ${thursday.hour}:00? '
          'Noa asked to join too, say yes if you\'re in.',
      time: now.subtract(const Duration(hours: 5)),
    ),
    Message(
      planId: 'my-sunday-siurana',
      authorId: null,
      text: 'You created the plan. People who match will show up here.',
      time: now.subtract(const Duration(days: 1)),
    ),
    for (final r in requests)
      Message(
        planId: r.planId,
        authorId: null,
        text: '${name(r.climberId)} asked to join',
        time: asked[r.id]!,
        requestId: r.id,
      ),
  ];

  return GrigriState(
    meId: meId,
    climbers: {for (final c in climbers) c.id: c},
    plans: {for (final p in plans) p.id: p},
    requests: {for (final r in requests) r.id: r},
    messages: messages,
    policies: const {
      'marta': Policy.acceptsMatchingGrades,
      'tomas': Policy.acceptsAll,
      'ravi': Policy.acceptsMatchingGrades,
      'kofi': Policy.undecided,
      'lena': Policy.acceptsAll,
      'noa': Policy.acceptsAll,
      'ines': Policy.acceptsAll,
      'bruno': Policy.acceptsAll,
    },
    notices: [
      Notice(
        kind: NoticeKind.accepted,
        planId: 'thursday-bouldering',
        planTitle: 'Boulder gym',
        time: now.subtract(const Duration(days: 2)),
        read: true,
      ),
      for (final r in requests)
        Notice(
          kind: NoticeKind.request,
          planId: r.planId,
          planTitle: title(r.planId),
          climberId: r.climberId,
          time: asked[r.id]!,
        ),
    ],
  );
}
