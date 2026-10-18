import 'package:flutter/material.dart';

import '../model/pics.dart';
import 'common.dart';

/// A GriGri Pics photo filling its box, cropped to cover it: the smallest
/// of its copies whose pixels cover the box on this screen ([picKeyFor]),
/// so it looks as sharp as the photo itself, else the photo. A copy that
/// fails to load gives way to the photo, and only the photo failing shows
/// [errorBuilder] (specs/pics.md, Sizes).
class GrigriPicImage extends StatelessWidget {
  const GrigriPicImage({
    super.key,
    required this.picKey,
    required this.variants,
    this.imageKey,
    this.semanticLabel,
    this.frameBuilder,
    this.errorBuilder,
  });

  /// The photo's own key.
  final String picKey;
  final List<PicVariant> variants;

  /// The [Image]'s key.
  final Key? imageKey;
  final String? semanticLabel;
  final ImageFrameBuilder? frameBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final chosen = picKeyFor(
          picKey,
          variants,
          box: constraints.biggest,
          devicePixelRatio: ratio,
        );
        Widget image(String key, ImageErrorWidgetBuilder? onError) => Image(
          key: imageKey,
          image: store.grigriPic(key),
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
          frameBuilder: frameBuilder,
          // A bigger box (turned sideways) keeps the photo shown until the
          // copy it needs arrives.
          gaplessPlayback: true,
          errorBuilder: onError,
        );
        return image(
          chosen,
          chosen == picKey
              ? errorBuilder
              : (context, _, _) => image(picKey, errorBuilder),
        );
      },
    );
  }
}
