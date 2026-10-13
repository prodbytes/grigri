// The log file on Android and iOS (specs/logging.md); none on the web.
export 'log_file_stub.dart' if (dart.library.io) 'log_file_io.dart';
