import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/photo_cache_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  late Directory dir;
  late List<Uri> fetched;
  late Map<Uri, Uint8List> served;
  late DateTime now;

  PhotoCache cache({int maxBytes = 1 << 20}) => PhotoCache(
    directory: () async => dir,
    client: MockClient((request) async {
      fetched.add(request.url);
      final bytes = served[request.url];
      return bytes == null
          ? http.Response('', 403)
          : http.Response.bytes(bytes, 200);
    }),
    maxBytes: maxBytes,
    now: () => now,
  );

  Uri url(String key) => Uri.parse('https://grigri.test/photos/$key');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('photo_cache_test');
    fetched = [];
    served = {};
    now = DateTime.now();
  });
  tearDown(() => dir.delete(recursive: true));

  List<String> files() =>
      [for (final f in dir.listSync()) f.uri.pathSegments.last]..sort();

  test('saves a photo, and reads it back by its URL', () async {
    final photos = cache();
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(await photos.read(url('a.jpg')), isNull);
    await photos.write(url('a.jpg'), bytes);
    expect(await photos.read(url('a.jpg')), bytes);
    expect(await photos.read(url('b.jpg')), isNull);
    // One whole file, no part left over.
    expect(files(), hasLength(1));
    expect(files().single, isNot(endsWith('.part')));
  });

  test('downloads with progress; anything but 200 is an error', () async {
    final photos = cache();
    served[url('a.jpg')] = Uint8List.fromList(List.filled(10, 7));
    final events = <ImageChunkEvent>[];
    final bytes = await photos.fetch(url('a.jpg'), onChunk: events.add);
    expect(bytes, hasLength(10));
    expect(events.last.cumulativeBytesLoaded, 10);
    await expectLater(
      photos.fetch(url('gone.jpg')),
      throwsA(
        isA<NetworkImageLoadException>().having(
          (e) => e.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
  });

  test('past its size, the least recently used go first', () async {
    final photos = cache(maxBytes: 25);
    final start = now;
    await photos.trim();
    Future<void> save(String key, DateTime at) async {
      now = at;
      await photos.write(url(key), Uint8List(10));
    }

    await save('old.jpg', start.add(const Duration(hours: 1)));
    await save('mid.jpg', start.add(const Duration(hours: 2)));
    // Shown again: it's the most recently used now.
    now = start.add(const Duration(hours: 3));
    expect(await photos.read(url('old.jpg')), isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await save('new.jpg', start.add(const Duration(hours: 4)));
    await photos.trim();
    expect(await photos.read(url('mid.jpg')), isNull);
    expect(await photos.read(url('old.jpg')), isNotNull);
    expect(await photos.read(url('new.jpg')), isNotNull);
  });

  test(
    'forgets photos unused for a month, and writes left half done',
    () async {
      final photos = cache();
      final start = now;
      await photos.trim();
      now = start.add(const Duration(hours: 1));
      await photos.write(url('a.jpg'), Uint8List(3));
      final part = File('${dir.path}/x.123.part')..writeAsBytesSync([1]);
      part.setLastModifiedSync(start);
      now = start.add(const Duration(days: 20));
      await photos.trim();
      expect(await photos.read(url('a.jpg')), isNotNull);
      expect(part.existsSync(), isFalse);
      now = start.add(const Duration(days: 60));
      await photos.trim();
      expect(files(), isEmpty);
    },
  );

  test('without a directory, photos still load from the network', () async {
    final photos = PhotoCache(
      directory: () async => throw const FileSystemException('none'),
      client: MockClient((_) async => http.Response.bytes([1, 2], 200)),
    );
    await photos.write(url('a.jpg'), Uint8List(2));
    expect(await photos.read(url('a.jpg')), isNull);
    expect(await photos.fetch(url('a.jpg')), [1, 2]);
  });

  group('CachedPhoto', () {
    Future<ImageInfo> load(ImageProvider provider) {
      final done = Completer<ImageInfo>();
      provider
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (info, _) => done.complete(info),
              onError: (e, _) => done.completeError(e),
            ),
          );
      return done.future;
    }

    testWidgets('downloads a photo once, then shows it from the disk', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final photos = cache();
        served[url('a.png')] = realPng;
        expect((await load(CachedPhoto(url('a.png'), photos))).image.width, 2);
        expect(fetched, [url('a.png')]);
        // Saved once it decoded.
        for (
          var i = 0;
          i < 100 && await photos.read(url('a.png')) == null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(files(), hasLength(1));
        // The next launch: nothing in memory, the disk has it.
        PaintingBinding.instance.imageCache.clear();
        await load(CachedPhoto(url('a.png'), cache()));
        expect(fetched, [url('a.png')]);
      });
    });

    testWidgets('a damaged file is downloaded again; a bad download is '
        'not saved', (tester) async {
      await tester.runAsync(() async {
        final photos = cache();
        await photos.write(url('a.png'), Uint8List.fromList([1, 2, 3]));
        served[url('a.png')] = realPng;
        await load(CachedPhoto(url('a.png'), photos));
        expect(fetched, [url('a.png')]);

        PaintingBinding.instance.imageCache.clear();
        served[url('b.png')] = Uint8List.fromList([9, 9, 9]);
        await expectLater(
          load(CachedPhoto(url('b.png'), photos)),
          throwsA(anything),
        );
        expect(await photos.read(url('b.png')), isNull);
      });
    });

    test('is the same image for the same URL and cache', () {
      final photos = cache();
      expect(
        CachedPhoto(url('a.jpg'), photos),
        CachedPhoto(url('a.jpg'), photos),
      );
      expect(
        CachedPhoto(url('a.jpg'), photos),
        isNot(CachedPhoto(url('b.jpg'), photos)),
      );
    });
  });
}
