import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../model/pics.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'chat_media.dart';
import 'common.dart';

/// The plan screen's photos (specs/pics.md): "Your Pics", what the group
/// added or sent in its chat (members only; they add photos here), and
/// "GriGri Pics", Grigri's own photos of the plan's crag, credited.
class PlanPicsSections extends StatefulWidget {
  const PlanPicsSections({
    super.key,
    required this.plan,
    this.pick = pickChatMedia,
  });

  final Plan plan;

  /// Picks a photo (from the camera or the gallery); tests swap it.
  final ChatMediaPicker pick;

  @override
  State<PlanPicsSections> createState() => _PlanPicsSectionsState();
}

class _PlanPicsSectionsState extends State<PlanPicsSections> {
  /// The share of the photo being added that has gone up; null: none.
  double? _uploading;

  Future<void> _add() async {
    final store = StoreScope.read(context);
    final source = await _chooseSource(context);
    if (source == null || !mounted) return;
    final media = await widget.pick(source);
    if (media == null || !mounted) return;
    setState(() => _uploading = 0);
    await store.addPlanPic(
      widget.plan.id,
      media.bytes,
      onProgress: (sent) {
        if (mounted) setState(() => _uploading = sent);
      },
    );
    if (mounted) setState(() => _uploading = null);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final pics = store.pics(widget.plan.id);
    if (pics == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pics.member) ...[
          const SizedBox(height: 20),
          _SectionLabel(l.yourPics),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _AddTile(uploading: _uploading, onTap: _add),
                for (final pic in pics.yours.reversed)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _Thumb(
                      key: ValueKey('pic ${pic.id}'),
                      image: store.photo(pic.key),
                      width: 96,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlanPicViewer(pic: pic),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (pics.yours.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.yourPicsEmpty,
              style: const TextStyle(color: Mountain.granite),
            ),
          ],
        ],
        const SizedBox(height: 20),
        _SectionLabel(l.grigriPics),
        const SizedBox(height: 8),
        if (pics.grigri.isEmpty)
          Text(
            l.grigriPicsEmpty,
            style: const TextStyle(color: Mountain.granite),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pics.grigri.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final pic = pics.grigri[i];
                return _Thumb(
                  key: ValueKey('grigri ${pic.key}'),
                  image: store.grigriPic(pic.key),
                  width: 170,
                  label: pic.crag,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GrigriPicViewer(pic: pic),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Where a plan photo comes from: the camera (where there is one) or the
/// gallery. Null when dismissed.
Future<ChatMediaSource?> _chooseSource(BuildContext context) {
  final camera = ImagePicker().supportsImageSource(ImageSource.camera);
  final l = context.l10n;
  return showModalBottomSheet<ChatMediaSource>(
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
              onTap: () => Navigator.pop(context, ChatMediaSource.takePhoto),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l.choosePhoto),
            onTap: () => Navigator.pop(context, ChatMediaSource.choosePhoto),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Mountain.granite, letterSpacing: 1.2),
  );
}

/// The first tile of "Your Pics": adds a photo, or shows one going up.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.uploading, required this.onTap});

  final double? uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final busy = uploading != null;
    return Tooltip(
      message: context.l10n.addPlanPic,
      child: InkWell(
        key: const ValueKey('add plan pic'),
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Container(
          width: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Mountain.granite),
          ),
          child: Center(
            child: busy
                ? CircularProgressIndicator(
                    value: uploading! > 0 ? uploading : null,
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    color: Mountain.granite,
                  ),
          ),
        ),
      ),
    );
  }
}

/// A photo cropped to fill its tile, with an optional label over it.
class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.image,
    required this.width,
    required this.onTap,
    this.label,
  });

  final ImageProvider image;
  final double width;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: width,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                image: image,
                fit: BoxFit.cover,
                semanticLabel: label ?? context.l10n.photoMessage,
                errorBuilder: (context, _, _) => Container(
                  color: Mountain.surface,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Mountain.granite,
                  ),
                ),
              ),
              if (label != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Mountain.snow),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A photo of "Your Pics", whole: who added it, and deleting it (whoever
/// added it, or the organizer).
class PlanPicViewer extends StatelessWidget {
  const PlanPicViewer({super.key, required this.pic});

  final PlanPic pic;

  Future<void> _delete(BuildContext context) async {
    final store = StoreScope.read(context);
    final l = context.l10n;
    final navigator = Navigator.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deletePicQuestion),
        content: Text(
          pic.fromChat ? l.deleteChatPicMessage : l.deletePicMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete, style: const TextStyle(color: Mountain.clay)),
          ),
        ],
      ),
    );
    if (sure != true) return;
    if (await store.deletePlanPic(pic)) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final name = pic.uploaderId == store.me.id
        ? l.you
        : store.climber(pic.uploaderId).name;
    return _Viewer(
      image: store.photo(pic.key),
      actions: [
        if (store.canDeletePic(pic))
          IconButton(
            tooltip: l.deletePic,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context),
          ),
      ],
      lines: [pic.fromChat ? l.picFromChat(name) : l.picAddedBy(name)],
    );
  }
}

/// A GriGri Pics photo, whole: its crag, caption and credit (with where it
/// comes from, to copy).
class GrigriPicViewer extends StatelessWidget {
  const GrigriPicViewer({super.key, required this.pic});

  final GrigriPic pic;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    return _Viewer(
      image: store.grigriPic(pic.key),
      title: pic.crag,
      lines: [
        if (pic.caption.isNotEmpty) pic.caption,
        if (pic.author.isNotEmpty) l.picCredit(pic.author, pic.license),
      ],
      source: pic.source,
    );
  }
}

class _Viewer extends StatelessWidget {
  const _Viewer({
    required this.image,
    required this.lines,
    this.title,
    this.actions = const [],
    this.source,
  });

  final ImageProvider image;
  final String? title;
  final List<String> lines;
  final List<Widget> actions;
  final String? source;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: title == null ? null : Text(title!),
      actions: actions,
    ),
    body: Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: Image(image: image, fit: BoxFit.contain),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(line, style: const TextStyle(color: Mountain.snow)),
                if (source != null && source!.isNotEmpty)
                  InkWell(
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: source!)),
                    child: Text(
                      source!,
                      style: const TextStyle(
                        color: Mountain.sky,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
