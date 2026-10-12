import 'package:flutter/material.dart';

import '../model/climbing.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';

/// Creates a plan, or edits one I organize: what, where, when, grades
/// and how many people.
class PlanEditor extends StatefulWidget {
  const PlanEditor({super.key, this.plan});

  /// The plan to edit; null for a new one.
  final Plan? plan;

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.plan?.title);
  late final _place = TextEditingController(text: widget.plan?.place);
  late final _area = TextEditingController(text: widget.plan?.area);
  late final _notes = TextEditingController(text: widget.plan?.notes);
  late Discipline _discipline = widget.plan?.discipline ?? Discipline.sport;
  late DateTime _start = widget.plan?.start ?? _nextSaturday();
  late int _hours = widget.plan?.hours ?? 6;
  late int _spots = widget.plan?.spots ?? 3;
  late RangeValues _grades;

  static DateTime _nextSaturday() {
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day + 1, 9);
    while (d.weekday != DateTime.saturday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  @override
  void initState() {
    super.initState();
    final g = widget.plan?.grades;
    _grades = g != null
        ? RangeValues(g.min.toDouble(), g.max.toDouble())
        : _defaultGrades(_discipline);
  }

  /// My own grades for the discipline, or the scale's middle.
  RangeValues _defaultGrades(Discipline d) {
    final mine = widget.plan == null
        ? StoreScope.read(context).me.levels[d]
        : null;
    if (mine != null) {
      return RangeValues(mine.min.toDouble(), mine.max.toDouble());
    }
    final n = d.scale.grades.length;
    return RangeValues((n * 0.3).roundToDouble(), (n * 0.5).roundToDouble());
  }

  @override
  void dispose() {
    for (final c in [_title, _place, _area, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start.isBefore(now) ? now : _start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(
        () => _start = DateTime(
          date.year,
          date.month,
          date.day,
          _start.hour,
          _start.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time != null) {
      setState(
        () => _start = DateTime(
          _start.year,
          _start.month,
          _start.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    final grades = GradeRange(
      _discipline.scale,
      _grades.start.round(),
      _grades.end.round(),
    );
    final existing = widget.plan;
    if (existing == null) {
      store.createPlan(
        title: _title.text.trim(),
        discipline: _discipline,
        place: _place.text.trim(),
        area: _area.text.trim(),
        start: _start,
        hours: _hours,
        grades: grades,
        spots: _spots,
        notes: _notes.text.trim(),
      );
    } else {
      store.updatePlan(
        existing.copyWith(
          title: _title.text.trim(),
          discipline: _discipline,
          place: _place.text.trim(),
          area: _area.text.trim(),
          start: _start,
          hours: _hours,
          grades: grades,
          spots: _spots,
          notes: _notes.text.trim(),
        ),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scale = _discipline.scale.grades;
    final members = widget.plan?.memberIds.length ?? 1;
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
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Saturday at the crag',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Give the plan a title' : null,
            ),
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
            TextFormField(
              controller: _place,
              decoration: const InputDecoration(
                labelText: 'Crag or gym',
                hintText: 'Siurana',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Where are you climbing?' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _area,
              decoration: const InputDecoration(
                labelText: 'Area (optional)',
                hintText: 'Catalonia',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            label('When'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(dayLabel(_start)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(clock(_start)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('For'),
                Expanded(
                  child: Slider(
                    value: _hours.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    label: '$_hours h',
                    onChanged: (v) => setState(() => _hours = v.round()),
                  ),
                ),
                Text('$_hours h'),
              ],
            ),
            label(
              'Grades: ${scale[_grades.start.round()]}–${scale[_grades.end.round()]}',
            ),
            RangeSlider(
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
            label('Group size'),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Fewer',
                  icon: const Icon(Icons.remove),
                  onPressed: _spots > 2 && _spots > members
                      ? () => setState(() => _spots--)
                      : null,
                ),
                Expanded(
                  child: Text(
                    '$_spots climbers, you included',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'More',
                  icon: const Icon(Icons.add),
                  onPressed: _spots < 12
                      ? () => setState(() => _spots++)
                      : null,
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
