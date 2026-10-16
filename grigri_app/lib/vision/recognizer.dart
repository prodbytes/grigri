import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'features.dart';
import 'gray.dart';
import 'homography.dart';
import 'matcher.dart';

/// A reference view, ready to match: whose it is, its size and features.
class ViewFeatures {
  const ViewFeatures({
    required this.wallId,
    required this.view,
    required this.width,
    required this.height,
    required this.features,
  });

  final String wallId;

  /// Its index in the wall's views.
  final int view;
  final double width;
  final double height;
  final Features features;
}

/// A wall found in a frame: which view matched, and the transform from that
/// view's pixels to the frame's.
class Recognition {
  const Recognition({
    required this.wallId,
    required this.view,
    required this.toFrame,
    required this.inliers,
  });

  final String wallId;
  final int view;
  final Homography toFrame;
  final int inliers;
}

/// Finds known walls in camera frames, off the UI thread: a long-lived
/// isolate holds every view's features; each frame is matched against the
/// view found last first, then a few others in turn, within a budget, so a
/// frame never takes long however many views there are.
class Recognizer {
  Recognizer._(this._isolate, this._send, this._answers);

  final Isolate _isolate;
  final SendPort _send;
  final Stream<Object?> _answers;
  var _closed = false;

  static Future<Recognizer> start() async {
    final receive = ReceivePort();
    final isolate = await Isolate.spawn(_main, receive.sendPort);
    final answers = receive.asBroadcastStream();
    final send = await answers.first as SendPort;
    return Recognizer._(isolate, send, answers);
  }

  var _ids = 0;

  Future<Object?> _ask(List<Object?> message) async {
    if (_closed) return null;
    final id = ++_ids;
    final answer = _answers.firstWhere((a) => a is List && a[0] == id);
    _send.send([id, ...message]);
    return ((await answer)! as List)[1];
  }

  /// The views to look for, replacing any before.
  Future<void> setViews(List<ViewFeatures> views) => _ask([
    'views',
    [
      for (final v in views)
        [v.wallId, v.view, v.width, v.height, v.features.pack()],
    ],
  ]);

  /// The wall in [frame], if any.
  Future<Recognition?> recognize(GrayImage frame) async {
    final r = await _ask([
      'frame',
      TransferableTypedData.fromList([frame.data]),
      frame.width,
      frame.height,
    ]);
    if (r == null) return null;
    final l = r as List;
    return Recognition(
      wallId: l[0] as String,
      view: l[1] as int,
      toFrame: Homography(Float64List.fromList((l[2] as List).cast<double>())),
      inliers: l[3] as int,
    );
  }

  void close() {
    _closed = true;
    _isolate.kill(priority: Isolate.immediate);
  }
}

/// The views a frame tries besides the last found: about 150 ms of work.
const _viewsPerFrame = 6;

void _main(SendPort reply) {
  final receive = ReceivePort();
  reply.send(receive.sendPort);
  var views = <ViewFeatures>[];
  int? last;
  var next = 0;
  receive.listen((message) {
    final m = message as List;
    final id = m[0] as int;
    switch (m[1]) {
      case 'views':
        views = [
          for (final v in (m[2] as List).cast<List>())
            ViewFeatures(
              wallId: v[0] as String,
              view: v[1] as int,
              width: v[2] as double,
              height: v[3] as double,
              features: Features.unpack(v[4] as Float64List),
            ),
        ];
        last = null;
        next = 0;
        reply.send([id, null]);
      case 'frame':
        final data = (m[2] as TransferableTypedData)
            .materialize()
            .asUint8List();
        final frame = detect(GrayImage(m[3] as int, m[4] as int, data));
        final order = <int>[
          ?last,
          for (var k = 0; k < views.length && k < _viewsPerFrame; k++)
            (next + k) % views.length,
        ];
        if (views.isNotEmpty) next = (next + _viewsPerFrame) % views.length;
        Object? answer;
        for (final i in order.toSet()) {
          final v = views[i];
          final match = matchView(frame, v.features, v.width, v.height);
          if (match == null) continue;
          last = i;
          answer = [v.wallId, v.view, match.homography.toList(), match.inliers];
          break;
        }
        if (answer == null && last != null && !order.skip(1).contains(last)) {
          // Lost: the next frames search them all again.
          last = null;
        }
        reply.send([id, answer]);
    }
  });
}

/// A frame's own features and the first view that matches, run inline (a
/// still photo; tests).
Recognition? recognizeNow(GrayImage frame, List<ViewFeatures> views) {
  final features = detect(frame);
  for (final v in views) {
    final match = matchView(features, v.features, v.width, v.height);
    if (match != null) {
      return Recognition(
        wallId: v.wallId,
        view: v.view,
        toFrame: match.homography,
        inliers: match.inliers,
      );
    }
  }
  return null;
}
