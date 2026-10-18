import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Photos on Android and iOS: loaded through [PhotoCache.device], so each
/// is downloaded once, not on every launch (specs/platforms.md, Photo
/// cache).
ImageProvider Function(Uri url) defaultPhotoImage() {
  final cache = _device ??= PhotoCache.device();
  return (url) => CachedPhoto(url, cache);
}

PhotoCache? _device;

/// Photos kept on the device's disk, by URL: one file each, named after a
/// hash of its URL. Photos' URLs never change what they serve (their keys
/// are new for every upload, and GriGri Pics' follow their source), so a
/// saved photo is never stale and is never checked again.
///
/// Bounded: past [maxBytes] the least recently used go first, and any not
/// used for [maxAge] go. The OS may also clear it (it's in the app's cache
/// directory). Anything failing on the disk (none, full) leaves photos to
/// load from the network, as without it.
class PhotoCache {
  PhotoCache({
    required this._directory,
    http.Client? client,
    this.maxBytes = 100 * 1024 * 1024,
    this.maxAge = const Duration(days: 30),
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  /// The app's: `photos/` in its cache directory.
  factory PhotoCache.device() => PhotoCache(
    directory: () async =>
        Directory('${(await getApplicationCacheDirectory()).path}/photos'),
  );

  final Future<Directory> Function() _directory;
  final http.Client _client;
  final DateTime Function() _now;

  /// The most it keeps, in bytes.
  final int maxBytes;

  /// How long a photo not shown since is kept.
  final Duration maxAge;

  Future<Directory?>? _dir;

  /// About how many bytes it holds: measured by [trim], and counted up as
  /// photos are saved.
  int _bytes = 0;
  Future<void>? _trimming;
  final _random = math.Random();

  /// The directory, made when first needed (and trimmed then); null when
  /// there's none to use.
  Future<Directory?> get _ready => _dir ??= () async {
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      unawaited(_trim(dir));
      return dir;
    } on Object {
      return null;
    }
  }();

  File _file(Directory dir, Uri url) =>
      File('${dir.path}/${sha1.convert(utf8.encode(url.toString()))}');

  /// The saved photo at [url], marked as just used; null when there's none.
  Future<Uint8List?> read(Uri url) async {
    final dir = await _ready;
    if (dir == null) return null;
    final file = _file(dir, url);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      unawaited(_touch(file));
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  Future<void> _touch(File file) async {
    try {
      await file.setLastModified(_now());
    } on FileSystemException {
      // Gone meanwhile (trimmed): it's still shown.
    }
  }

  /// Downloads the photo at [url], telling [onChunk] how far along it is.
  /// Throws [NetworkImageLoadException] unless it's there (200).
  Future<Uint8List> fetch(
    Uri url, {
    void Function(ImageChunkEvent event)? onChunk,
  }) async {
    final response = await _client.send(http.Request('GET', url));
    if (response.statusCode != HttpStatus.ok) {
      await response.stream.drain<void>();
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: url,
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.stream) {
      builder.add(chunk);
      onChunk?.call(
        ImageChunkEvent(
          cumulativeBytesLoaded: builder.length,
          expectedTotalBytes: response.contentLength,
        ),
      );
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) throw StateError('$url is an empty file.');
    return bytes;
  }

  /// Saves [bytes] as the photo at [url] (whole or not at all: written
  /// aside, then moved in), trimming the cache when it's over its size.
  Future<void> write(Uri url, Uint8List bytes) async {
    final dir = await _ready;
    if (dir == null) return;
    final file = _file(dir, url);
    final part = File('${file.path}.${_random.nextInt(1 << 32)}.part');
    try {
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
      // Used now, by the cache's clock (what trimming goes by).
      await file.setLastModified(_now());
      _bytes += bytes.length;
    } on FileSystemException {
      try {
        await part.delete();
      } on FileSystemException {
        // Never written.
      }
      return;
    }
    if (_bytes > maxBytes) await _trim(dir);
  }

  /// Forgets the photo at [url] (it couldn't be shown).
  Future<void> remove(Uri url) async {
    final dir = await _ready;
    if (dir == null) return;
    try {
      await _file(dir, url).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// Deletes what's past [maxAge] (and writes left half done), then the
  /// least recently used until it's within [maxBytes]. One at a time.
  Future<void> trim() async {
    final dir = await _ready;
    if (dir != null) await _trim(dir);
  }

  Future<void> _trim(Directory dir) =>
      _trimming ??= _trimNow(dir).whenComplete(() => _trimming = null);

  Future<void> _trimNow(Directory dir) async {
    final now = _now();
    final kept = <(File, DateTime, int)>[];
    try {
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is! File) continue;
        try {
          final stat = await entry.stat();
          final age = now.difference(stat.modified);
          final stale = entry.path.endsWith('.part')
              ? age > const Duration(hours: 1)
              : age > maxAge;
          if (stale) {
            await entry.delete();
          } else {
            kept.add((entry, stat.modified, stat.size));
          }
        } on FileSystemException {
          // Gone meanwhile.
        }
      }
    } on FileSystemException {
      return;
    }
    kept.sort((a, b) => a.$2.compareTo(b.$2));
    var total = kept.fold(0, (sum, f) => sum + f.$3);
    for (final (file, _, size) in kept) {
      if (total <= maxBytes) break;
      try {
        await file.delete();
        total -= size;
      } on FileSystemException {
        // Gone meanwhile.
      }
    }
    _bytes = total;
  }
}

/// A photo by URL, through a [PhotoCache]: from the disk when it's saved
/// there, else downloaded (reporting its progress, as [NetworkImage] does)
/// and saved once it decodes.
@immutable
class CachedPhoto extends ImageProvider<CachedPhoto> {
  const CachedPhoto(this.url, this.cache);

  final Uri url;
  final PhotoCache cache;

  @override
  Future<CachedPhoto> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<CachedPhoto>(this);

  @override
  ImageStreamCompleter loadImage(CachedPhoto key, ImageDecoderCallback decode) {
    final chunks = StreamController<ImageChunkEvent>();
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode, chunks),
      chunkEvents: chunks.stream,
      scale: 1,
      debugLabel: url.toString(),
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedPhoto>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _load(
    CachedPhoto key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunks,
  ) async {
    try {
      final saved = await cache.read(url);
      if (saved != null) {
        try {
          return await _decoded(saved, decode);
        } on Object {
          // Damaged: downloaded again.
          await cache.remove(url);
        }
      }
      final bytes = await cache.fetch(url, onChunk: chunks.add);
      final codec = await _decoded(bytes, decode);
      // Only a photo that shows is saved.
      unawaited(cache.write(url, bytes));
      return codec;
    } on Object {
      // Not kept in memory either, so showing it again tries again.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    } finally {
      unawaited(chunks.close());
    }
  }

  /// The photo decoded as far as its first frame, so bytes that aren't
  /// one throw here (a codec alone may only fail when it's shown).
  static Future<ui.Codec> _decoded(
    Uint8List bytes,
    ImageDecoderCallback decode,
  ) async {
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    try {
      return _FirstFrameDecoded(codec, await codec.getNextFrame());
    } on Object {
      codec.dispose();
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CachedPhoto && other.url == url && identical(other.cache, cache);

  @override
  int get hashCode => Object.hash(url, identityHashCode(cache));

  @override
  String toString() => '${objectRuntimeType(this, 'CachedPhoto')}("$url")';
}

/// A codec whose first frame is already decoded: handed over first, then
/// the rest from [_codec], as it would have given them.
class _FirstFrameDecoded implements ui.Codec {
  _FirstFrameDecoded(this._codec, this._first);

  final ui.Codec _codec;
  ui.FrameInfo? _first;

  @override
  int get frameCount => _codec.frameCount;

  @override
  int get repetitionCount => _codec.repetitionCount;

  @override
  Future<ui.FrameInfo> getNextFrame() {
    final first = _first;
    if (first == null) return _codec.getNextFrame();
    _first = null;
    return Future.value(first);
  }

  @override
  void dispose() {
    _first?.image.dispose();
    _first = null;
    _codec.dispose();
  }
}
