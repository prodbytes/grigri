import 'package:flutter/material.dart';

import '../data/sector_index.dart';
import '../model/climbing.dart';
import '../model/plan.dart';
import '../model/sector.dart';
import '../theme.dart';
import 'common.dart';

/// Creates a plan, or edits one I organize: what, where (a sector from the
/// index, or typed in), when (a first day, left open if not known yet, any
/// more days, and the hours, the same each day) and which grades.
class PlanEditor extends StatefulWidget {
  const PlanEditor({super.key, this.plan});

  /// The plan to edit; null for a new one.
  final Plan? plan;

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  final _form = GlobalKey<FormState>();
  late final _place = TextEditingController(text: widget.plan?.place);
  final _placeFocus = FocusNode();
  late final _notes = TextEditingController(text: widget.plan?.notes);
  late Discipline _discipline = widget.plan?.discipline ?? Discipline.sport;

  /// The first day; null while it's left open (an undated plan). A new
  /// plan starts on the next Saturday.
  late DateTime? _day = widget.plan == null
      ? _nextSaturday()
      : widget.plan!.start == null
      ? null
      : _dayOf(widget.plan!.start!);

  /// The days after the first, soonest first.
  late final List<DateTime> _moreDays = [
    for (final d in widget.plan?.moreDays ?? const <DayWindow>[])
      _dayOf(d.start),
  ];

  /// From and to, in half hours since midnight, each day.
  late RangeValues _hours =
      widget.plan?.start == null || widget.plan?.end == null
      ? const RangeValues(9 * 2, 17 * 2)
      : RangeValues(
          _halfHours(widget.plan!.start!, _firstHalfHour, _lastHalfHour - 1),
          _halfHours(widget.plan!.end!, _firstHalfHour + 1, _lastHalfHour),
        );
  late RangeValues _grades;

  /// The sector picked from the index; null when the place is typed in.
  late Sector? _sector = widget.plan?.sectorId == null
      ? null
      : Sector(
          id: widget.plan!.sectorId!,
          name: widget.plan!.place,
          area: widget.plan!.area,
          lat: widget.plan!.lat,
          lon: widget.plan!.lon,
        );
  SectorIndex? _index;

  /// The time range's ends: 05:00 and 23:30.
  static const _firstHalfHour = 5 * 2;
  static const _lastHalfHour = 23 * 2 + 1;

  /// Days after the first: two weeks in all (the API's limit).
  static const _maxMoreDays = 13;

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  static DateTime _nextSaturday() {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day + 1);
    while (d.weekday != DateTime.saturday) {
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return d;
  }

  /// [t] in half hours since midnight, to the nearest, within [min]–[max].
  static double _halfHours(DateTime t, int min, int max) =>
      ((t.hour * 60 + t.minute) / 30).round().clamp(min, max).toDouble();

  /// [day] at [halfHours] since midnight.
  static DateTime _at(DateTime day, double halfHours) {
    final h = halfHours.round();
    return DateTime(day.year, day.month, day.day, h ~/ 2, h.isOdd ? 30 : 0);
  }

  /// [day] from and to [_hours].
  DayWindow _window(DateTime day) =>
      (start: _at(day, _hours.start), end: _at(day, _hours.end));

  static DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  static String _clockOf(double halfHours) {
    final h = halfHours.round();
    return '${(h ~/ 2).toString().padLeft(2, '0')}:${h.isOdd ? '30' : '00'}';
  }

  @override
  void initState() {
    super.initState();
    final g = widget.plan?.grades;
    _grades = g != null
        ? RangeValues(g.min.toDouble(), g.max.toDouble())
        : _defaultGrades(_discipline);
    SectorIndex.load().then((index) {
      if (mounted) setState(() => _index = index);
    });
    _place.addListener(() {
      // Typing over a picked sector makes it a place typed in by hand.
      if (_sector != null && _place.text != _sector!.name) {
        setState(() => _sector = null);
      }
    });
  }

  /// My own grades for the discipline, or the scale's middle.
  RangeValues _defaultGrades(Discipline d) {
    final mine = widget.plan == null
        ? StoreScope.read(context).me.levels[d]
        : null;
    if (mine != null) {
      return RangeValues(mine.min.toDouble(), mine.max.toDouble());
    }
    final n = d.scale.european.length;
    return RangeValues((n * 0.3).roundToDouble(), (n * 0.5).roundToDouble());
  }

