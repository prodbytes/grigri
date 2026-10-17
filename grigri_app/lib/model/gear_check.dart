import 'climbing.dart';
import 'plan.dart';

/// One piece of gear a plan needs: how many it needs, and how many its
/// group has.
class GearNeed {
  const GearNeed(this.gear, {required this.need, required this.have});

  final Gear gear;
  final int need;
  final int have;

  bool get met => have >= need;
}

/// What a plan needs, by its discipline, against the gear its members
/// listed on their profiles. A simple check, not a safety one:
///
/// - Sport and trad: a rope, a belay device and quickdraws (sport) or a
///   rack (trad) for each pair of climbers; every climber's harness and
///   shoes, and on trad their helmet.
/// - Bouldering: a crash pad, and every climber's shoes. No ropes.
/// - The gym: nothing; it has ropes and mats, and rents the rest.
///
/// A guided plan's guide brings the group's gear, so it checks only what
/// each climber needs of their own.
List<GearNeed> gearCheck(Plan plan, List<Set<Gear>> members) {
  final climbers = members.length;
  final pairs = climbers <= 2 ? 1 : (climbers / 2).ceil();
  final (Map<Gear, int> shared, Set<Gear> personal) = switch (plan.discipline) {
    Discipline.sport => (
      {Gear.rope: pairs, Gear.quickdraws: pairs, Gear.belayDevice: pairs},
      {Gear.harness, Gear.shoes},
    ),
    Discipline.trad => (
      {Gear.rope: pairs, Gear.rack: pairs, Gear.belayDevice: pairs},
      {Gear.harness, Gear.shoes, Gear.helmet},
    ),
    Discipline.bouldering => ({Gear.crashPad: 1}, {Gear.shoes}),
    Discipline.gym => (<Gear, int>{}, <Gear>{}),
  };
  int count(Gear g) => members.where((m) => m.contains(g)).length;
  return [
    if (plan.type != PlanType.guided)
      for (final e in shared.entries)
        GearNeed(e.key, need: e.value, have: count(e.key)),
    for (final g in personal) GearNeed(g, need: climbers, have: count(g)),
  ];
}
