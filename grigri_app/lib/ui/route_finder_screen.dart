import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/route_finder.dart';
import '../model/climbing.dart';
import '../theme.dart';
import '../vision/gray.dart';
import '../vision/recognizer.dart';
import 'common.dart';

/// The route finder (specs/route-finder.md), premium: the camera on the
/// rock, with each route Grigri knows there drawn over it bolt by bolt and
/// labeled with its grade. Climbers record new routes and teach Grigri
/// the wall from where they stand.
class RouteFinderScreen extends StatefulWidget {
  const RouteFinderScreen({
    super.key,
    required this.lat,
    required this.lon,
    required this.place,
    this.cragId,
  });

  final double lat;
  final double lon;

  /// The plan's place, the name a new wall gets by default.
  final String place;
  final String? cragId;

  @override
  State<RouteFinderScreen> createState() => _RouteFinderScreenState();
}

class _RouteFinderScreenState extends State<RouteFinderScreen> {
  late final RouteFinder _finder;
  CameraController? _camera;
  String? _cameraError;
  bool _busy = false;
  bool _streaming = false;

  /// The latest wall seen, the frame it was seen in, and when.
  Recognition? _seen;
  (int, int)? _frameSize;
  DateTime _seenAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// A wall stays drawn this long after the last frame that found it.
  static const _hold = Duration(milliseconds: 700);

