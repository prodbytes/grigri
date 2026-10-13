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

/// "Sat 17 Oct · 08:00–17:00".
String whenLabel(BuildContext context, Plan plan) =>
    '${dayLabel(context, plan.start)} · ${clock(plan.start)}–${clock(plan.end)}';

/// "Sat 17 Oct, 18:30".
String dayAndTime(BuildContext context, DateTime t) =>
    context.l10n.dayAndTime(dayLabel(context, t), clock(t));
