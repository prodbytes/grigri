import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The log file's name, in the app's support directory (iOS: the app
/// container's Library/Application Support; Android: its files dir).
/// `scripts/ios-log.sh` copies it off the iPhone.
const logFileName = 'grigri.log';

/// Past this size the file is moved to `grigri.log.1` (replacing the older
/// one) when the app starts: at most about 1 MB of logs on the device.
const _maxBytes = 512 * 1024;

/// Opens the log file for appending: a function that writes one line, or
/// null when it can't be opened (the app runs without it).
Future<void Function(String line)?> openLogFile() async {
  try {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$logFileName');
    if (await file.exists() && await file.length() > _maxBytes) {
      await file.rename('${file.path}.1');
    }
    return (line) {
      try {
        // Written through at once: the lines before a crash are kept.
        file.writeAsStringSync('$line\n', mode: FileMode.append);
      } on FileSystemException {
        // A full disk: the log goes on without its file.
      }
    };
  } on Object {
    return null;
  }
}