  /// Live frames on phones; the web takes stills.
  bool get _live => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _finder = RouteFinder(
      store: StoreScope.read(context),
      lat: widget.lat,
      lon: widget.lon,
      cragId: widget.cragId,
    )..addListener(_changed);
    unawaited(_start());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    unawaited(_finder.load(live: _live));
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
      await _stream(true);
    } on Object catch (e) {
      if (mounted) setState(() => _cameraError = '$e');
    }
  }

  Future<void> _stream(bool on) async {
    final camera = _camera;
    if (!_live || camera == null || on == _streaming) return;
    _streaming = on;
    if (on) {
      await camera.startImageStream(_onFrame);
    } else {
      await camera.stopImageStream();
    }
  }

  /// One frame at a time: gray, upright, [frameWidth] wide, then matched
  /// off the UI thread; frames that come meanwhile are skipped.
  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _finder.views.isEmpty) return;
    _busy = true;
    try {
      final plane = image.planes.first;
      final raw = image.format.group == ImageFormatGroup.bgra8888
          ? GrayImage.fromBgra(
              plane.bytes,
              image.width,
              image.height,
              plane.bytesPerRow,
            )
          : GrayImage.fromLuma(
              plane.bytes,
              image.width,
              image.height,
              plane.bytesPerRow,
            );
      final turns = (_camera!.description.sensorOrientation ~/ 90) % 4;
      final frame = raw.rotate(turns).resizeToWidth(frameWidth);
      final seen = await _finder.recognize(frame);
      if (!mounted) return;
      setState(() {
        _frameSize = (frame.width, frame.height);
        if (seen != null) {
          _seen = seen;
          _seenAt = DateTime.now();
        } else if (DateTime.now().difference(_seenAt) > _hold) {
          _seen = null;
        }
      });
    } finally {
      _busy = false;
    }
  }

  /// A still from the camera, the stream paused meanwhile.
  Future<Uint8List?> _still() async {
    final camera = _camera;
    if (camera == null) return null;
    await _stream(false);
    try {
      return await (await camera.takePicture()).readAsBytes();
    } on Object catch (e) {
      debugPrint('route finder: still: $e');
      return null;
    }
  }

  /// The still screen: the photo with its routes, to draw a new one or
  /// teach Grigri the view.
  Future<void> _openStill({bool draw = false}) async {
    final bytes = await _still();
    if (bytes != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RouteStillScreen(
            finder: _finder,
            photo: bytes,
            place: widget.place,
            startDrawing: draw,
          ),
        ),
      );
    }
    await _stream(true);
  }

  @override
  void dispose() {
    _finder
      ..removeListener(_changed)
      ..dispose();
    final camera = _camera;
    if (camera != null) {
      if (_streaming) unawaited(camera.stopImageStream());
      unawaited(camera.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = StoreScope.of(context);
    final camera = _camera;
    final seen = _seen;
    final wall = seen == null ? null : _finder.wall(seen.wallId);
    final status = _finder.loading
        ? l.routeFinderLoading
        : _finder.walls.isEmpty
        ? l.routeFinderNoWalls
        : wall != null
        ? l.routeFinderSeen(wall.name, wall.routes.length)
        : _live
        ? l.routeFinderPoint
        : l.routeFinderSnap;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(l.routeFinder)),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _cameraError != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l.cameraUnavailable,
                        style: const TextStyle(color: Mountain.snow),
                      ),
                    )
                  : camera == null || !camera.value.isInitialized
                  ? const CircularProgressIndicator()
                  : AspectRatio(
                      // The preview is turned upright: portrait.
                      aspectRatio: 1 / camera.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(camera),
                          if (seen != null && _frameSize != null)
                            CustomPaint(
                              key: const ValueKey('route overlay'),
                              painter: RoutesPainter(
                                routes: _finder.routesIn(seen),
                                frame: _frameSize!,
                                system: store.gradeSystem,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Mountain.snow),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.timeline),
                          label: Text(l.recordRoute),
                          onPressed: camera == null
                              ? null
                              : () => _openStill(draw: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: Icon(
                            _live ? Icons.school_outlined : Icons.camera_alt,
                          ),
                          label: Text(_live ? l.teachView : l.findRoutes),
                          // Phones: teach the view in sight; the web: a
                          // still to find routes on.
                          onPressed: camera == null || (_live && wall == null)
                              ? null
                              : () => _openStill(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The routes over the rock: a line through each route's bolts (a dot per
/// bolt, a ring at the anchor) and a label at the top with its grade and
/// name.
class RoutesPainter extends CustomPainter {
  RoutesPainter({
    required this.routes,
    required this.frame,
    required this.system,
    this.drawing = const [],
  });

  final List<RouteInFrame> routes;

  /// The size of the frame the points are in.
  final (int, int) frame;
  final GradeSystem system;

  /// A route being drawn (frame pixels), dashed in white.
  final List<(double, double)> drawing;

  static const colors = [
    Color(0xFFFF8A3D),
    Color(0xFF5BC0EB),
    Color(0xFFB5E35D),
    Color(0xFFF25F9B),
    Color(0xFFFFD23F),
    Color(0xFFB892FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / frame.$1, sy = size.height / frame.$2;
    Offset at((double, double) p) => Offset(p.$1 * sx, p.$2 * sy);
    for (var i = 0; i < routes.length; i++) {
      final r = routes[i];
      if (r.points.length < 2) continue;
      final color = colors[i % colors.length];
      final points = [for (final p in r.points) at(p)];
      _line(canvas, points, color);
      final label = '${r.route.gradeLabel(system)}  ${r.route.name}';
      _label(canvas, points.last, label, color);
    }
    if (drawing.isNotEmpty) {
      _line(canvas, [for (final p in drawing) at(p)], Colors.white);
    }
  }

  void _line(Canvas canvas, List<Offset> points, Color color) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
      );
    for (var k = 0; k < points.length; k++) {
      final anchor = k == points.length - 1 && points.length > 1;
      canvas
        ..drawCircle(points[k], anchor ? 8 : 5, Paint()..color = Colors.black)
        ..drawCircle(
          points[k],
          anchor ? 6 : 3.5,
          anchor
              ? (Paint()
                  ..color = color
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3)
              : (Paint()..color = color),
        );
    }
  }

  void _label(Canvas canvas, Offset top, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 180);
    final box = Rect.fromLTWH(
      top.dx - painter.width / 2 - 6,
      top.dy - painter.height - 16,
      painter.width + 12,
      painter.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      Paint()..color = color,
    );
    painter.paint(canvas, Offset(box.left + 6, box.top + 3));
  }

  @override
  bool shouldRepaint(RoutesPainter old) =>
      old.routes != routes || old.frame != frame || old.drawing != drawing;
}

/// A still of the rock: the routes Grigri found on it; drawing a new
/// route bolt by bolt (its name and grade, then saved); and, when the wall
/// was found, teaching Grigri this view.
class RouteStillScreen extends StatefulWidget {
  const RouteStillScreen({
    super.key,
    required this.finder,
    required this.photo,
    required this.place,
    this.startDrawing = false,
  });

  final RouteFinder finder;
  final Uint8List photo;
  final String place;
  final bool startDrawing;

  @override
  State<RouteStillScreen> createState() => _RouteStillScreenState();
}

class _RouteStillScreenState extends State<RouteStillScreen> {
  Recognition? _seen;
  (int, int)? _size;
  bool _looking = true;
  late bool _drawing = widget.startDrawing;
  bool _saving = false;

  /// The bolts tapped so far, in the matching copy's pixels.
  final _bolts = <(double, double)>[];

  @override
  void initState() {
    super.initState();
    unawaited(_look());
  }

  Future<void> _look() async {
    final (seen, gray) = await widget.finder.recognizeStill(widget.photo);
    if (!mounted) return;
    setState(() {
      _seen = seen;
      _size = (gray.width, gray.height);
      _looking = false;
    });
  }

  Future<void> _teach() async {
    final seen = _seen, size = _size;
    if (seen == null || size == null) return;
    setState(() => _saving = true);
    final ok = await widget.finder.learn(widget.photo, size.$1, seen);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.learnedView)));
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    final l = context.l10n;
    final size = _size;
    if (size == null) return;
    if (_bolts.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.needTwoBolts)));
      return;
    }
    final details = await showDialog<_RouteDetails>(
      context: context,
      builder: (_) =>
          _RouteDetailsDialog(newWall: _seen == null, place: widget.place),
    );
    if (details == null || !mounted) return;
    setState(() => _saving = true);
    final wall = await widget.finder.saveRoute(
      still: widget.photo,
      stillWidth: size.$1,
      stillHeight: size.$2,
      seen: _seen,
      bolts: [for (final (x, y) in _bolts) (x / size.$1, y / size.$2)],
      name: details.name,
      scale: details.scale,
      grade: details.grade,
      wallName: details.wallName,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (wall != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.routeSaved)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = StoreScope.of(context);
    final seen = _seen, size = _size;
    final wall = seen == null ? null : widget.finder.wall(seen.wallId);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(wall?.name ?? l.routeFinder),
        actions: [
          if (_drawing && _bolts.isNotEmpty)
            IconButton(
              tooltip: l.undoBolt,
              icon: const Icon(Icons.undo),
              onPressed: () => setState(_bolts.removeLast),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: size == null
                  ? const CircularProgressIndicator()
                  : AspectRatio(
                      aspectRatio: size.$1 / size.$2,
                      child: LayoutBuilder(
                        builder: (context, box) => GestureDetector(
                          key: const ValueKey('still'),
                          onTapUp: !_drawing
                              ? null
                              : (d) => setState(
                                  () => _bolts.add((
                                    d.localPosition.dx / box.maxWidth * size.$1,
                                    d.localPosition.dy /
                                        box.maxHeight *
                                        size.$2,
                                  )),
                                ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(widget.photo, fit: BoxFit.fill),
                              CustomPaint(
                                painter: RoutesPainter(
                                  routes: seen == null
                                      ? const []
                                      : widget.finder.routesIn(seen),
                                  frame: size,
                                  system: store.gradeSystem,
                                  drawing: List.of(_bolts),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _looking
                        ? l.routeFinderLoading
                        : _drawing
                        ? (wall == null ? l.tapBoltsNewWall : l.tapBolts)
                        : wall == null
                        ? l.notRecognized
                        : l.routeFinderSeen(wall.name, wall.routes.length),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Mountain.snow),
                  ),
                  const SizedBox(height: 8),
                  if (_saving)
                    const Center(child: CircularProgressIndicator())
                  else if (_drawing)
                    FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(l.saveRoute),
                      onPressed: _looking ? null : _save,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.timeline),
                            label: Text(l.recordRoute),
                            onPressed: _looking
                                ? null
                                : () => setState(() => _drawing = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.school_outlined),
                            label: Text(l.teachView),
                            onPressed: wall == null ? null : _teach,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteDetails {
  const _RouteDetails(this.name, this.scale, this.grade, this.wallName);

  final String name;
  final GradeScale scale;
  final int grade;
  final String? wallName;
}

/// A new route's name and grade (and, on new rock, the wall's name).
class _RouteDetailsDialog extends StatefulWidget {
  const _RouteDetailsDialog({required this.newWall, required this.place});

  final bool newWall;
  final String place;

  @override
  State<_RouteDetailsDialog> createState() => _RouteDetailsDialogState();
}

class _RouteDetailsDialogState extends State<_RouteDetailsDialog> {
  final _name = TextEditingController();
  late final _wall = TextEditingController(text: widget.place);
  GradeScale _scale = GradeScale.routes;
  int _grade = 8;

  @override
  void dispose() {
    _name.dispose();
    _wall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final system = StoreScope.of(context).gradeSystem;
    final grades = _scale.grades(system);
    final ok =
        _name.text.trim().isNotEmpty &&
        (!widget.newWall || _wall.text.trim().isNotEmpty);
    return AlertDialog(
      title: Text(l.recordRoute),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.newWall) ...[
              Text(l.newWallNote),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('wall name'),
                controller: _wall,
                maxLength: 60,
                decoration: InputDecoration(labelText: l.wallName),
                onChanged: (_) => setState(() {}),
              ),
            ],
            TextField(
              key: const ValueKey('route name'),
              controller: _name,
              maxLength: 60,
              autofocus: true,
              decoration: InputDecoration(labelText: l.routeName),
              onChanged: (_) => setState(() {}),
            ),
            SegmentedButton<GradeScale>(
              segments: [
                ButtonSegment(
                  value: GradeScale.routes,
                  label: Text(l.routeScale),
                ),
                ButtonSegment(
                  value: GradeScale.boulders,
                  label: Text(l.boulderScale),
                ),
              ],
              selected: {_scale},
              onSelectionChanged: (s) => setState(() {
                _scale = s.first;
                _grade = _grade.clamp(0, _scale.grades(system).length - 1);
              }),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: const ValueKey('route grade'),
              initialValue: _grade.clamp(0, grades.length - 1),
              decoration: InputDecoration(labelText: l.routeGrade),
              items: [
                for (var i = 0; i < grades.length; i++)
                  DropdownMenuItem(value: i, child: Text(grades[i])),
              ],
              onChanged: (v) => setState(() => _grade = v ?? _grade),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: !ok
              ? null
              : () => Navigator.pop(
                  context,
                  _RouteDetails(
                    _name.text.trim(),
                    _scale,
                    _grade,
                    widget.newWall ? _wall.text.trim() : null,
                  ),
                ),
          child: Text(l.save),
        ),
      ],
    );
  }
}
