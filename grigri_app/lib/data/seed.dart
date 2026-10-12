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
    GradeScale.french,
    GradeScale.french.grades.indexOf(min),
    GradeScale.french.grades.indexOf(max),
  );
  GradeRange v(String min, String max) => GradeRange(
    GradeScale.vScale,
    GradeScale.vScale.grades.indexOf(min),
    GradeScale.vScale.grades.indexOf(max),
  );
  Set<Slot> slots(List<int> days, List<DayPart> parts) => {
    for (final d in days)
      for (final p in parts) Slot(d, p),
  };

  const meId = 'me';
  final climbers = [
    Climber(
      id: meId,
      name: 'You',
      age: 30,
      bio: 'Edit your profile: tell people how you like to climb.',
      homeArea: 'Barcelona',
      yearsClimbing: 4,
      levels: {
        Discipline.sport: french('6a', '6c+'),
        Discipline.trad: french('5c', '6a'),
        Discipline.bouldering: v('V2', 'V5'),
        Discipline.gym: french('6a', '7a'),
      },
      availability: {
        ...slots([6, 7], DayPart.values),
        ...slots([2, 4], [DayPart.evening]),
      },
      places: const ['Siurana', 'Montserrat'],
      gear: const {Gear.rope, Gear.quickdraws},
    ),
    Climber(
      id: 'marta',
      name: 'Marta Soler',
      age: 29,
      bio: 'Limestone lover. I like long days, early starts and a good bocata.',
      homeArea: 'Tarragona',
      yearsClimbing: 7,
      levels: {Discipline.sport: french('6b', '7a+')},
      availability: slots([6, 7], [DayPart.morning, DayPart.afternoon]),
      places: const ['Siurana', 'Margalef', 'Arboli'],
      gear: const {Gear.rope, Gear.quickdraws, Gear.car},
    ),
    Climber(
      id: 'tomas',
      name: 'Tomás Ibarra',
      age: 34,
      bio: 'Multipitch and conglomerate. Happy to lead the trad pitches.',
      homeArea: 'Barcelona',
      yearsClimbing: 12,
      levels: {
        Discipline.trad: french('5c', '6c'),
        Discipline.sport: french('6a', '6c'),
      },
      availability: slots([6, 7], [DayPart.morning]),
      places: const ['Montserrat', 'Vilanova de Meià'],
      gear: const {Gear.rope, Gear.rack, Gear.car},
    ),
    Climber(
      id: 'ravi',
      name: 'Ravi Nair',
      age: 38,
      bio: 'Slow and steady. Belays with snacks.',
      homeArea: 'Barcelona',
      yearsClimbing: 9,
      levels: {Discipline.trad: french('5b', '6b')},
      availability: slots([6, 7], DayPart.values),
      places: const ['Montserrat'],
      gear: const {Gear.rack},
    ),
    Climber(
      id: 'kofi',
      name: 'Kofi Mensah',
      age: 31,
      bio: 'Projecting season. Looking for patient belayers.',
      homeArea: 'Lleida',
      yearsClimbing: 10,
      levels: {Discipline.sport: french('7a', '7c+')},
      availability: slots([5, 6, 7], DayPart.values),
      places: const ['Margalef', 'Oliana'],
      gear: const {Gear.rope, Gear.quickdraws, Gear.car},
    ),
    Climber(
      id: 'lena',
      name: 'Lena Vogel',
      age: 26,
      bio: 'Boulder gym rat on weeknights, Fontainebleau dreamer.',
      homeArea: 'Barcelona',
      yearsClimbing: 5,
      levels: {
        Discipline.bouldering: v('V3', 'V6'),
        Discipline.gym: french('6b', '7a'),
      },
      availability: slots([1, 2, 3, 4], [DayPart.evening]),
      places: const ['Boulder gym', 'Albarracín'],
      gear: const {Gear.crashPad},
    ),
    Climber(
      id: 'noa',
      name: 'Noa Levi',
      age: 24,
      bio: 'New to outdoor bouldering, keen to learn.',
      homeArea: 'Barcelona',
      yearsClimbing: 2,
      levels: {Discipline.bouldering: v('V1', 'V4')},
      availability: slots([2, 4], [DayPart.evening]),
      places: const ['Boulder gym'],
    ),
    Climber(
      id: 'ines',
      name: 'Inés Prado',
      age: 27,
      bio: 'Coming back after a finger injury, so moderate routes please.',
      homeArea: 'Barcelona',
      yearsClimbing: 3,
      levels: {
        Discipline.sport: french('5c', '6b'),
        Discipline.gym: french('5c', '6b+'),
      },
      availability: slots([6, 7], [DayPart.morning, DayPart.afternoon]),
      places: const ['Siurana', 'Climbing gym'],
      gear: const {Gear.quickdraws},
    ),
    Climber(
      id: 'bruno',
      name: 'Bruno Costa',
      age: 33,
      bio: 'After-work leads and weekend sport trips.',
      homeArea: 'Barcelona',
      yearsClimbing: 6,
      levels: {
        Discipline.sport: french('6a+', '6c+'),
        Discipline.gym: french('6a+', '7a'),
      },
      availability: {
        ...slots([1, 3], [DayPart.evening]),
        ...slots([7], [DayPart.morning]),
      },
      places: const ['Climbing gym', 'Siurana'],
      gear: const {Gear.rope, Gear.car},
    ),
  ];

  final plans = [
    Plan(
      id: 'siurana-saturday',
      organizerId: 'marta',
      title: 'Siurana sport day',
      discipline: Discipline.sport,
      place: 'Siurana',
      area: 'Catalonia',
      start: next(DateTime.saturday, 8),
      hours: 9,
      grades: french('6a', '7a'),
      spots: 3,
      memberIds: const ['marta'],
      notes: 'Car from Barcelona at 6:30, two seats free. Sector El Pati.',
    ),
    Plan(
      id: 'montserrat-multipitch',
      organizerId: 'tomas',
      title: 'Montserrat multipitch',
      discipline: Discipline.trad,
      place: 'Montserrat',
      area: 'Catalonia',
      start: next(DateTime.sunday, 7),
      hours: 8,
      grades: french('5c', '6b'),
      spots: 4,
      memberIds: const ['tomas', 'ravi'],
      notes: 'Two ropes of two. Approach is 1 h; bring a headlamp.',
    ),
    Plan(
      id: 'margalef-project',
      organizerId: 'kofi',
      title: 'Margalef projecting',
      discipline: Discipline.sport,
      place: 'Margalef',
      area: 'Catalonia',
      start: next(DateTime.friday, 9),
      hours: 8,
      grades: french('7a', '7c'),
      spots: 2,
      memberIds: const ['kofi'],
      notes: 'Mostly belaying and trying hard. Campsite Friday night.',
    ),
    Plan(
      id: 'tuesday-bouldering',
      organizerId: 'lena',
      title: 'Evening bouldering session',
      discipline: Discipline.bouldering,
      place: 'Boulder gym',
      area: 'Barcelona',
      start: next(DateTime.tuesday, 19),
      hours: 3,
      grades: v('V2', 'V5'),
      spots: 4,
      memberIds: const ['lena', 'noa'],
    ),
    Plan(
      id: 'after-work-leads',
      organizerId: 'bruno',
      title: 'After-work lead climbing',
      discipline: Discipline.gym,
      place: 'Climbing gym',
      area: 'Barcelona',
      start: next(DateTime.wednesday, 19),
      hours: 2,
      grades: french('6a', '6c+'),
      spots: 2,
      memberIds: const ['bruno'],
    ),
    // Mine: two people want to join.
    Plan(
      id: 'my-sunday-siurana',
      organizerId: meId,
      title: 'Sunday at Siurana',
      discipline: Discipline.sport,
      place: 'Siurana',
      area: 'Catalonia',
      start: next(DateTime.sunday, 9, after: 7),
      hours: 8,
      grades: french('6a', '6c'),
      spots: 3,
      memberIds: const [meId],
      notes: 'Relaxed day of 6s. I have a rope and draws.',
    ),
    // A group I'm in, where one more wants to join.
    Plan(
      id: 'thursday-bouldering',
      organizerId: 'lena',
      title: 'Thursday bouldering',
      discipline: Discipline.bouldering,
      place: 'Boulder gym',
      area: 'Barcelona',
      start: next(DateTime.thursday, 19),
      hours: 3,
      grades: v('V2', 'V6'),
      spots: 4,
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
          'Noa asked to join too, have a look in Requests.',
      time: now.subtract(const Duration(hours: 5)),
    ),
    Message(
      planId: 'my-sunday-siurana',
      authorId: null,
      text: 'You created the plan. People who match will show up here.',
      time: now.subtract(const Duration(days: 1)),
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
        planTitle: 'Thursday bouldering',
        time: now.subtract(const Duration(days: 2)),
        read: true,
      ),
    ],
  );
}
