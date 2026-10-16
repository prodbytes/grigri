import 'dart:math' as math;
import 'dart:typed_data';

import 'gray.dart';

/// Corners of an image and their binary descriptors, as ORB makes them:
/// FAST corners, spread over a grid, each oriented by its patch's
/// intensity centroid and described by 256 steered BRIEF comparisons.
/// Positions are in the image's own pixels at full size.
class Features {
  Features(this.xs, this.ys, this.descriptors)
    : assert(descriptors.length == xs.length * words);

  /// 256 bits per descriptor, as 8 words of 32.
  static const words = 8;

  final Float32List xs;
  final Float32List ys;
  final Uint32List descriptors;

  int get length => xs.length;

  static final empty = Features(Float32List(0), Float32List(0), Uint32List(0));

  /// Several sets as one (a reference view's pyramid levels).
  static Features join(List<Features> parts) {
    final n = parts.fold<int>(0, (s, f) => s + f.length);
    final xs = Float32List(n), ys = Float32List(n);
    final d = Uint32List(n * words);
    var i = 0;
    for (final f in parts) {
      xs.setRange(i, i + f.length, f.xs);
      ys.setRange(i, i + f.length, f.ys);
      d.setRange(i * words, (i + f.length) * words, f.descriptors);
      i += f.length;
    }
    return Features(xs, ys, d);
  }

  /// For sending between isolates and keeping: x, y, then the words.
  Float64List pack() {
    final out = Float64List(length * (2 + words));
    for (var i = 0; i < length; i++) {
      final o = i * (2 + words);
      out[o] = xs[i];
      out[o + 1] = ys[i];
      for (var w = 0; w < words; w++) {
        out[o + 2 + w] = descriptors[i * words + w].toDouble();
      }
    }
    return out;
  }

  static Features unpack(Float64List packed) {
    final n = packed.length ~/ (2 + words);
    final xs = Float32List(n), ys = Float32List(n);
    final d = Uint32List(n * words);
    for (var i = 0; i < n; i++) {
      final o = i * (2 + words);
      xs[i] = packed[o];
      ys[i] = packed[o + 1];
      for (var w = 0; w < words; w++) {
        d[i * words + w] = packed[o + 2 + w].toInt();
      }
    }
    return Features(xs, ys, d);
  }
}

/// Finds features in [image]: at most [maxFeatures], spread over the image
/// (a grid keeps them off one bright patch). [upright]: described as they
/// stand, not turned to their own orientation. A phone is held upright in
/// front of a wall, and BRIEF takes the tilt of a hand (±15°); estimating
/// each corner's angle on rock's soft patches is noisy, and a wrong angle
/// costs more matches than it saves.
Features detect(
  GrayImage image, {
  int maxFeatures = 500,
  int threshold = 20,
  bool upright = true,
}) {
  const margin = _patchRadius + 3;
  final w = image.width, h = image.height;
  if (w <= margin * 2 || h <= margin * 2) return Features.empty;
  // Dim or flat light gives few corners: the threshold comes down until
  // there are enough (strong ones still come first, by score).
  var t = threshold;
  var scores = _fastScores(image, t, margin);
  while (t > 6 && _count(scores) < maxFeatures * 2) {
    t = (t * 0.6).floor();
    scores = _fastScores(image, t, margin);
  }
  // The best corner of each grid cell first, then the next best, so they
  // cover the image.
  const cell = 24;
  final cols = (w / cell).ceil(), rows = (h / cell).ceil();
  final perCell = List.generate(cols * rows, (_) => <int>[]);
  for (var y = margin; y < h - margin; y++) {
    for (var x = margin; x < w - margin; x++) {
      final i = y * w + x;
      final s = scores[i];
      if (s == 0) continue;
      // Non-maximum suppression (3×3).
      var isMax = true;
      for (var dy = -1; dy <= 1 && isMax; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if ((dx != 0 || dy != 0) && scores[i + dy * w + dx] > s) {
            isMax = false;
            break;
          }
        }
      }
      if (isMax) perCell[(y ~/ cell) * cols + x ~/ cell].add(i);
    }
  }
  for (final c in perCell) {
    c.sort((a, b) => scores[b].compareTo(scores[a]));
  }
  final picked = <int>[];
  for (var round = 0; picked.length < maxFeatures; round++) {
    var any = false;
    for (final c in perCell) {
      if (round < c.length) {
        picked.add(c[round]);
        any = true;
        if (picked.length >= maxFeatures) break;
      }
    }
    if (!any) break;
  }
  final smooth = image.blur();
  final xs = Float32List(picked.length), ys = Float32List(picked.length);
  final d = Uint32List(picked.length * Features.words);
  for (var k = 0; k < picked.length; k++) {
    final x = picked[k] % w, y = picked[k] ~/ w;
    xs[k] = x.toDouble();
    ys[k] = y.toDouble();
    _describe(
      smooth,
      x,
      y,
      upright ? 0 : _orientation(smooth, x, y),
      d,
      k * Features.words,
    );
  }
  return Features(xs, ys, d);
}

