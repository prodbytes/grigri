import 'dart:math' as math;
import 'dart:typed_data';

/// A 3×3 projective transform between two views of a (roughly flat) rock
/// face, row-major, normalized so its last entry is 1.
class Homography {
  Homography(this.m) : assert(m.length == 9);

  Homography.identity() : m = Float64List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  factory Homography.fromList(List<num> values) =>
      Homography(Float64List.fromList([for (final v in values) v.toDouble()]))
          .normalized();

  final Float64List m;

  List<double> toList() => [for (final v in m) v];

  (double, double) apply(double x, double y) {
    final w = m[6] * x + m[7] * y + m[8];
    return ((m[0] * x + m[1] * y + m[2]) / w, (m[3] * x + m[4] * y + m[5]) / w);
  }

  /// This, then [other].
  Homography then(Homography other) => other.times(this);

  Homography times(Homography o) {
    final a = m;
    final b = o.m;
    final r = Float64List(9);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        r[i * 3 + j] =
            a[i * 3] * b[j] + a[i * 3 + 1] * b[3 + j] + a[i * 3 + 2] * b[6 + j];
      }
    }
    return Homography(r).normalized();
  }

  Homography inverse() {
    final a = m;
    final c00 = a[4] * a[8] - a[5] * a[7];
    final c01 = a[5] * a[6] - a[3] * a[8];
    final c02 = a[3] * a[7] - a[4] * a[6];
    final det = a[0] * c00 + a[1] * c01 + a[2] * c02;
    final r = Float64List.fromList([
      c00 / det,
      (a[2] * a[7] - a[1] * a[8]) / det,
      (a[1] * a[5] - a[2] * a[4]) / det,
      c01 / det,
      (a[0] * a[8] - a[2] * a[6]) / det,
      (a[2] * a[3] - a[0] * a[5]) / det,
      c02 / det,
      (a[1] * a[6] - a[0] * a[7]) / det,
      (a[0] * a[4] - a[1] * a[3]) / det,
    ]);
    return Homography(r).normalized();
  }

  Homography normalized() {
    final s = m[8];
    if (s == 0 || s == 1) return this;
    return Homography(Float64List.fromList([for (final v in m) v / s]));
  }

  bool get isFinite => m.every((v) => v.isFinite);

  /// Whether it maps a [width]×[height] view to a plausible one: its
  /// corners stay a convex quadrilateral in the same orientation, not
  /// shrunk or blown up beyond [maxScale] (by area).
  bool isPlausible(double width, double height, {double maxScale = 25}) {
    if (!isFinite) return false;
    final corners = [
      apply(0, 0),
      apply(width, 0),
      apply(width, height),
      apply(0, height),
    ];
    var sign = 0;
    for (var i = 0; i < 4; i++) {
      final (ax, ay) = corners[i];
      final (bx, by) = corners[(i + 1) % 4];
      final (cx, cy) = corners[(i + 2) % 4];
      final cross = (bx - ax) * (cy - by) - (by - ay) * (cx - bx);
      if (!cross.isFinite || cross == 0) return false;
      final s = cross > 0 ? 1 : -1;
      if (sign == 0) sign = s;
      if (s != sign) return false;
    }
    if (sign < 0) return false;
    var area = 0.0;
    for (var i = 0; i < 4; i++) {
      final (ax, ay) = corners[i];
      final (bx, by) = corners[(i + 1) % 4];
      area += ax * by - bx * ay;
    }
    final ratio = (area / 2).abs() / (width * height);
    return ratio > 1 / maxScale && ratio < maxScale;
  }

  /// The least-squares transform taking each [from] point to its [to]
  /// point (at least 4 pairs, as x, y, x, y, ...), with Hartley's
  /// normalization; null when they're degenerate (e.g. collinear).
  static Homography? fit(List<double> from, List<double> to) {
    final n = from.length ~/ 2;
    if (n < 4) return null;
    final (tf, nf) = _normalize(from);
    final (tt, nt) = _normalize(to);
    // h33 = 1: 8 unknowns; the normal equations of the 2n rows.
    final ata = Float64List(64);
    final atb = Float64List(8);
    final row = Float64List(8);
    for (var i = 0; i < n; i++) {
      final x = nf[i * 2], y = nf[i * 2 + 1];
      final u = nt[i * 2], v = nt[i * 2 + 1];
      for (final (r, rhs) in [
        ([x, y, 1.0, 0.0, 0.0, 0.0, -u * x, -u * y], u),
        ([0.0, 0.0, 0.0, x, y, 1.0, -v * x, -v * y], v),
      ]) {
        for (var k = 0; k < 8; k++) {
          row[k] = r[k];
        }
        for (var a = 0; a < 8; a++) {
          atb[a] += row[a] * rhs;
          for (var b = 0; b < 8; b++) {
            ata[a * 8 + b] += row[a] * row[b];
          }
        }
      }
    }
    final h = _solve(ata, atb, 8);
    if (h == null) return null;
    final hn = Homography(Float64List.fromList([...h, 1]));
    // Undo the normalizations: H = Tt⁻¹ · Hn · Tf.
    final result = tf.then(hn).then(tt.inverse());
    return result.isFinite ? result : null;
  }

  /// Moves points' centroid to the origin and their mean distance to √2.
  static (Homography, Float64List) _normalize(List<double> pts) {
    final n = pts.length ~/ 2;
    var cx = 0.0, cy = 0.0;
    for (var i = 0; i < n; i++) {
      cx += pts[i * 2];
      cy += pts[i * 2 + 1];
    }
    cx /= n;
    cy /= n;
    var d = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = pts[i * 2] - cx, dy = pts[i * 2 + 1] - cy;
      d += math.sqrt(dx * dx + dy * dy);
    }
    d /= n;
    final s = d == 0 ? 1.0 : math.sqrt2 / d;
    final out = Float64List(pts.length);
    for (var i = 0; i < n; i++) {
      out[i * 2] = (pts[i * 2] - cx) * s;
      out[i * 2 + 1] = (pts[i * 2 + 1] - cy) * s;
    }
    final t = Homography(
      Float64List.fromList([s, 0, -cx * s, 0, s, -cy * s, 0, 0, 1]),
    );
    return (t, out);
  }

  /// Gaussian elimination with partial pivoting; null when singular.
  static Float64List? _solve(Float64List a, Float64List b, int n) {
    final m = Float64List.fromList(a);
    final r = Float64List.fromList(b);
    for (var c = 0; c < n; c++) {
      var p = c;
      for (var i = c + 1; i < n; i++) {
        if (m[i * n + c].abs() > m[p * n + c].abs()) p = i;
      }
      if (m[p * n + c].abs() < 1e-12) return null;
      if (p != c) {
        for (var k = 0; k < n; k++) {
          final t = m[c * n + k];
          m[c * n + k] = m[p * n + k];
          m[p * n + k] = t;
        }
        final t = r[c];
        r[c] = r[p];
        r[p] = t;
      }
      for (var i = c + 1; i < n; i++) {
        final f = m[i * n + c] / m[c * n + c];
        if (f == 0) continue;
        for (var k = c; k < n; k++) {
          m[i * n + k] -= f * m[c * n + k];
        }
        r[i] -= f * r[c];
      }
    }
    final x = Float64List(n);
    for (var i = n - 1; i >= 0; i--) {
      var s = r[i];
      for (var k = i + 1; k < n; k++) {
        s -= m[i * n + k] * x[k];
      }
      x[i] = s / m[i * n + i];
    }
    return x;
  }

  /// RANSAC: the transform most point pairs agree with (within
  /// [threshold] pixels in the [to] view), refitted on those inliers.
  /// Null when fewer than [minInliers] agree.
  static ({Homography homography, int inliers})? ransac(
    List<double> from,
    List<double> to, {
    double threshold = 4,
    int iterations = 400,
    int minInliers = 12,
    int seed = 7,
  }) {
    final n = from.length ~/ 2;
    if (n < minInliers || n < 4) return null;
    final random = math.Random(seed);
    final t2 = threshold * threshold;
    var bestCount = 0;
    Uint8List? best;
    final sampleFrom = List<double>.filled(8, 0);
    final sampleTo = List<double>.filled(8, 0);
    final picked = <int>[];
    for (var it = 0; it < iterations; it++) {
      picked.clear();
      while (picked.length < 4) {
        final i = random.nextInt(n);
        if (!picked.contains(i)) picked.add(i);
      }
      for (var k = 0; k < 4; k++) {
        sampleFrom[k * 2] = from[picked[k] * 2];
        sampleFrom[k * 2 + 1] = from[picked[k] * 2 + 1];
        sampleTo[k * 2] = to[picked[k] * 2];
        sampleTo[k * 2 + 1] = to[picked[k] * 2 + 1];
      }
      final h = fit(sampleFrom, sampleTo);
      if (h == null) continue;
      final mask = Uint8List(n);
      var count = 0;
      for (var i = 0; i < n; i++) {
        final (px, py) = h.apply(from[i * 2], from[i * 2 + 1]);
        final dx = px - to[i * 2], dy = py - to[i * 2 + 1];
        if (dx * dx + dy * dy < t2) {
          mask[i] = 1;
          count++;
        }
      }
      if (count > bestCount) {
        bestCount = count;
        best = mask;
        // Enough agreement: stop early.
        if (count > n * 0.8) break;
      }
    }
    if (best == null || bestCount < minInliers) return null;
    final inFrom = <double>[], inTo = <double>[];
    for (var i = 0; i < n; i++) {
      if (best[i] == 0) continue;
      inFrom.addAll([from[i * 2], from[i * 2 + 1]]);
      inTo.addAll([to[i * 2], to[i * 2 + 1]]);
    }
    final refit = fit(inFrom, inTo);
    if (refit == null) return null;
    return (homography: refit, inliers: bestCount);
  }
}
