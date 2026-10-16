import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/route_finder.dart';
import 'package:grigri_app/model/climbing.dart';
import 'package:grigri_app/vision/gray.dart';
import 'package:grigri_app/vision/homography.dart';

import 'support/fakes.dart';
import 'vision_test.dart' as v;

/// Made-up photos: bytes that pass for JPEG, each standing for a gray
/// image the fake decoder gives back at the width asked.
class Photos {
  final _images = <String, GrayImage>{};
  var _n = 0;

  Uint8List add(GrayImage image) {
    final bytes = Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      ...'photo-${_n++}'.codeUnits,
    ]);
    _images[String.fromCharCodes(bytes)] = image;
    return bytes;
  }

  GrayImage _of(Uint8List bytes) => _images[String.fromCharCodes(bytes)]!;

  Future<GrayImage> decode(Uint8List bytes, int width) async =>
      _of(bytes).resizeToWidth(width);

  Future<(int, int)> size(Uint8List bytes) async {
    final g = _of(bytes);
    return (g.width, g.height);
  }
}

void main() {
  test('records a route on new rock, finds it from another angle, adds one '
      'there, and learns that view', () async {
    final api = sampleApi()..premium = true;
    final store = storeFor(api);
    await store.start();
    expect(store.premium, isTrue);
    final photos = Photos();
    RouteFinder finder() => RouteFinder(
      store: store,
      lat: 41.2577,
      lon: 0.9318,
      cragId: 'osm:n1',
      decode: photos.decode,
      sizeOf: photos.size,
    );

    // The wall, photographed straight on (1280×960).
    final wallImage = v.rock(640, 480).resize(1280, 960);
    final base = photos.add(wallImage);

    // Nothing known here: the still's rock is new; the route makes the wall.
    final first = finder();
    await first.load(live: false);
    expect(first.walls, isEmpty);
    final (none, small) = await first.recognizeStill(base);
    expect(none, isNull);
    final line = [(0.40, 0.90), (0.42, 0.65), (0.45, 0.40), (0.47, 0.20)];
    final wall = await first.saveRoute(
      still: base,
      stillWidth: small.width,
      stillHeight: small.height,
      seen: null,
      bolts: line,
      name: 'Made-up Line',
      scale: GradeScale.routes,
      grade: 12,
      wallName: 'Made-up Wall',
    );
    expect(wall, isNotNull);
    expect(api.allWalls.single.name, 'Made-up Wall');
    expect(api.allWalls.single.cragId, 'osm:n1');
    expect(api.allWalls.single.base.width, 1280);
    expect(api.allWalls.single.routes.single.bolts, line);

    // Later, from another angle, nearer, in other light (960×720).
    final a = 6 * math.pi / 180;
    final truth = Homography.fromList([
      0.9 * math.cos(a),
      -0.9 * math.sin(a),
      -120,
      0.9 * math.sin(a),
      0.9 * math.cos(a),
      -60,
      0.00004,
      0.00002,
      1,
    ]);
    final angle = photos.add(v.view(wallImage, truth, 960, 720));
    final second = finder();
    await second.load(live: false);
    expect(second.views, hasLength(1));
    final (seen, still) = await second.recognizeStill(angle);
    expect(seen, isNotNull);
    expect(seen!.wallId, wall!.id);

    // The route's bolts are where they are in this photo (its 480-wide copy).
    final routes = second.routesIn(seen);
    expect(routes.single.route.name, 'Made-up Line');
    final k = still.width / 960;
    for (var i = 0; i < line.length; i++) {
      final (ex, ey) = truth.apply(line[i].$1 * 1280, line[i].$2 * 960);
      expect(routes.single.points[i].$1, closeTo(ex * k, 3));
      expect(routes.single.points[i].$2, closeTo(ey * k, 3));
    }

    // A second route drawn on this photo lands on the wall's first view.
    final other = [(0.60, 0.88), (0.62, 0.50), (0.63, 0.25)];
    final tapped = [
      for (final (x, y) in other)
        () {
          final (sx, sy) = truth.apply(x * 1280, y * 960);
          return (sx / 960, sy / 720);
        }(),
    ];
    final saved = await second.saveRoute(
      still: angle,
      stillWidth: still.width,
      stillHeight: still.height,
      seen: seen,
      bolts: tapped,
      name: 'Another Line',
      scale: GradeScale.boulders,
      grade: 3,
    );
    expect(saved!.routes, hasLength(2));
    final stored = api.allWalls.single.routes.last;
    expect(stored.scale, GradeScale.boulders);
    for (var i = 0; i < other.length; i++) {
      expect(stored.bolts[i].$1, closeTo(other[i].$1, 0.005));
      expect(stored.bolts[i].$2, closeTo(other[i].$2, 0.005));
    }
    expect(api.calls.where((c) => c == 'POST /api/walls'), hasLength(1));

    // Learning this view: its transform takes it back to the first view.
    expect(await second.learn(angle, still.width, seen), isTrue);
    final learned = api.allWalls.single.views.last;
    expect((learned.width, learned.height), (960, 720));
    final h = Homography.fromList(learned.h);
    final (sx, sy) = truth.apply(500, 400);
    final (bx, by) = h.apply(sx, sy);
    expect(bx, closeTo(500, 3));
    expect(by, closeTo(400, 3));
    // The finder now matches with both views.
    expect(second.views, hasLength(2));
  });

  test('not premium: the walls are refused', () async {
    final api = sampleApi();
    final store = storeFor(api);
    await store.start();
    expect(store.premium, isFalse);
    final errors = <String>[];
    final sub = store.errors.listen(errors.add);
    addTearDown(sub.cancel);
    final f = RouteFinder(
      store: store,
      lat: 41,
      lon: 1,
      decode: Photos().decode,
    );
    await f.load(live: false);
    await Future<void>.delayed(Duration.zero);
    expect(f.walls, isEmpty);
    expect(errors, ['premium only']);
  });
}
