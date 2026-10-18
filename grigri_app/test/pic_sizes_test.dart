import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/model/pics.dart';
import 'package:grigri_app/ui/common.dart';
import 'package:grigri_app/ui/grigri_pic_image.dart';

import 'support/fakes.dart';

const _variants = [
  PicVariant(key: 'crags/x/a-w640.jpg', width: 640, height: 427),
  PicVariant(key: 'crags/x/a-w1080.jpg', width: 1080, height: 720),
  PicVariant(key: 'crags/x/a-w1440.jpg', width: 1440, height: 960),
];

String _pick(Size box, double ratio, [List<PicVariant> variants = _variants]) =>
    picKeyFor('crags/x/a.jpg', variants, box: box, devicePixelRatio: ratio);

/// A real 2 x 2 PNG, which decodes (the fakes' `png` makes a codec but no
/// frame).
Future<Uint8List> _realPng() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 2, 2),
    Paint()..color = const Color(0xFF3C6E47),
  );
  final image = await recorder.endRecording().toImage(2, 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  late Uint8List realPng;
  setUpAll(() async => realPng = await _realPng());

  group('picKeyFor', () {
    test("the narrowest copy whose pixels cover the box, cropped", () {
      // A plan screen thumbnail, 170 x 120, of a 3:2 photo: cropped to its
      // height, 180 points wide.
      expect(_pick(const Size(170, 120), 1), 'crags/x/a-w640.jpg');
      expect(_pick(const Size(170, 120), 3.5), 'crags/x/a-w640.jpg');
      expect(_pick(const Size(170, 120), 4), 'crags/x/a-w1080.jpg');
      // A wide box: the width counts.
      expect(_pick(const Size(500, 100), 2), 'crags/x/a-w1080.jpg');
      expect(_pick(const Size(700, 100), 2), 'crags/x/a-w1440.jpg');
    });

    test('the photo itself when no copy is big enough, or none is known', () {
      // A deck card on a phone: 3:2 photo cropped to 560 points tall.
      expect(_pick(const Size(360, 560), 3), 'crags/x/a.jpg');
      expect(_pick(const Size(170, 120), 2, const []), 'crags/x/a.jpg');
      expect(_pick(Size.infinite, 2), 'crags/x/a.jpg');
      expect(_pick(Size.zero, 2), 'crags/x/a.jpg');
      expect(_pick(const Size(170, 120), 0), 'crags/x/a.jpg');
    });

    test('a portrait photo, cropped to a wide box, needs its width', () {
      const tall = [
        PicVariant(key: 'crags/x/t-w640.jpg', width: 640, height: 960),
      ];
      expect(_pick(const Size(170, 120), 3, tall), 'crags/x/t-w640.jpg');
      expect(_pick(const Size(170, 120), 4, tall), 'crags/x/a.jpg');
    });
  });

  test('photos and covers read their copies, leaving out bad ones', () {
    final pic = GrigriPic.fromJson({
      'key': 'crags/x/a.jpg',
      'crag': 'Siurana',
      'variants': [
        {'key': 'crags/x/a-w640.jpg', 'width': 640, 'height': 427},
        {'key': 'crags/x/a-w1080.jpg', 'width': 0, 'height': 720},
        {'width': 1440, 'height': 960},
        'nope',
      ],
    });
    expect(pic.variants.map((v) => (v.key, v.width, v.height)), [
      ('crags/x/a-w640.jpg', 640, 427),
    ]);
    expect(GrigriPic.fromJson({'key': 'k', 'crag': 'c'}).variants, isEmpty);
    final cover = DeckCover.fromJson({
      'key': 'crags/x/a.jpg',
      'variants': [
        {'key': 'crags/x/a-w640.jpg', 'width': 640, 'height': 427},
      ],
    })!;
    expect(cover.variants.single.key, 'crags/x/a-w640.jpg');
    expect(DeckCover.fromJson({'key': 'k'})!.variants, isEmpty);
  });

  group('GrigriPicImage', () {
    Future<List<Uri>> show(
      WidgetTester tester, {
      required Size box,
      required double ratio,
      bool copiesFail = false,
    }) async {
      final asked = <Uri>[];
      final store = storeFor(
        FakeApi(),
        signedIn: false,
        image: (url) {
          asked.add(url);
          final copy = url.path.contains('-w');
          return MemoryImage(
            copy && copiesFail ? Uint8List.fromList([1, 2, 3]) : realPng,
          );
        },
      );
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MediaQuery(
            data: MediaQueryData(devicePixelRatio: ratio),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: SizedBox.fromSize(
                  size: box,
                  child: GrigriPicImage(
                    picKey: 'crags/x/a.jpg',
                    variants: _variants,
                    errorBuilder: (_, e, _) {
                      debugPrint('ERR $e');
                      return const Text('broken');
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      return asked;
    }

    testWidgets('loads the copy that covers it on this screen', (tester) async {
      final asked = await show(tester, box: const Size(170, 120), ratio: 3);
      expect(asked.map((u) => u.path).toSet(), {'/pics/crags/x/a-w640.jpg'});
    });

    testWidgets('loads the photo itself when it needs more', (tester) async {
      final asked = await show(tester, box: const Size(360, 560), ratio: 3);
      expect(asked.map((u) => u.path).toSet(), {'/pics/crags/x/a.jpg'});
    });

    testWidgets('a copy that fails gives way to the photo', (tester) async {
      final asked = await show(
        tester,
        box: const Size(170, 120),
        ratio: 3,
        copiesFail: true,
      );
      expect(asked.map((u) => u.path).toSet(), {
        '/pics/crags/x/a-w640.jpg',
        '/pics/crags/x/a.jpg',
      });
      expect(find.text('broken'), findsNothing);
    });
  });
}
