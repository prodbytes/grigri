import 'dart:typed_data';

import 'features.dart';
import 'homography.dart';

/// Where a reference view of a wall is in a camera frame: the transform
/// from the view's pixels to the frame's, and how many corners agreed.
class ViewMatch {
  const ViewMatch(this.homography, this.inliers);

  final Homography homography;
  final int inliers;
}

/// Finds the [reference] view (its features, of a [refWidth]×[refHeight]
/// photo) in a [frame]: nearest descriptors with Lowe's ratio test, then
/// RANSAC. Null when the rock isn't in the frame (too few agree, or the
/// transform is implausible).
ViewMatch? matchView(
  Features frame,
  Features reference,
  double refWidth,
  double refHeight, {
  int maxDistance = 64,
  double ratio = 0.8,
  int minInliers = 15,
  double threshold = 5,
}) {
  if (frame.length < minInliers || reference.length < minInliers) return null;
  final from = <double>[], to = <double>[];
  final fd = frame.descriptors, rd = reference.descriptors;
  // For each frame corner, its nearest reference corner and the runner-up.
  final usedBy = Int32List(reference.length)
    ..fillRange(0, reference.length, -1);
  final bestDist = Int32List(reference.length)
    ..fillRange(0, reference.length, 1 << 30);
  final pairs = <(int, int)>[];
  for (var i = 0; i < frame.length; i++) {
    var best = 1 << 30, second = 1 << 30, bestJ = -1;
    for (var j = 0; j < reference.length; j++) {
      final d = hamming(fd, i * Features.words, rd, j * Features.words);
      if (d < best) {
        second = best;
        best = d;
        bestJ = j;
      } else if (d < second) {
        second = d;
      }
    }
    if (bestJ < 0 || best > maxDistance || best > ratio * second) continue;
    // One frame corner per reference corner: the closest.
    if (best < bestDist[bestJ]) {
      bestDist[bestJ] = best;
      usedBy[bestJ] = i;
    }
  }
  for (var j = 0; j < reference.length; j++) {
    if (usedBy[j] >= 0) pairs.add((usedBy[j], j));
  }
  if (pairs.length < minInliers) return null;
  for (final (i, j) in pairs) {
    from.addAll([reference.xs[j].toDouble(), reference.ys[j].toDouble()]);
    to.addAll([frame.xs[i].toDouble(), frame.ys[i].toDouble()]);
  }
  final found = Homography.ransac(
    from,
    to,
    threshold: threshold,
    minInliers: minInliers,
  );
  if (found == null) return null;
  if (!found.homography.isPlausible(refWidth, refHeight)) return null;
  return ViewMatch(found.homography, found.inliers);
}
