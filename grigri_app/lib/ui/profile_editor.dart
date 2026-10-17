import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/grigri_store.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/location.dart';
import '../theme.dart';
import 'common.dart';
import 'location_picker.dart';

/// Picks a photo from the camera or the library, downsized so its longer
/// side is at most [maxSide] pixels; null when cancelled.
typedef PhotoPicker = Future<Uint8List?> Function(
  ImageSource source,
  double maxSide,
);

/// The device's picker. Photos are downsized and recompressed as they're
/// picked, so their uploads stay small.
Future<Uint8List?> pickPhoto(ImageSource source, double maxSide) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: maxSide,
    maxHeight: maxSide,
    imageQuality: 75,
  );
  return file?.readAsBytes();
}

/// Asks camera or library (and, given [onRemove], offers to remove the
/// photo), then picks with [pick]. Null when cancelled.
Future<Uint8List?> choosePhoto(
  BuildContext context,
  PhotoPicker pick,
  double maxSide, {
  VoidCallback? onRemove,
}) async {
  final camera = ImagePicker().supportsImageSource(ImageSource.camera);
  final l = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Mountain.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (camera)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l.choosePhoto),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (onRemove != null)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Mountain.clay),
              title: Text(
                l.removePhoto,
                style: const TextStyle(color: Mountain.clay),
              ),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    return await pick(source, maxSide);
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.photoFailed)));
    }
    return null;
  }
}

/// Edits my profile: my photo, about me, how grades are written, the
/// grades I climb per discipline, and where I climb (my location and other areas, private,
/// which rank the Discover deck). When is for plans; my gear has its own
/// editor, from the Profile tab's gear card.
/// My profile is made from my Google account at the first sign-in; this is
/// where I fill in the rest.
class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, this.pick = pickPhoto});

  final PhotoPicker pick;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final Climber _me = StoreScope.read(context).me;
  late final _name = TextEditingController(text: _me.name);
  late final _age = TextEditingController(text: '${_me.age ?? ''}');
  late final _bio = TextEditingController(text: _me.bio);
  late EditablePhoto? _photo = _me.photo == null
      ? null
      : EditablePhoto.saved(_me.photo!);
  bool _saving = false;
  late final Map<Discipline, RangeValues> _levels = {
    for (final e in _me.levels.entries)
      e.key: RangeValues(e.value.min.toDouble(), e.value.max.toDouble()),
  };
  late Location? _location = _me.location;
  late final List<Location> _areas = [..._me.areas];

  @override
  void dispose() {
    for (final c in [_name, _age, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final photo = await choosePhoto(
      context,
      widget.pick,
      640,
      onRemove: _photo == null ? null : () => setState(() => _photo = null),
    );
    if (photo != null) setState(() => _photo = EditablePhoto.picked(photo));
  }

  Future<void> _pickLocation() async {
    final picked = await pickLocation(
      context,
      title: context.l10n.yourLocation,
    );
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _addArea() async {
    final picked = await pickLocation(context, title: context.l10n.addArea);
    if (picked != null && !_areas.contains(picked)) {
      setState(() => _areas.add(picked));
    }
  }

  /// A photo's image: the picked bytes, or the saved one.
  ImageProvider _image(EditablePhoto photo) => photo.bytes != null
      ? MemoryImage(photo.bytes!)
      : StoreScope.read(context).photo(photo.key!);

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final store = StoreScope.read(context);
    setState(() => _saving = true);
    final saved = await store.saveProfile(
      _me.copyWith(
        name: _name.text.trim(),
        age: int.tryParse(_age.text.trim()),
        bio: _bio.text.trim(),
        levels: {
          for (final e in _levels.entries)
            e.key: GradeRange(
              e.key.scale,
              e.value.start.round(),
              e.value.end.round(),
            ),
        },
        location: _location,
        areas: _areas,
      ),
      photo: _photo,
      gearPhotos: [for (final key in _me.gearPhotos) EditablePhoto.saved(key)],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
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
        title: Text(l.editProfile),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: _PhotoButton(
                avatar: Avatar(
                  _me.copyWith(
                    name: _name.text.isEmpty ? '?' : _name.text,
                    photo: null,
                  ),
                  image: _photo == null ? null : _image(_photo!),
                  radius: 52,
                ),
                tooltip: _photo == null ? l.addPhoto : l.changePhoto,
                onPressed: _changePhoto,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l.nameLabel),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l.nameRequired : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _age,
              decoration: InputDecoration(labelText: l.ageLabel),
              keyboardType: TextInputType.number,
              validator: (v) {
                final text = (v ?? '').trim();
                if (text.isEmpty) return null;
                final age = int.tryParse(text);
                return age == null || age < 16 || age > 99
                    ? l.ageRange(16, 99)
                    : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bio,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: l.bioLabel),
              textCapitalization: TextCapitalization.sentences,
            ),
            label(l.whereYouClimb, l.whereYouClimbHint),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location, color: Mountain.sky),
              title: Text(_location?.name ?? l.setYourLocation),
              subtitle: Text(
                l.yourLocation,
                style: const TextStyle(color: Mountain.granite),
              ),
              trailing: _location == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: l.clearYourLocation,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _location = null),
                    ),
              onTap: _pickLocation,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, a) in _areas.indexed)
                  InputChip(
                    avatar: const Icon(Icons.place_outlined, size: 18),
                    label: Text(a.name),
                    deleteButtonTooltipMessage: l.removeArea(a.name),
                    onDeleted: () => setState(() => _areas.removeAt(i)),
                  ),
                if (_areas.length < Climber.maxAreas)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(l.addArea),
                    onPressed: _addArea,
                  ),
              ],
            ),
            label(l.gradeSystem, l.gradeSystemHint),
            const GradeSystemToggle(examples: true),
            label(l.whatYouClimb, l.whatYouClimbHint),
            for (final d in Discipline.values) _levelEditor(d),
            label(l.language),
            const LanguagePicker(),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelEditor(Discipline d) {
    final grades = d.scale.grades(StoreScope.of(context).gradeSystem);
    final range = _levels[d];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${d.emoji} ${d.label(context.l10n)}'),
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

/// My avatar with a camera badge: tap to add, change or remove the photo.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.avatar,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget avatar;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Stack(
          children: [
            avatar,
            const Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Mountain.pine,
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: Mountain.sand,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
