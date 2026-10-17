import 'package:flutter/material.dart';

import '../model/climbing.dart';
import '../model/gear_check.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';

/// A plan's gear: what it needs for its discipline, ticked off against
/// what its members listed on their profiles ([gearCheck]), a discreet
/// line when something's missing, and each member's gear (tap one for
/// their profile, with its gear photos).
class PlanGearSection extends StatelessWidget {
  const PlanGearSection(this.plan, {super.key});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final members = [for (final id in plan.memberIds) store.climber(id)];
    final needs = gearCheck(plan, [for (final m in members) m.gear]);
    final missing = needs.where((n) => !n.met).toList();
    String count(GearNeed n) => n.need > 1 ? ' ${n.have}/${n.need}' : '';
    Widget note(String s, {IconData? icon, Color color = Mountain.granite}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(s, style: text.bodySmall?.copyWith(color: color)),
              ),
            ],
          ),
        );
    return Column(
      key: const ValueKey('plan gear'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.profileGear.toUpperCase(),
          style: text.labelSmall?.copyWith(
            color: Mountain.granite,
            letterSpacing: 1.2,
          ),
        ),
        if (plan.discipline == Discipline.gym)
          note(l.planGearGym)
        else ...[
          if (plan.type == PlanType.guided) note(l.planGearGuided),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in needs)
                n.met
                    ? Tag(
                        '${n.gear.label(l)}${count(n)}',
                        icon: Icons.check,
                        color: Mountain.olive,
                      )
                    : Tag(
                        '${n.gear.label(l)}${count(n)}',
                        icon: Icons.radio_button_unchecked,
                        color: Mountain.granite,
                      ),
            ],
          ),
          if (missing.isEmpty)
            note(l.planGearAllSet, color: Mountain.olive)
          else
            note(
              l.planGearMissing(
                [for (final n in missing) n.gear.label(l)].join(', '),
              ),
              icon: Icons.info_outline,
              color: Mountain.tan,
            ),
        ],
        const SizedBox(height: 4),
        for (final m in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Avatar(m, radius: 14),
            title: Text(m.id == store.me.id ? l.you : m.name),
            subtitle: Text(
              m.gear.isEmpty
                  ? l.noGearListed
                  : [
                      for (final g in Gear.values)
                        if (m.gear.contains(g)) g.label(l),
                    ].join(' · '),
              style: const TextStyle(color: Mountain.granite),
            ),
            trailing: m.gearPhotos.isEmpty
                ? null
                : const Icon(
                    Icons.photo_outlined,
                    size: 18,
                    color: Mountain.granite,
                  ),
            onTap: () => showProfileSheet(context, m),
          ),
      ],
    );
  }
}
