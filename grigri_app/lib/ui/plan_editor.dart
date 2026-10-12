import 'package:flutter/material.dart';

import '../data/sector_index.dart';
import '../model/climbing.dart';
import '../model/plan.dart';
import '../model/sector.dart';
import '../theme.dart';
import 'common.dart';

/// Creates a plan, or edits one I organize: what, where (a sector from the
/// index, or typed in), when (a day and a time range) and which grades.
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
  late DateTime _day = _dayOf(widget.plan?.start ?? _nextSaturday());

  /// From and to, in half hours since midnight.
  late RangeValues _hours = widget.plan == null
      ? const RangeValues(9 * 2, 17 * 2)
      : RangeValues(
          _halfHours(widget.plan!.start, _firstHalfHour, _lastHalfHour - 1),
          _halfHours(widget.plan!.end, _firstHalfHour + 1, _lastHalfHour),
        );
  late RangeValues _grades;

  /// The sector picked from the index; null when the place is typed in.
  late Sector? _sector = widget.plan?.sectorId == null
      ? null
      : Sector(
          id: widget.plan!.sectorId!,
          name: widget.plan!.place,
          area: widget.plan!.area,
        );
  SectorIndex? _index;

  /// The time range's ends: 05:00 and 23:30.
  static const _firstHalfHour = 5 * 2;
  static const _lastHalfHour = 23 * 2 + 1;

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

  /// [_day] at [halfHours] since midnight.
  DateTime _at(double halfHours) {
    final h = halfHours.round();
    return DateTime(_day.year, _day.month, _day.day, h ~/ 2, h.isOdd ? 30 : 0);
  }

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = _dayOf(now);
    final date = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(today) ? today : _day,
      firstDate: today,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _day = _dayOf(date));
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final grades = GradeRange(
      _discipline.scale,
      _grades.start.round(),
      _grades.end.round(),
    );
    final sector = _sector;
    final place = _place.text.trim();
    final area = sector?.where ?? '';
    final start = _at(_hours.start);
    final end = _at(_hours.end);
    final existing = widget.plan;
    if (existing == null) {
      store.createPlan(
        discipline: _discipline,
        place: place,
        area: area,
        sectorId: sector?.id,
        start: start,
        end: end,
        grades: grades,
        notes: _notes.text.trim(),
      );
    } else {
      store.updatePlan(
        existing.copyWith(
          discipline: _discipline,
          place: place,
          area: area,
          sectorId: () => sector?.id,
          start: start,
          end: end,
          grades: grades,
          notes: _notes.text.trim(),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  /// The where field: searches the sector index as I type, and takes any
  /// place the index doesn't have.
  Widget _whereField() => RawAutocomplete<Sector>(
    textEditingController: _place,
    focusNode: _placeFocus,
    displayStringForOption: (s) => s.name,
    optionsBuilder: (value) => _index?.search(value.text) ?? const <Sector>[],
    onSelected: (s) => setState(() => _sector = s),
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Sector, crag or gym',
            hintText: 'Search, or type it in',
            prefixIcon: const Icon(Icons.search),
            helperText: _sector != null
                ? _sector!.where
                : (_index?.attribution.isNotEmpty ?? false)
                ? 'Sectors: ${_index!.attribution}'
                : null,
            helperMaxLines: 2,
          ),
          textCapitalization: TextCapitalization.words,
          onFieldSubmitted: (_) => onSubmitted(),
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Where are you climbing?' : null,
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
                  subtitle: s.where.isEmpty ? null : Text(s.where),
                  onTap: () => onSelected(s),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
        title: Text(widget.plan == null ? 'New plan' : 'Edit plan'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            label('Climbing'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in Discipline.values)
                  ChoiceChip(
                    label: Text('${d.emoji} ${d.label}'),
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
            label('Where'),
            _whereField(),
            label('When'),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(dayLabel(_day)),
              onPressed: _pickDate,
            ),
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
            label('Grades'),
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
            label('Notes'),
            TextFormField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'Meeting point, car seats, the routes you have in mind…',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Text(widget.plan == null ? 'Publish the plan' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
