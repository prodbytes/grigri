import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/model/gear_check.dart';
import 'package:grigri_app/model/plan.dart';

Plan _plan(Discipline discipline, {PlanType type = PlanType.private}) => Plan(
  id: 'p1',
  organizerId: 'ada',
  discipline: discipline,
  place: 'Somewhere',
  grades: const GradeRange(GradeScale.routes, 6, 10),
  memberIds: const ['ada', 'ben'],
  type: type,
);

/// The check, as "gear have/need".
Map<Gear, String> _check(Plan plan, List<Set<Gear>> members) => {
  for (final n in gearCheck(plan, members)) n.gear: '${n.have}/${n.need}',
};

void main() {
  const pair = [
    {Gear.rope, Gear.quickdraws, Gear.harness, Gear.shoes},
    {Gear.belayDevice, Gear.harness, Gear.shoes, Gear.car},
  ];

  test('sport: a rope, quickdraws and a belay device, and everyone\'s '
      'harness and shoes', () {
    expect(_check(_plan(Discipline.sport), pair), {
      Gear.rope: '1/1',
      Gear.quickdraws: '1/1',
      Gear.belayDevice: '1/1',
      Gear.harness: '2/2',
      Gear.shoes: '2/2',
    });
    expect(gearCheck(_plan(Discipline.sport), pair).every((n) => n.met), true);
  });

  test('a rope, draws and a belay device for each pair', () {
    final four = [
      ...pair,
      {Gear.harness, Gear.shoes},
      {Gear.shoes},
    ];
    final check = gearCheck(_plan(Discipline.sport), four);
    expect(_check(_plan(Discipline.sport), four), {
      Gear.rope: '1/2',
      Gear.quickdraws: '1/2',
      Gear.belayDevice: '1/2',
      Gear.harness: '3/4',
      Gear.shoes: '4/4',
    });
    expect(
      [
        for (final n in check)
          if (!n.met) n.gear,
      ],
      [Gear.rope, Gear.quickdraws, Gear.belayDevice, Gear.harness],
    );
  });

  test('trad: a rack instead of draws, and helmets', () {
    expect(_check(_plan(Discipline.trad), pair), {
      Gear.rope: '1/1',
      Gear.rack: '0/1',
      Gear.belayDevice: '1/1',
      Gear.harness: '2/2',
      Gear.shoes: '2/2',
      Gear.helmet: '0/2',
    });
  });

  test('bouldering: a crash pad and shoes, no ropes', () {
    expect(_check(_plan(Discipline.bouldering), pair), {
      Gear.crashPad: '0/1',
      Gear.shoes: '2/2',
    });
  });

  test('the gym: nothing to check', () {
    expect(gearCheck(_plan(Discipline.gym), [{}, {}]), isEmpty);
  });

  test('guided: the guide brings the group\'s gear; only your own counts', () {
    expect(_check(_plan(Discipline.sport, type: PlanType.guided), [{}, {}]), {
      Gear.harness: '0/2',
      Gear.shoes: '0/2',
    });
  });
}
