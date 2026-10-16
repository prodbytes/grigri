import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../model/climbing.dart';
import '../model/walls.dart';
import '../vision/features.dart';
import '../vision/gray.dart';
import '../vision/homography.dart';
import '../vision/recognizer.dart';
import 'api.dart';
import 'grigri_store.dart';

/// The width reference views are matched at (their features are found on
/// the photo scaled to it).
const viewWidth = 640;

/// The width camera frames are matched at.
const frameWidth = 480;

/// Decodes a photo to gray, [width] pixels wide (dart:ui's decoder, which
/// tests swap).
typedef GrayDecoder = Future<GrayImage> Function(Uint8List bytes, int width);

Future<GrayImage> decodeGray(Uint8List bytes, int width) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final gray = GrayImage.fromRgba(
    rgba!.buffer.asUint8List(),
    image.width,
    image.height,
  );
  image.dispose();
  codec.dispose();
  return gray;
}

/// Its size (decoded, as the app reads it).
Future<(int, int)> photoSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final size = (frame.image.width, frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return size;
}

/// A route where it is in a frame: its bolts, from the ground up, in the
/// frame's pixels.
class RouteInFrame {
  const RouteInFrame(this.route, this.points);

  final ClimbRoute route;
  final List<(double, double)> points;
}

/// What the route finder knows around a place (specs/route-finder.md):
/// the walls near it, each view's features (found once, off the UI
/// thread), and the [Recognizer] that looks for them in camera frames. It
/// places routes in a frame, records new ones, and learns walls from
/// confirmed views.
class RouteFinder extends ChangeNotifier {
  RouteFinder({
    required this.store,
    required this.lat,
    required this.lon,
    this.cragId,
    this.decode = decodeGray,
    this.sizeOf = photoSize,
  });

  final GrigriStore store;
  final double lat;
  final double lon;
  final String? cragId;

  /// Decodes photos to gray (tests swap it).
  final GrayDecoder decode;

  /// A photo's size (tests swap it).
  final Future<(int, int)> Function(Uint8List bytes) sizeOf;

  GrigriApi get api => store.api;

  List<Wall> _walls = [];
  List<Wall> get walls => _walls;

  final _features = <String, ViewFeatures>{};
  Recognizer? _recognizer;

  bool _loading = false;
  bool get loading => _loading;

  /// The views ready to match.
  List<ViewFeatures> get views => [
    for (final w in _walls)
      for (var i = 0; i < w.views.length; i++)
        ?_features['${w.id}/${w.views[i].key}'],
  ];

  Wall? wall(String id) => _walls.where((w) => w.id == id).firstOrNull;

