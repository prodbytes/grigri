// How the app loads photos by URL (specs/platforms.md, Photo cache): on
// Android and iOS through a cache on the device's disk, on the web
// through the browser (which keeps them by their Cache-Control).
export 'photo_cache_web.dart' if (dart.library.io) 'photo_cache_io.dart';