/// Features at several scales, positions in [image]'s pixels: a reference
/// view, so the rock matches from nearer or farther than it was taken.
Features detectPyramid(
  GrayImage image, {
  List<double> scales = const [1.4, 1, 0.75, 0.56, 0.42],
  int maxFeatures = 500,
}) {
  final levels = <Features>[];
  for (final s in scales) {
    final level = s == 1
        ? image
        : image.resize(
            math.max(1, (image.width * s).round()),
            math.max(1, (image.height * s).round()),
          );
    final f = detect(
      level,
      maxFeatures: (maxFeatures * s).round().clamp(100, maxFeatures),
    );
    for (var i = 0; i < f.length; i++) {
      f.xs[i] = f.xs[i] * image.width / level.width;
      f.ys[i] = f.ys[i] * image.height / level.height;
    }
    levels.add(f);
  }
  return Features.join(levels);
}

int _count(Uint16List scores) {
  var n = 0;
  for (final s in scores) {
    if (s > 0) n++;
  }
  return n;
}

// --- FAST ------------------------------------------------------------------

/// The 16 pixels of a radius-3 Bresenham circle, as (dx, dy).
const _circle = [
  (0, -3),
  (1, -3),
  (2, -2),
  (3, -1),
  (3, 0),
  (3, 1),
  (2, 2),
  (1, 3),
  (0, 3),
  (-1, 3),
  (-2, 2),
  (-3, 1),
  (-3, 0),
  (-3, -1),
  (-2, -2),
  (-1, -3),
];

/// FAST-9 corner scores (0: not a corner): a corner has 9 contiguous
/// circle pixels all brighter, or all darker, than it by [t]; its score
/// is how far past [t] they are, summed.
Uint16List _fastScores(GrayImage img, int t, int margin) {
  final w = img.width, h = img.height, data = img.data;
  final offsets = [for (final (dx, dy) in _circle) dy * w + dx];
  final scores = Uint16List(w * h);
  final ring = Int32List(16);
  for (var y = margin; y < h - margin; y++) {
    for (var x = margin; x < w - margin; x++) {
      final i = y * w + x;
      final p = data[i];
      final hi = p + t, lo = p - t;
      // Quick reject: of pixels 0, 4, 8 and 12, at least 3 must pass.
      var bright = 0, dark = 0;
      for (final k in const [0, 4, 8, 12]) {
        final v = data[i + offsets[k]];
        if (v > hi) bright++;
        if (v < lo) dark++;
      }
      if (bright < 3 && dark < 3) continue;
      for (var k = 0; k < 16; k++) {
        final v = data[i + offsets[k]];
        ring[k] = v > hi ? 1 : (v < lo ? -1 : 0);
      }
      var runLen = 0, best = 0, sign = 0;
      for (var k = 0; k < 32; k++) {
        final s = ring[k & 15];
        if (s != 0 && s == sign) {
          runLen++;
        } else {
          sign = s;
          runLen = s == 0 ? 0 : 1;
        }
        if (runLen > best) best = runLen;
      }
      if (best < 9) continue;
      var score = 0;
      for (var k = 0; k < 16; k++) {
        final dv = (data[i + offsets[k]] - p).abs() - t;
        if (dv > 0) score += dv;
      }
      scores[i] = math.min(score, 65535);
    }
  }
  return scores;
}

