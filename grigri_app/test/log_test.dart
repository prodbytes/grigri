import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/log.dart';

void main() {
  group('AppLog', () {
    test('prints and keeps lines, at most capacity, oldest dropped', () {
      final printed = <String>[];
      final log = AppLog(capacity: 3, sink: printed.add);
      for (var i = 1; i <= 4; i++) {
        log.info('t', 'line $i');
      }
      expect(log.lines.map((l) => l.message), ['line 2', 'line 3', 'line 4']);
      expect(printed, hasLength(4));
      expect(printed.last, endsWith('INFO [t] line 4'));
    });

    test('never keeps or prints emails, ID tokens or bearer tokens', () {
      final printed = <String>[];
      final log = AppLog(sink: printed.add);
      log.error(
        'auth',
        'failed for test.climber@example.com',
        Exception(
          'token eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiI3In0.c2lnbmF0dXJl '
          'header Authorization: Bearer abcDEF123_-xyz',
        ),
      );
      final line = log.lines.single.toString();
      expect(line, isNot(contains('example.com')));
      expect(line, isNot(contains('eyJ')));
      expect(line, isNot(contains('abcDEF123')));
      expect(line, contains('<email>'));
      expect(line, contains('<jwt>'));
      expect(line, contains('Bearer <token>'));
      expect(printed.single, line);
    });

    test('the file gets the kept lines, then every new one', () {
      final log = AppLog(sink: (_) {})..info('start', 'before');
      final file = <String>[];
      log.attachFile(file.add);
      log.warn('api', 'after');
      expect(file, hasLength(2));
      expect(file.first, endsWith('INFO [start] before'));
      expect(file.last, endsWith('WARN [api] after'));
    });

    test('says the level, the error type and the stack', () {
      final log = AppLog(sink: (_) {});
      log.warn('api', 'GET /api/me: 503', StateError('down'));
      log.error('x', 'boom', null, StackTrace.fromString('#0 here'));
      expect(
        log.lines.first.toString(),
        contains('WARN [api] GET /api/me: 503: StateError'),
      );
      expect(log.lines.last.message, 'boom\n#0 here');
    });
  });
}
