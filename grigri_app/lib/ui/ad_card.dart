import 'package:flutter/material.dart';

import '../model/ad.dart';
import '../model/plan.dart' show MediaKind;
import '../theme.dart';
import 'chat_media.dart' show VideoViewer;
import 'common.dart';

/// An ad on the Discover deck (specs/ads.md): its photo or video, with
/// its text over it, who placed it and where its link goes. Swiping it
/// right (or ✓) opens the link. A video loads only when played.
class AdCard extends StatelessWidget {
  const AdCard(this.ad, {super.key, this.previewMedia});

  final Ad ad;

  /// The editor's preview: the picked photo, not uploaded yet.
  final ImageProvider? previewMedia;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final owner = store.climber(ad.ownerId);
    final key = ad.mediaKey;
    final ImageProvider? image =
        previewMedia ??
        (key != null && ad.mediaKind == MediaKind.image
            ? store.photo(key)
            : null);
    final video = key != null && ad.mediaKind == MediaKind.video;
    return Card(
      key: ValueKey('ad ${ad.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The media fills the card; text alone sits on the mountain
          // gradient.
          if (image != null)
            Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _Backdrop(),
            )
          else
            const _Backdrop(),
          if (video)
            Center(
              child: IconButton(
                iconSize: 72,
                tooltip: l.playVideo,
                color: Mountain.snow,
                icon: const Icon(Icons.play_circle_fill),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => VideoViewer(url: store.api.photoUrl(key)),
                  ),
                ),
              ),
            ),
          // Readable over any photo: a dark fade under the text.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Mountain.night.withValues(alpha: 0.88),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ad.text.isNotEmpty)
                      Text(
                        ad.text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          color: Mountain.snow,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.link, size: 18, color: Mountain.sky),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ad.site,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Mountain.sky),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.adBy(owner.name),
                      style: text.bodySmall?.copyWith(color: Mountain.sand),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: Tag(
              l.adTag,
              icon: Icons.campaign_outlined,
              color: Mountain.sand,
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2B4152), Mountain.pine],
      ),
    ),
  );
}
