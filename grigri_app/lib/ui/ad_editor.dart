import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/ad.dart';
import '../model/plan.dart' show MediaKind;
import '../theme.dart';
import 'ad_card.dart';
import 'chat_media.dart';
import 'common.dart';

/// A new ad (specs/ads.md): the text over it, its link, and a photo or
/// video, with a preview of its card on the deck. **Send for review**
/// uploads the media and saves the ad, waiting for an admin; pops true.
class AdEditor extends StatefulWidget {
  const AdEditor({super.key, this.pickMedia = pickChatMedia});

  /// The device's photo and video picker (tests pass their own).
  final ChatMediaPicker pickMedia;

  @override
  State<AdEditor> createState() => _AdEditorState();
}

class _AdEditorState extends State<AdEditor> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _link = TextEditingController(text: 'https://');
  ChatMedia? _media;
  bool _sending = false;
  double? _progress;

  static const maxText = 200;

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    super.dispose();
  }

  /// The link as typed, when it's a web address the API takes.
  Uri? get _url {
    final url = Uri.tryParse(_link.text.trim());
    if (url == null ||
        !(url.scheme == 'https' || url.scheme == 'http') ||
        !url.host.contains('.')) {
      return null;
    }
    return url;
  }

  Future<void> _pick() async {
    final source = await chooseChatMediaSource(context);
    if (source == null) return;
    final media = await widget.pickMedia(source);
    if (media != null && mounted) setState(() => _media = media);
  }

  Future<void> _send() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_text.text.trim().isEmpty && _media == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.adNeedsContent)));
      return;
    }
    setState(() => _sending = true);
    final ok = await StoreScope.read(context).createAd(
      text: _text.text,
      link: _link.text,
      media: _media,
      onProgress: (sent) {
        if (mounted) setState(() => _progress = sent);
      },
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      _progress = null;
    });
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final store = StoreScope.of(context);
    final media = _media;
    final preview = Ad(
      id: 'preview',
      ownerId: store.me.id,
      text: _text.text.trim(),
      link: _url ?? Uri.parse('https://example.com'),
      mediaKind: media?.kind,
      mediaKey: media?.kind == MediaKind.video ? 'preview' : null,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.newAd)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _text,
              maxLength: maxText,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.adTextLabel),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey('ad link'),
              controller: _link,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.adLinkLabel),
              validator: (_) => _url == null ? l.adLinkInvalid : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(l.adAddMedia),
                  onPressed: _sending ? null : _pick,
                ),
                if (media != null)
                  IconButton(
                    tooltip: l.adRemoveMedia,
                    icon: const Icon(Icons.close),
                    onPressed: _sending
                        ? null
                        : () => setState(() => _media = null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l.adPreview.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: Mountain.granite,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: IgnorePointer(
                    child: AdCard(
                      preview,
                      previewMedia: media?.kind == MediaKind.image
                          ? MemoryImage(media!.bytes)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_sending)
              LinearProgressIndicator(value: _progress)
            else
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: Text(l.adSubmit),
                onPressed: _send,
              ),
          ],
        ),
      ),
    );
  }
}
