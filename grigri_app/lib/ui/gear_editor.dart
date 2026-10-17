import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../theme.dart';
import 'common.dart';
import 'profile_editor.dart';

/// Edits the gear I own: what the group shares (a rope, a crash pad, a
/// car) and what each climber needs their own of (a harness), and up to
/// [Climber.maxGearPhotos] photos of it. Plans check their group's gear
/// against what they need (specs/gear.md).
class GearEditor extends StatefulWidget {
  const GearEditor({super.key, this.pick = pickPhoto});

  final PhotoPicker pick;

  @override
  State<GearEditor> createState() => _GearEditorState();
}

class _GearEditorState extends State<GearEditor> {
  late final Climber _me = StoreScope.read(context).me;
  late final Set<Gear> _gear = {..._me.gear};
  late final List<EditablePhoto> _photos = [
    for (final key in _me.gearPhotos) EditablePhoto.saved(key),
  ];
  bool _saving = false;

  Future<void> _addPhoto() async {
    final photo = await choosePhoto(context, widget.pick, 1080);
    if (photo != null) setState(() => _photos.add(EditablePhoto.picked(photo)));
  }

  /// A photo's image: the picked bytes, or the saved one.
  ImageProvider _image(EditablePhoto photo) => photo.bytes != null
      ? MemoryImage(photo.bytes!)
      : StoreScope.read(context).photo(photo.key!);

  Future<void> _save() async {
    if (_saving) return;
    final store = StoreScope.read(context);
    setState(() => _saving = true);
    final saved = await store.saveProfile(
      _me.copyWith(gear: _gear),
      photo: _me.photo == null ? null : EditablePhoto.saved(_me.photo!),
      gearPhotos: _photos,
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
    Widget chips(bool shared) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final g in Gear.values)
          if (g.shared == shared)
            FilterChip(
              label: Text(g.label(l)),
              selected: _gear.contains(g),
              onSelected: (on) =>
                  setState(() => on ? _gear.add(g) : _gear.remove(g)),
            ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.yourGear),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          label(l.gearShared, l.gearSharedHint),
          chips(true),
          label(l.gearPersonal, l.gearPersonalHint),
          chips(false),
          label(l.gearPhotos, l.gearHint),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (i, photo) in _photos.indexed)
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
                        onPressed: () => setState(() => _photos.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              if (_photos.length < Climber.maxGearPhotos)
                _AddPhotoTile(onPressed: _addPhoto),
            ],
          ),
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
    );
  }
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