// --- Orientation and steered BRIEF -------------------------------------------

const _patchRadius = 15;
const _angleBins = 30;

/// The angle from the corner to its patch's intensity centroid (radians).
double _orientation(GrayImage img, int cx, int cy) {
  var m01 = 0, m10 = 0;
  final w = img.width, data = img.data;
  for (var dy = -_patchRadius; dy <= _patchRadius; dy++) {
    final span = _span[dy + _patchRadius];
    final row = (cy + dy) * w + cx;
    for (var dx = -span; dx <= span; dx++) {
      final v = data[row + dx];
      m10 += dx * v;
      m01 += dy * v;
    }
  }
  return math.atan2(m01.toDouble(), m10.toDouble());
}

/// Each row's half-width in the circular patch.
final _span = [
  for (var dy = -_patchRadius; dy <= _patchRadius; dy++)
    math.sqrt(_patchRadius * _patchRadius - dy * dy).floor(),
];

/// 256 point pairs in the patch (fixed: every device must make the same
/// descriptors), Gaussian around the center, and their rotations into
/// [_angleBins] steps.
final List<Int8List> _pattern = () {
  final random = math.Random(0x0b0175);
  double gauss() {
    // Box-Muller.
    final u = math.max(1e-9, random.nextDouble()), v = random.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  int coord() => (gauss() * (_patchRadius * 2 + 1) / 5).round().clamp(-12, 12);
  final base = [for (var i = 0; i < 256 * 4; i++) coord()];
  return [
    for (var b = 0; b < _angleBins; b++)
      () {
        final a = b * 2 * math.pi / _angleBins;
        final c = math.cos(a), s = math.sin(a);
        final out = Int8List(256 * 4);
        for (var i = 0; i < 256 * 2; i++) {
          final x = base[i * 2], y = base[i * 2 + 1];
          out[i * 2] = (c * x - s * y).round().clamp(
            -_patchRadius,
            _patchRadius,
          );
          out[i * 2 + 1] = (s * x + c * y).round().clamp(
            -_patchRadius,
            _patchRadius,
          );
        }
        return out;
      }(),
  ];
}();

void _describe(
  GrayImage img,
  int x,
  int y,
  double angle,
  Uint32List out,
  int offset,
) {
  var bin = (angle / (2 * math.pi) * _angleBins).round() % _angleBins;
  if (bin < 0) bin += _angleBins;
  final p = _pattern[bin];
  final w = img.width, data = img.data;
  final center = y * w + x;
  for (var word = 0; word < Features.words; word++) {
    var bits = 0;
    for (var b = 0; b < 32; b++) {
      final k = (word * 32 + b) * 4;
      final v1 = data[center + p[k + 1] * w + p[k]];
      final v2 = data[center + p[k + 3] * w + p[k + 2]];
      if (v1 < v2) bits |= 1 << b;
    }
    out[offset + word] = bits;
  }
}

/// The number of bits two descriptors differ in.
int hamming(Uint32List a, int ai, Uint32List b, int bi) {
  var d = 0;
  for (var w = 0; w < Features.words; w++) {
    var v = a[ai + w] ^ b[bi + w];
    v = v - ((v >> 1) & 0x55555555);
    v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
    d += (((v + (v >> 4)) & 0x0F0F0F0F) * 0x01010101 & 0xFFFFFFFF) >> 24;
  }
  return d;
}
