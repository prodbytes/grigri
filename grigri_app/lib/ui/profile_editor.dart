import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/grigri_store.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../theme.dart';
import 'common.dart';

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

/// Edits my profile: my photo, about me, the grades I climb per
/// discipline, and my gear with its photos. When and where are for plans.
/// With [create], it's the "Create your profile" step after the first
/// sign-in, before the tabs.
class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, this.pick = pickPhoto, this.create = false});

  final PhotoPicker pick;
  final bool create;

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final Climber _me =
      StoreScope.read(context).meOrNull ??
      Climber(id: '', name: StoreScope.read(context).suggestedName);
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
  late final Set<Gear> _gear = {..._me.gear};
  late final List<EditablePhoto> _gearPhotos = [
    for (final key in _me.gearPhotos) EditablePhoto.saved(key),
  ];

  @override
  void dispose() {
    for (final c in [_name, _age, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Asks camera or library (and, for my photo, offers to remove it), then
  /// picks. Null when cancelled.
  Future<Uint8List?> _choose(double maxSide, {VoidCallback? onRemove}) async {
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
      return await widget.pick(source, maxSide);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.photoFailed)));
      }
      return null;
    }
  }

  Future<void> _changePhoto() async {
    final photo = await _choose(
      640,
      onRemove: _photo == null ? null : () => setState(() => _photo = null),
    );
    if (photo != null) setState(() => _photo = EditablePhoto.picked(photo));
  }

  Future<void> _addGearPhoto() async {
    final photo = await _choose(1080);
    if (photo != null) {
      setState(() => _gearPhotos.add(EditablePhoto.picked(photo)));
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
        gear: _gear,
      ),
      photo: _photo,
      gearPhotos: _gearPhotos,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved && !widget.create) Navigator.of(context).pop();
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
        automaticallyImplyLeading: !widget.create,
        title: Text(widget.create ? l.createProfile : l.editProfile),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
          if (widget.create)
            PopupMenuButton<String>(
              tooltip: l.more,
              onSelected: (_) => StoreScope.read(context).signOut(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'signOut', child: Text(l.signOut)),
              ],
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (widget.create)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  l.welcomeIntro,
                  style: text.bodyMedium?.copyWith(color: Mountain.snow),
                ),
              ),
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
            label(l.whatYouClimb, l.whatYouClimbHint),
            const GradeSystemToggle(),
            for (final d in Discipline.values) _levelEditor(d),
            label(l.gearYouCanBring, l.gearHint),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in Gear.values)
                  FilterChip(
                    label: Text(g.label(l)),
                    selected: _gear.contains(g),
                    onSelected: (on) =>
                        setState(() => on ? _gear.add(g) : _gear.remove(g)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, photo) in _gearPhotos.indexed)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PhotoThumb(_image(photo), label: l.gearPhoto(i + 1)),
                      Positioned(
                        top: -10,
                        right: -10,
                        child: IconButton.filledTonal(
                          tooltip: l.removeGearPhoto(i + 1),
                          iconSize: 16,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _gearPhotos.removeAt(i)),
                        ),
                      ),
                    ],
                  ),
                if (_gearPhotos.length < Climber.maxGearPhotos)
                  _AddPhotoTile(onPressed: _addGearPhoto),
              ],
            ),
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
                  : Text(widget.create ? l.startClimbing : l.save),
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

/// The empty tile that adds a gear photo.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.addGearPhoto,
    child: Material(
      color: Mountain.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: const SizedBox(
          width: 84,
          height: 84,
          child: Icon(Icons.add_a_photo_outlined, color: Mountain.granite),
        ),
      ),
    ),
  );
}
