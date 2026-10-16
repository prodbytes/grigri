import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/vision/features.dart';
import 'package:grigri_app/vision/gray.dart';
import 'package:grigri_app/vision/homography.dart';
import 'package:grigri_app/vision/matcher.dart';

/// A made-up rock face: blobs of light and shadow at several sizes, plus
/// grain, so it has corners everywhere, as real rock does.
GrayImage rock(int w, int h, {int seed = 1}) {
  final random = math.Random(seed);
  final f = Float64List(w * h);
  for (final (count, radius, strength) in [
    (40, 40.0, 50.0),
    (300, 12.0, 40.0),
    (1500, 4.0, 30.0),
  ]) {
    for (var n = 0; n < count; n++) {
      final cx = random.nextDouble() * w, cy = random.nextDouble() * h;
      final s = (random.nextDouble() * 2 - 1) * strength;
      final r = radius * (0.5 + random.nextDouble());
      final x0 = math.max(0, (cx - 2 * r).floor());
      final x1 = math.min(w - 1, (cx + 2 * r).ceil());
      final y0 = math.max(0, (cy - 2 * r).floor());
      final y1 = math.min(h - 1, (cy + 2 * r).ceil());
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final d2 = ((x - cx) * (x - cx) + (y - cy) * (y - cy)) / (r * r);
          f[y * w + x] += s * math.exp(-d2);
        }
      }
    }
  }
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = (128 + f[i] + random.nextInt(9) - 4).round().clamp(0, 255);
  }
  return GrayImage(w, h, out);
}

/// [src] seen through [h] (source to destination), as a [w]×[h2] frame,
/// with its light changed and fresh sensor noise.
GrayImage view(GrayImage src, Homography h, int w, int h2, {int seed = 2}) {
  final inv = h.inverse();
  final random = math.Random(seed);
  final out = Uint8List(w * h2);
  for (var y = 0; y < h2; y++) {
    for (var x = 0; x < w; x++) {
      final (sx, sy) = inv.apply(x.toDouble(), y.toDouble());
      final v = sx < 0 || sy < 0 || sx > src.width - 1 || sy > src.height - 1
          ? 90
          : src.sample(sx, sy);
      out[y * w + x] = (v * 0.8 + 25 + random.nextInt(11) - 5).round().clamp(
        0,
        255,
      );
    }
  }
  return GrayImage(w, h2, out);
}

void main() {
  test('homography: fits exact pairs, inverts, composes', () {
    final h = Homography.fromList([
      1.1,
      0.05,
      12,
      -0.04,
      0.95,
      30,
      0.0002,
      -0.0001,
      1,
    ]);
    final from = <double>[], to = <double>[];
    for (final (x, y) in [
      (0.0, 0.0),
      (400.0, 10.0),
      (390.0, 300.0),
      (5.0, 310.0),
      (200.0, 150.0),
    ]) {
      final (u, v) = h.apply(x, y);
      from.addAll([x, y]);
      to.addAll([u, v]);
    }
    final fit = Homography.fit(from, to)!;
    for (var i = 0; i < 9; i++) {
      expect(fit.m[i], closeTo(h.m[i], 1e-6));
    }
    final (x, y) = h.then(h.inverse()).apply(123, 45);
    expect(x, closeTo(123, 1e-6));
    expect(y, closeTo(45, 1e-6));
    expect(h.isPlausible(400, 300), isTrue);
    // A mirror image isn't a view of the same face.
    expect(
      Homography.fromList([-1, 0, 400, 0, 1, 0, 0, 0, 1]).isPlausible(400, 300),
      isFalse,
    );
  });

  test('descriptors: the same corner described twice matches itself', () {
    final img = rock(200, 160);
    final a = detect(img), b = detect(img);
    expect(a.length, greaterThan(100));
    expect(hamming(a.descriptors, 0, b.descriptors, 0), 0);
  });

  test('finds a wall seen from another angle, closer, in other light', () {
    final wall = rock(640, 480);
    // Tilted 8°, 1.3× closer, shifted, and in perspective.
    final a = 8 * math.pi / 180;
    final truth = Homography.fromList([
      1.3 * math.cos(a),
      -1.3 * math.sin(a),
      -180,
      1.3 * math.sin(a),
      1.3 * math.cos(a),
      -120,
      0.00012,
      0.00005,
      1,
    ]);
    final frame = view(wall, truth, 480, 360);
    final reference = detectPyramid(wall);
    final seen = detect(frame);
    final watch = Stopwatch()..start();
    final match = matchView(seen, reference, 640, 480);
    final ms = watch.elapsedMilliseconds;
    expect(match, isNotNull);
    expect(match!.inliers, greaterThan(30));
    // A route's bolts land where they are in the frame (within 3 px).
    for (final (x, y) in [(300.0, 200.0), (350.0, 260.0), (260.0, 240.0)]) {
      final (ex, ey) = truth.apply(x, y);
      final (gx, gy) = match.homography.apply(x, y);
      expect((gx - ex).abs(), lessThan(3), reason: 'x at ($x, $y)');
      expect((gy - ey).abs(), lessThan(3), reason: 'y at ($x, $y)');
    }
    // ignore: avoid_print
    print('matched in $ms ms, ${match.inliers} inliers of ${seen.length}');
  });

  test("another wall isn't taken for this one", () {
    final reference = detectPyramid(rock(640, 480, seed: 1));
    final other = detect(rock(480, 360, seed: 99));
    expect(matchView(other, reference, 640, 480), isNull);
  });

  test('features survive packing (for isolates and caching)', () {
    final f = detect(rock(200, 160));
    final back = Features.unpack(f.pack());
    expect(back.length, f.length);
    expect(back.descriptors, f.descriptors);
    expect(back.xs, f.xs);
  });
}
