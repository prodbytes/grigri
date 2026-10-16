import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../model/climbing.dart';
import '../model/plan.dart';

export '../l10n/app_localizations.dart';

/// The app's texts in the user's language (lib/l10n, specs/i18n.md).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The languages the app speaks, each named in itself for the picker.
const languageNames = {
  'en': 'English',
  'es': 'Español',
  'de': 'Deutsch',
  'fr': 'Français',
  'pt': 'Português (Brasil)',
  'ca': 'Català',
};

extension DisciplineL10n on Discipline {
  /// "Sport", "Bouldering", in the user's language.
  String label(AppLocalizations l) => switch (this) {
    Discipline.sport => l.disciplineSport,
    Discipline.trad => l.disciplineTrad,
    Discipline.bouldering => l.disciplineBouldering,
    Discipline.gym => l.disciplineGym,
  };
}

extension GradeSystemL10n on GradeSystem {
  String label(AppLocalizations l) => switch (this) {
    GradeSystem.european => l.gradeSystemEuropean,
    GradeSystem.american => l.gradeSystemAmerican,
  };
}

extension GearL10n on Gear {
  String label(AppLocalizations l) => switch (this) {
    Gear.rope => l.gearRope,
    Gear.quickdraws => l.gearQuickdraws,
    Gear.rack => l.gearRack,
    Gear.crashPad => l.gearCrashPad,
    Gear.car => l.gearCar,
  };
}

/// "18:30": 24-hour time, as all the app's languages write it.
String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Sat 17 Oct" in English, "sáb 17 oct" in Spanish.
String dayLabel(BuildContext context, DateTime t) =>
    DateFormat('EEE d MMM', context.l10n.localeName).format(t);

/// The plan's first day, "Sat 17 Oct"; "Sat 17 Oct +2 days" when it has
/// more; "Date to be decided" while undated.
String daysLabel(BuildContext context, Plan plan) {
  final start = plan.start;
  if (start == null) return context.l10n.dateToBeDecided;
  final day = dayLabel(context, start);
  return plan.moreDays.isEmpty
      ? day
      : context.l10n.dayAndMoreDays(day, plan.moreDays.length);
}

/// Every day of the plan, "Sat 17 Oct, Sun 18 Oct"; "Date to be decided"
/// while undated.
String allDaysLabel(BuildContext context, Plan plan) => plan.days.isEmpty
    ? context.l10n.dateToBeDecided
    : plan.days.map((d) => dayLabel(context, d.start)).join(', ');

/// "Sat 17 Oct · 08:00–17:00"; just "Date to be decided" while undated.
String whenLabel(BuildContext context, Plan plan) => plan.start == null
    ? daysLabel(context, plan)
    : '${daysLabel(context, plan)} · ${timeRangeLabel(plan)}';

/// The first day's hours, "08:00–17:00"; empty while undated.
String timeRangeLabel(Plan plan) => plan.start == null || plan.end == null
    ? ''
    : '${clock(plan.start!)}–${clock(plan.end!)}';

/// "Sat 17 Oct, 18:30".
String dayAndTime(BuildContext context, DateTime t) =>
    context.l10n.dayAndTime(dayLabel(context, t), clock(t));
