import 'dart:math' as math;
import 'dart:typed_data';

/// An 8-bit grayscale image, row by row: what the route finder sees
/// (specs/route-finder.md).
class GrayImage {
  GrayImage(this.width, this.height, [Uint8List? data])
    : data = data ?? Uint8List(width * height) {
    assert(this.data.length == width * height);
  }

  final int width;
  final int height;
  final Uint8List data;

  int at(int x, int y) => data[y * width + x];

  /// From RGBA bytes (dart:ui's rawRgba), by luma.
  factory GrayImage.fromRgba(Uint8List rgba, int width, int height) {
    final out = Uint8List(width * height);
    for (var i = 0, j = 0; i < out.length; i++, j += 4) {
      out[i] = (rgba[j] * 77 + rgba[j + 1] * 150 + rgba[j + 2] * 29) >> 8;
    }
    return GrayImage(width, height, out);
  }

  /// From BGRA bytes (iOS camera frames), rows [bytesPerRow] apart.
  factory GrayImage.fromBgra(
    Uint8List bgra,
    int width,
    int height,
    int bytesPerRow,
  ) {
    final out = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      final row = y * bytesPerRow;
      for (var x = 0; x < width; x++) {
        final j = row + x * 4;
        out[y * width + x] =
            (bgra[j + 2] * 77 + bgra[j + 1] * 150 + bgra[j] * 29) >> 8;
      }
    }
    return GrayImage(width, height, out);
  }

  /// From a luma plane (Android's YUV frames: the Y plane is the gray
  /// image), rows [bytesPerRow] apart.
  factory GrayImage.fromLuma(
    Uint8List plane,
    int width,
    int height,
    int bytesPerRow,
  ) {
    if (bytesPerRow == width) {
      return GrayImage(
        width,
        height,
        Uint8List.fromList(plane.sublist(0, width * height)),
      );
    }
    final out = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      out.setRange(y * width, (y + 1) * width, plane, y * bytesPerRow);
    }
    return GrayImage(width, height, out);
  }

  /// Scaled so its width is [targetWidth] (box-averaged when shrinking,
  /// so detail doesn't alias).
  GrayImage resizeToWidth(int targetWidth) {
    if (targetWidth == width) return this;
    final targetHeight = math.max(1, (height * targetWidth / width).round());
    return resize(targetWidth, targetHeight);
  }

  GrayImage resize(int w, int h) {
    final out = Uint8List(w * h);
    final sx = width / w;
    final sy = height / h;
    if (sx <= 1 && sy <= 1) {
      // Growing: bilinear.
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          out[y * w + x] = sample((x + 0.5) * sx - 0.5, (y + 0.5) * sy - 0.5);
        }
      }
      return GrayImage(w, h, out);
    }
    for (var y = 0; y < h; y++) {
      final y0 = (y * sy).floor();
      final y1 = math.min(height, math.max(y0 + 1, ((y + 1) * sy).floor()));
      for (var x = 0; x < w; x++) {
        final x0 = (x * sx).floor();
        final x1 = math.min(width, math.max(x0 + 1, ((x + 1) * sx).floor()));
        var sum = 0;
        for (var yy = y0; yy < y1; yy++) {
          final row = yy * width;
          for (var xx = x0; xx < x1; xx++) {
            sum += data[row + xx];
          }
        }
        out[y * w + x] = sum ~/ ((y1 - y0) * (x1 - x0));
      }
    }
    return GrayImage(w, h, out);
  }

  /// Turned clockwise by [quarterTurns] × 90°.
  GrayImage rotate(int quarterTurns) {
    final q = quarterTurns % 4;
    if (q == 0) return this;
    final w = q.isOdd ? height : width;
    final h = q.isOdd ? width : height;
    final out = Uint8List(w * h);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final v = data[y * width + x];
        final (nx, ny) = switch (q) {
          1 => (height - 1 - y, x),
          2 => (width - 1 - x, height - 1 - y),
          _ => (y, width - 1 - x),
        };
        out[ny * w + nx] = v;
      }
    }
    return GrayImage(w, h, out);
  }

  /// Bilinear sample at (x, y), clamped to the edges.
  int sample(double x, double y) {
    final cx = x.clamp(0.0, width - 1.0);
    final cy = y.clamp(0.0, height - 1.0);
    final x0 = cx.floor();
    final y0 = cy.floor();
    final x1 = math.min(x0 + 1, width - 1);
    final y1 = math.min(y0 + 1, height - 1);
    final fx = cx - x0;
    final fy = cy - y0;
    final top = data[y0 * width + x0] * (1 - fx) + data[y0 * width + x1] * fx;
    final bottom =
        data[y1 * width + x0] * (1 - fx) + data[y1 * width + x1] * fx;
    return (top * (1 - fy) + bottom * fy).round();
  }

  /// A 5×5 box blur (two passes of a 5-wide running sum): what the
  /// descriptors compare, so single-pixel noise doesn't flip their bits.
  GrayImage blur() {
    final tmp = Uint16List(width * height);
    for (var y = 0; y < height; y++) {
      final row = y * width;
      var sum = 0;
      for (var x = -2; x < width + 2; x++) {
        sum += data[row + x.clamp(0, width - 1)];
        if (x - 5 >= -2) sum -= data[row + (x - 5).clamp(0, width - 1)];
        if (x - 2 >= 0) tmp[row + x - 2] = sum;
      }
    }
    final out = Uint8List(width * height);
    for (var x = 0; x < width; x++) {
      var sum = 0;
      for (var y = -2; y < height + 2; y++) {
        sum += tmp[y.clamp(0, height - 1) * width + x];
        if (y - 5 >= -2) sum -= tmp[(y - 5).clamp(0, height - 1) * width + x];
        if (y - 2 >= 0) out[(y - 2) * width + x] = sum ~/ 25;
      }
    }
    return GrayImage(width, height, out);
  }
}