  @override
  void dispose() {
    _place.dispose();
    _placeFocus.dispose();
    _notes.dispose();
    super.dispose();
  }

  static DateTime get _lastDate =>
      _dayOf(DateTime.now().add(const Duration(days: 365)));

  /// Picks the first day; more days not after it are dropped.
  Future<void> _pickDate() async {
    final today = _dayOf(DateTime.now());
    final day = _day ?? _nextSaturday();
    final date = await showDatePicker(
      context: context,
      initialDate: day.isBefore(today) ? today : day,
      firstDate: today,
      lastDate: _lastDate,
    );
    if (date == null) return;
    setState(() {
      _day = _dayOf(date);
      _moreDays.removeWhere((d) => !d.isAfter(_day!));
    });
  }

  /// Adds a day after the first, one not in the plan yet.
  Future<void> _addDay() async {
    final first = _day;
    if (first == null) return;
    final taken = {first, ..._moreDays};
    final firstDate = _nextDay(first);
    if (firstDate.isAfter(_lastDate)) return;
    var initial = _nextDay(_moreDays.isEmpty ? first : _moreDays.last);
    if (initial.isAfter(_lastDate)) initial = firstDate;
    while (taken.contains(initial) && !initial.isAfter(_lastDate)) {
      initial = _nextDay(initial);
    }
    if (initial.isAfter(_lastDate)) return;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: _lastDate,
      selectableDayPredicate: (d) => !taken.contains(_dayOf(d)),
    );
    if (date == null) return;
    setState(() {
      _moreDays
        ..add(_dayOf(date))
        ..sort();
    });
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final now = DateTime.now();
    final day = _day;
    if (day != null && !_at(day, _hours.start).isAfter(now)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.pickFutureTime)));
      return;
    }
    final grades = GradeRange(
      _discipline.scale,
      _grades.start.round(),
      _grades.end.round(),
    );
    final sector = _sector;
    final place = _place.text.trim();
    final area = sector?.where ?? '';
    final first = day == null ? null : _window(day);
    final existing = widget.plan;
    final plan = (existing ?? _draft).copyWith(
      discipline: _discipline,
      place: place,
      area: area,
      sectorId: () => sector?.id,
      point: () => sector?.lat == null || sector?.lon == null
          ? null
          : (lat: sector!.lat!, lon: sector.lon!),
      start: () => first?.start,
      end: () => first?.end,
      moreDays: day == null
          ? const []
          : [for (final d in _moreDays) _window(d)],
      grades: grades,
      notes: _notes.text.trim(),
    );
    setState(() => _saving = true);
    final saved = existing == null
        ? await store.createPlan(plan) != null
        : await store.updatePlan(plan);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  /// A new plan, before the server gives it an id and its group.
  Plan get _draft => Plan(
    id: '',
    organizerId: '',
    discipline: _discipline,
    place: '',
    grades: GradeRange(_discipline.scale, 0, 0),
    memberIds: const [],
  );

  /// Where I am, for the search: my location, else my first area; null
  /// when I've set neither.
  ({double lat, double lon})? _me(BuildContext context) {
    final me = StoreScope.read(context).me;
    final at = me.location ?? (me.areas.isEmpty ? null : me.areas.first);
    return at == null ? null : (lat: at.lat, lon: at.lon);
  }

  /// The where field: searches the sector index by name as I type,
  /// nearest to me first (with how far each is), and with nothing typed
  /// offers the nearest; takes any place the index doesn't have.
  Widget _whereField() => RawAutocomplete<Sector>(
    textEditingController: _place,
    focusNode: _placeFocus,
    displayStringForOption: (s) => s.name,
    optionsBuilder: (value) =>
        _index?.search(value.text, near: _me(context)) ?? const <Sector>[],
    onSelected: (s) => setState(() => _sector = s),
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: context.l10n.sectorLabel,
            hintText: context.l10n.sectorHint,
            prefixIcon: const Icon(Icons.search),
            helperText: _sector != null
                ? _sector!.where
                : (_index?.attribution.isNotEmpty ?? false)
                ? context.l10n.sectorsAttribution(_index!.attribution)
                : null,
            helperMaxLines: 2,
          ),
          textCapitalization: TextCapitalization.words,
          onFieldSubmitted: (_) => onSubmitted(),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? context.l10n.whereRequired : null,
        ),
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        color: Mountain.pine,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final s in options)
                ListTile(
                  leading: const Icon(
                    Icons.place_outlined,
                    color: Mountain.sky,
                  ),
                  title: Text(s.name),
                  subtitle: _subtitle(context, s),
                  onTap: () => onSelected(s),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  /// Where a suggestion is, and how far from me ("Siurana, Spain · 12 km").
  Widget? _subtitle(BuildContext context, Sector s) {
    final near = _me(context);
    final km = near == null ? null : SectorIndex.distanceKm(s, near);
    final parts = [
      if (s.where.isNotEmpty) s.where,
      if (km != null)
        context.l10n.kmAway(km < 10 ? km.toStringAsFixed(1) : '${km.round()}'),
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final scale = _discipline.scale.grades(StoreScope.of(context).gradeSystem);
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        s.toUpperCase(),
        style: text.labelSmall?.copyWith(
          color: Mountain.granite,
          letterSpacing: 1.2,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? l.newPlan : l.editPlan),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            label(l.sectionDiscipline),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in Discipline.values)
                  ChoiceChip(
                    label: Text('${d.emoji} ${d.label(l)}'),
                    selected: _discipline == d,
                    onSelected: (_) => setState(() {
                      if (d.scale != _discipline.scale) {
                        _grades = _defaultGrades(d);
                      }
                      _discipline = d;
                    }),
                  ),
              ],
            ),
            label(l.sectionWhere),
            _whereField(),
            label(l.sectionWhen),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      _day == null
                          ? l.dateToBeDecided
                          : dayLabel(context, _day!),
                    ),
                    onPressed: _pickDate,
                  ),
                ),
                if (_day != null)
                  IconButton(
                    tooltip: l.leaveDateOpen,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _day = null;
                      _moreDays.clear();
                    }),
                  ),
              ],
            ),
            if (_moreDays.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _moreDays)
                    InputChip(
                      avatar: const Icon(Icons.event, size: 18),
                      label: Text(dayLabel(context, d)),
                      onDeleted: () => setState(() => _moreDays.remove(d)),
                    ),
                ],
              ),
            ],
            if (_day != null && _moreDays.length < _maxMoreDays)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.addDay),
                  onPressed: _addDay,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.whenHelp,
                style: text.bodySmall?.copyWith(color: Mountain.granite),
              ),
            ),
            if (_day != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 20, color: Mountain.granite),
                  Expanded(
                    child: RangeSlider(
                      values: _hours,
                      min: _firstHalfHour.toDouble(),
                      max: _lastHalfHour.toDouble(),
                      divisions: _lastHalfHour - _firstHalfHour,
                      labels: RangeLabels(
                        _clockOf(_hours.start),
                        _clockOf(_hours.end),
                      ),
                      onChanged: (v) {
                        // At least half an hour.
                        if (v.end > v.start) setState(() => _hours = v);
                      },
                    ),
                  ),
                  Text(
                    '${_clockOf(_hours.start)}–${_clockOf(_hours.end)}',
                    style: text.titleSmall,
                  ),
                ],
              ),
            ],
            label(l.sectionGrades),
            const GradeSystemToggle(),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 20,
                  color: Mountain.granite,
                ),
                Expanded(
                  child: RangeSlider(
                    values: _grades,
                    min: 0,
                    max: (scale.length - 1).toDouble(),
                    divisions: scale.length - 1,
                    labels: RangeLabels(
                      scale[_grades.start.round()],
                      scale[_grades.end.round()],
                    ),
                    onChanged: (v) => setState(() => _grades = v),
                  ),
                ),
                // Not upper-cased: 6a and 6A are different grades.
                Text(
                  '${scale[_grades.start.round()]}–${scale[_grades.end.round()]}',
                  style: text.titleSmall,
                ),
              ],
            ),
            label(l.sectionNotes),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(hintText: l.notesHint),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.plan == null ? l.publishPlan : l.save),
            ),
          ],
        ),
      ),
    );
  }
}
