import 'package:flutter/material.dart';

import '../model/climber.dart';
import '../model/climbing.dart';
import '../theme.dart';
import 'common.dart';

/// Edits my profile: about me, the grades I climb per discipline, when I
/// like to climb, where, and my gear.
class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key});

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final Climber _me = StoreScope.read(context).me;
  late final _name = TextEditingController(text: _me.name);
  late final _age = TextEditingController(text: '${_me.age}');
  late final _years = TextEditingController(text: '${_me.yearsClimbing}');
  late final _home = TextEditingController(text: _me.homeArea);
  late final _bio = TextEditingController(text: _me.bio);
  final _newPlace = TextEditingController();
  late final Map<Discipline, RangeValues> _levels = {
    for (final e in _me.levels.entries)
      e.key: RangeValues(e.value.min.toDouble(), e.value.max.toDouble()),
  };
  late final Set<Slot> _availability = {..._me.availability};
  late final List<String> _places = [..._me.places];
  late final Set<Gear> _gear = {..._me.gear};

  @override
  void dispose() {
    for (final c in [_name, _age, _years, _home, _bio, _newPlace]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPlace() {
    final place = _newPlace.text.trim();
    if (place.isEmpty || _places.contains(place)) return;
    setState(() => _places.add(place));
    _newPlace.clear();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    StoreScope.read(context).updateProfile(
      _me.copyWith(
        name: _name.text.trim(),
        age: int.parse(_age.text.trim()),
        yearsClimbing: int.tryParse(_years.text.trim()) ?? 0,
        homeArea: _home.text.trim(),
        bio: _bio.text.trim(),
        levels: {
          for (final e in _levels.entries)
            e.key: GradeRange(
              e.key.scale,
              e.value.start.round(),
              e.value.end.round(),
            ),
        },
        availability: _availability,
        places: _places,
        gear: _gear,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget label(String s, [String? hint]) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.toUpperCase(),
            style: text.labelSmall?.copyWith(
              color: Mountain.granite,
              letterSpacing: 1.2,
            ),
          ),
          if (hint != null)
            Text(
              hint,
              style: text.bodySmall?.copyWith(color: Mountain.granite),
            ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Your name, please' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _age,
                    decoration: const InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final age = int.tryParse((v ?? '').trim());
                      return age == null || age < 16 || age > 99
                          ? '16 to 99'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _years,
                    decoration: const InputDecoration(
                      labelText: 'Years climbing',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _home,
              decoration: const InputDecoration(
                labelText: 'Home area',
                hintText: 'Barcelona',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bio,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'About you'),
              textCapitalization: TextCapitalization.sentences,
            ),
            label(
              'What you climb',
              'Pick your disciplines and the grades you climb.',
            ),
            for (final d in Discipline.values) _levelEditor(d),
            label('When you climb', 'Tap the times you\'re usually free.'),
            _AvailabilityGrid(
              selected: _availability,
              onToggle: (slot) => setState(() {
                if (!_availability.remove(slot)) _availability.add(slot);
              }),
            ),
            label('Where you climb', 'Crags and gyms you like.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final place in _places)
                  InputChip(
                    label: Text(place),
                    avatar: const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: Mountain.tan,
                    ),
                    onDeleted: () => setState(() => _places.remove(place)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPlace,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Add a place',
                suffixIcon: IconButton(
                  tooltip: 'Add',
                  icon: const Icon(Icons.add),
                  onPressed: _addPlace,
                ),
              ),
              onSubmitted: (_) => _addPlace(),
            ),
            label('Gear you can bring'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in Gear.values)
                  FilterChip(
                    label: Text(g.label),
                    selected: _gear.contains(g),
                    onSelected: (on) =>
                        setState(() => on ? _gear.add(g) : _gear.remove(g)),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  Widget _levelEditor(Discipline d) {
    final grades = d.scale.grades;
    final range = _levels[d];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${d.emoji} ${d.label}'),
          subtitle: range == null
              ? null
              : Text(
                  '${grades[range.start.round()]}–${grades[range.end.round()]}',
                  style: const TextStyle(color: Mountain.olive),
                ),
          value: range != null,
          onChanged: (on) => setState(() {
            if (on) {
              final n = grades.length;
              _levels[d] = RangeValues(
                (n * 0.3).roundToDouble(),
                (n * 0.45).roundToDouble(),
              );
            } else {
              _levels.remove(d);
            }
          }),
        ),
        if (range != null)
          RangeSlider(
            values: range,
            min: 0,
            max: (grades.length - 1).toDouble(),
            divisions: grades.length - 1,
            labels: RangeLabels(
              grades[range.start.round()],
              grades[range.end.round()],
            ),
            onChanged: (v) => setState(() => _levels[d] = v),
          ),
      ],
    );
  }
}

/// Days down, parts of the day across: tap to toggle.
class _AvailabilityGrid extends StatelessWidget {
  const _AvailabilityGrid({required this.selected, required this.onToggle});

  final Set<Slot> selected;
  final void Function(Slot slot) onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 48),
            for (final part in DayPart.values)
              Expanded(
                child: Text(
                  part.label,
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(color: Mountain.granite),
                ),
              ),
          ],
        ),
        for (var day = 1; day <= 7; day++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text(weekdayLabels[day - 1])),
                for (final part in DayPart.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _Cell(
                        on: selected.contains(Slot(day, part)),
                        label: '${weekdayLabels[day - 1]} ${part.label}',
                        onTap: () => onToggle(Slot(day, part)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.on, required this.label, required this.onTap});

  final bool on;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    toggled: on,
    button: true,
    child: Material(
      color: on ? Mountain.pine : Mountain.surfaceHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: on
              ? const Icon(Icons.check, size: 18, color: Mountain.sand)
              : null,
        ),
      ),
    ),
  );
}