  /// Loads the walls near the place and gets their views ready; the
  /// recognizer starts with [live] (the camera's frames; a still photo
  /// needs none).
  Future<void> load({bool live = true}) async {
    _loading = true;
    notifyListeners();
    try {
      _walls = await api.walls(lat, lon);
      await _prepare();
      if (live) {
        _recognizer ??= await Recognizer.start();
        await _recognizer!.setViews(views);
      }
    } on ApiException catch (e) {
      store.report(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Each view's features, found once per photo.
  Future<void> _prepare() async {
    for (final w in _walls) {
      for (var i = 0; i < w.views.length; i++) {
        final v = w.views[i];
        final id = '${w.id}/${v.key}';
        if (_features.containsKey(id)) continue;
        try {
          final gray = await decode(await api.photoBytes(v.key), viewWidth);
          final packed = await Isolate.run(() => detectPyramid(gray).pack());
          _features[id] = ViewFeatures(
            wallId: w.id,
            view: i,
            width: gray.width.toDouble(),
            height: gray.height.toDouble(),
            features: Features.unpack(packed),
          );
        } on Object catch (e) {
          // One photo that won't load leaves the wall's other views.
          debugPrint('route finder: view ${v.key}: $e');
        }
      }
    }
  }

  /// The wall in a camera frame (already turned upright and scaled to
  /// [frameWidth]), from the isolate.
  Future<Recognition?> recognize(GrayImage frame) async =>
      _recognizer?.recognize(frame);

  /// The wall in a still photo, matched here: for stills (the web, and
  /// recording and teaching on phones).
  Future<(Recognition?, GrayImage)> recognizeStill(Uint8List bytes) async {
    final gray = await decode(bytes, frameWidth);
    final ready = views;
    final r = await Isolate.run(() => recognizeNow(gray, ready));
    return (r, gray);
  }

  /// From the matched view's matching size to its full size.
  Homography _viewScale(Wall wall, int view) {
    final v = wall.views[view];
    final f = _features['${wall.id}/${v.key}'];
    final s = f == null ? 1.0 : f.width / v.width;
    return Homography.fromList([s, 0, 0, 0, s, 0, 0, 0, 1]);
  }

  /// From the wall's first view (full size) to the frame [r] was found in.
  Homography? baseToFrame(Recognition r) {
    final wall = this.wall(r.wallId);
    if (wall == null) return null;
    final v = wall.views[r.view];
    final viewToBase = Homography.fromList(v.h);
    // frame ← view (matched size) ← view (full) ← base
    return viewToBase.inverse().then(_viewScale(wall, r.view)).then(r.toFrame);
  }

  /// The wall's routes where they are in the frame [r] was found in.
  List<RouteInFrame> routesIn(Recognition r) {
    final wall = this.wall(r.wallId);
    final h = baseToFrame(r);
    if (wall == null || h == null) return const [];
    final w = wall.base.width.toDouble(), hh = wall.base.height.toDouble();
    return [
      for (final route in wall.routes)
        RouteInFrame(route, [
          for (final (x, y) in route.bolts) h.apply(x * w, y * hh),
        ]),
    ];
  }

  /// Uploads a photo as a wall photo: its key and size.
  Future<(String, int, int)> _upload(Uint8List bytes) async {
    final type = photoContentType(bytes);
    if (type == null) {
      throw const ApiException(
        400,
        'Use a JPEG, PNG or WebP photo.',
        client: ClientError.photoType,
      );
    }
    final (width, height) = await sizeOf(bytes);
    final upload = await api.newWallPhoto(type);
    await api.uploadPhoto(upload, bytes);
    return (upload.key, width, height);
  }

  void _replace(Wall wall) {
    _walls = [for (final w in _walls) w.id == wall.id ? wall : w];
    if (!_walls.any((w) => w.id == wall.id)) _walls = [..._walls, wall];
    notifyListeners();
  }

  Future<void> _refreshViews() async {
    await _prepare();
    await _recognizer?.setViews(views);
    notifyListeners();
  }

  /// Saves a route drawn on a still photo: [bolts] are 0..1 of the still,
  /// [seen] where the still found a wall (in its [stillWidth]-wide matching
  /// copy). Unknown rock becomes a new wall named [wallName], the still its
  /// first view. → the wall, or null when it failed (reported).
  Future<Wall?> saveRoute({
    required Uint8List still,
    required int stillWidth,
    required int stillHeight,
    required Recognition? seen,
    required List<(double, double)> bolts,
    required String name,
    required GradeScale scale,
    required int grade,
    String? wallName,
  }) async {
    try {
      Wall? wall = seen == null ? null : this.wall(seen.wallId);
      List<(double, double)> onBase;
      if (wall != null && seen != null) {
        // still (0..1) → still (matched size) → base (full) → base (0..1)
        final toFrame = baseToFrame(seen)!;
        final back = toFrame.inverse();
        onBase = [
          for (final (x, y) in bolts)
            () {
              final (bx, by) = back.apply(x * stillWidth, y * stillHeight);
              return (
                (bx / wall!.base.width).clamp(0.0, 1.0),
                (by / wall.base.height).clamp(0.0, 1.0),
              );
            }(),
        ];
      } else {
        final (key, width, height) = await _upload(still);
        wall = await api.createWall(
          name: wallName ?? name,
          lat: lat,
          lon: lon,
          cragId: cragId,
          key: key,
          width: width,
          height: height,
        );
        onBase = bolts;
      }
      final saved = await api.addRoute(
        wall.id,
        name: name,
        scale: scale,
        grade: grade,
        bolts: onBase,
      );
      _replace(saved);
      await _refreshViews();
      return saved;
    } on ApiException catch (e) {
      store.report(e);
      return null;
    }
  }

  /// Teaches the wall a new view: [still] (its matching copy
  /// [stillWidth] wide), where [seen] found the wall. True when saved.
  Future<bool> learn(Uint8List still, int stillWidth, Recognition seen) async {
    final wall = this.wall(seen.wallId);
    final toFrame = baseToFrame(seen);
    if (wall == null || toFrame == null) return false;
    try {
      final (key, width, height) = await _upload(still);
      // The still at full size → base (full).
      final s = stillWidth / width;
      final fullToMatched = Homography.fromList([s, 0, 0, 0, s, 0, 0, 0, 1]);
      final h = fullToMatched.then(toFrame.inverse());
      final saved = await api.addWallView(
        wall.id,
        key: key,
        width: width,
        height: height,
        h: h.toList(),
      );
      _replace(saved);
      await _refreshViews();
      return true;
    } on ApiException catch (e) {
      store.report(e);
      return false;
    }
  }

  /// Deletes a route (whoever drew it, or an admin).
  Future<bool> deleteRoute(Wall wall, ClimbRoute route) async {
    try {
      _replace(await api.deleteRoute(wall.id, route.id));
      return true;
    } on ApiException catch (e) {
      store.report(e);
      return false;
    }
  }

  @override
  void dispose() {
    _recognizer?.close();
    super.dispose();
  }
}
