import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/realtime.dart';
import 'package:grigri_app/main.dart';
import 'package:grigri_app/ui/common.dart';
import 'package:grigri_app/ui/home_shell.dart';

import 'support/fakes.dart';

/// Timers that tests fire by hand, recording each delay.
class FakeScheduler {
  final delays = <Duration>[];
  final _callbacks = <void Function()>[];

  Timer call(Duration delay, void Function() callback) {
    delays.add(delay);
    _callbacks.add(callback);
    return _FakeTimer();
  }

  /// Runs the latest scheduled callback.
  Future<void> fire() async {
    _callbacks.removeLast()();
    await pumpEventQueue();
  }
}

class _FakeTimer implements Timer {
  @override
  bool get isActive => false;
  @override
  int get tick => 0;
  @override
  void cancel() {}
}

void main() {
  group('hints and where to connect', () {
    test('a hint names a kind and maybe a plan; anything else is ignored', () {
      expect(
        Hint.parse('{"kind":"message","planId":"p1"}'),
        const Hint(HintKind.message, 'p1'),
      );
      expect(Hint.parse('{"kind":"notice"}'), const Hint(HintKind.notice));
      expect(Hint.parse('{"kind":"later"}'), const Hint(HintKind.unknown));
      expect(Hint.parse('not json'), isNull);
      expect(Hint.parse('{"planId":"p1"}'), isNull);
    });

    test('the URL names the authorizer and carries the token', () {
      final url = fakeRealtimeInfo.connectUrl('tok/en+=');
      expect(url.host, 'mqtt.example.com');
      expect(url.path, '/mqtt');
      expect(url.queryParameters, {
        'x-amz-customauthorizer-name': 'grigri-test-realtime',
        'token': 'tok/en+=',
      });
      final local = RealtimeInfo.fromJson({
        'url': 'wss://local.example.com:2543/mqtt',
        'authorizer': '',
        'topic': 't/#',
        'clientIdPrefix': 'me-',
      })!;
      expect(local.connectUrl('t').queryParameters, {'token': 't'});
      expect(local.connectUrl('t').port, 2543);
      expect(RealtimeInfo.fromJson({'url': null}), isNull);
    });
  });

  group('the connection', () {
    late FakeRealtimeTransport transport;
    late FakeScheduler scheduler;
    late List<Hint> hints;
    late int reconnects;
    late Realtime realtime;
    RealtimeInfo? info;

    setUp(() {
      transport = FakeRealtimeTransport();
      scheduler = FakeScheduler();
      hints = [];
      reconnects = 0;
      info = fakeRealtimeInfo;
      realtime = Realtime(
        transport: transport,
        info: () async => info,
        token: () async => 'session-1',
        onHint: hints.add,
        onReconnected: () => reconnects++,
        schedule: scheduler.call,
      );
    });

    tearDown(() => realtime.dispose());

    test('connects as me with my token, and hands on hints', () async {
      realtime.start();
      await pumpEventQueue();
      expect(realtime.connected, isTrue);
      final connect = transport.connects.single;
      expect(connect.topic, 'grigri/test/climbers/me/#');
      expect(connect.clientId, startsWith('me-'));
      expect(connect.url.queryParameters['token'], 'session-1');
      transport.current.send('{"kind":"request","planId":"p2"}');
      transport.current.send('garbage');
      await pumpEventQueue();
      expect(hints, [const Hint(HintKind.request, 'p2')]);
    });

    test(
      'reconnects with backoff, up to a minute, and resets once up',
      () async {
        transport.refuse = true;
        realtime.start();
        await pumpEventQueue();
        for (var i = 0; i < 8; i++) {
          await scheduler.fire();
        }
        final seconds = [1, 2, 4, 8, 16, 32, 60, 60, 60];
        expect(scheduler.delays, hasLength(seconds.length));
        for (final (i, delay) in scheduler.delays.indexed) {
          expect(delay.inMilliseconds, lessThanOrEqualTo(seconds[i] * 1000));
          expect(delay.inMilliseconds, greaterThanOrEqualTo(seconds[i] * 500));
        }
        expect(Realtime.backoff(0, 1), const Duration(seconds: 1));
        expect(Realtime.backoff(20, 1), const Duration(seconds: 60));
        // It comes back: connected, and the next drop starts from 1 s again.
        transport.refuse = false;
        await scheduler.fire();
        expect(realtime.connected, isTrue);
        expect(reconnects, 0);
        transport.current.drop();
        await pumpEventQueue();
        expect(realtime.connected, isFalse);
        expect(scheduler.delays.last.inMilliseconds, lessThanOrEqualTo(1000));
        await scheduler.fire();
        expect(realtime.connected, isTrue);
        expect(reconnects, 1);
      },
    );

    test('stop closes it and stops reconnecting', () async {
      realtime.start();
      await pumpEventQueue();
      final channel = transport.current;
      realtime.stop();
      expect(channel.isClosed, isTrue);
      expect(realtime.connected, isFalse);
      await pumpEventQueue();
      expect(scheduler.delays, isEmpty);
    });

    test('live updates off: no connection, no retries', () async {
      info = null;
      realtime.start();
      await pumpEventQueue();
      expect(transport.connects, isEmpty);
      expect(scheduler.delays, isEmpty);
    });
  });

  test('polling: every tick unless live, then every nth', () {
    final cadence = Cadence(liveEvery: 4);
    final runs = [for (var i = 0; i < 4; i++) cadence.tick(live: false)];
    expect(runs, [true, true, true, true]);
    final live = [for (var i = 0; i < 8; i++) cadence.tick(live: true)];
    expect(live, [false, false, false, true, false, false, false, true]);
    expect(cadence.tick(live: false), isTrue);
  });

  group('the store', () {
    late FakeApi api;
    late FakeRealtimeTransport transport;
    late GrigriStore store;

    setUp(() async {
      api = sampleApi()..realtimeInfo = fakeRealtimeInfo;
      transport = FakeRealtimeTransport();
      store = storeFor(api, realtime: transport);
      await store.start();
      store.goLive();
      await pumpEventQueue();
    });

    tearDown(() => store.dispose());

    Future<List<String>> callsAfter(String hint) async {
      api.calls.clear();
      transport.current.send(hint);
      await pumpEventQueue();
      return api.calls;
    }

    test(
      'connects once signed in, and refetches just what a hint names',
      () async {
        expect(store.live, isTrue);
        expect(
          await callsAfter('{"kind":"request","planId":"my-gym"}'),
          unorderedEquals(['GET /api/requests', 'GET /api/notices']),
        );
        expect(await callsAfter('{"kind":"message","planId":"my-gym"}'), [
          'GET /api/plans/my-gym/messages',
        ]);
        expect(
          await callsAfter('{"kind":"notice","planId":"crag-day"}'),
          unorderedEquals(['GET /api/notices', 'GET /api/plans']),
        );
        expect(
          await callsAfter('{"kind":"plan","planId":"crag-day"}'),
          unorderedEquals(['GET /api/plans', 'GET /api/requests']),
        );
        expect(
          await callsAfter('{"kind":"match","planId":"crag-day"}'),
          unorderedEquals([
            'GET /api/plans',
            'GET /api/requests',
            'GET /api/notices',
          ]),
        );
        // Not my plan's chat: nothing to fetch.
        expect(
          await callsAfter('{"kind":"message","planId":"crag-day"}'),
          isEmpty,
        );
      },
    );

    test('an open chat is refetched on a request hint for its plan', () async {
      await store.pollMessages('my-gym');
      expect(
        await callsAfter('{"kind":"request","planId":"my-gym"}'),
        unorderedEquals([
          'GET /api/requests',
          'GET /api/notices',
          'GET /api/plans/my-gym/messages?after',
        ]),
      );
    });

    test('goes quiet in the background and on sign-out', () async {
      final channel = transport.current;
      store.goQuiet();
      expect(channel.isClosed, isTrue);
      expect(store.live, isFalse);
      store.goLive();
      await pumpEventQueue();
      expect(store.live, isTrue);
      await store.signOut();
      await pumpEventQueue();
      expect(transport.current.isClosed, isTrue);
      expect(store.live, isFalse);
    });
  });

  group('polling around live updates', () {
    testWidgets('slows down while connected and resumes when it drops', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final api = sampleApi()..realtimeInfo = fakeRealtimeInfo;
      final transport = FakeRealtimeTransport();
      final store = storeFor(api, realtime: transport);
      await tester.runAsync(store.start);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeShell(
              refreshEvery: Duration(seconds: 1),
              liveRefreshEvery: Duration(seconds: 4),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(store.live, isTrue);

      int planPolls() => api.calls.where((c) => c == 'GET /api/plans').length;
      Future<int> pollsOver(int seconds) async {
        final before = planPolls();
        for (var i = 0; i < seconds; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        return planPolls() - before;
      }

      expect(await pollsOver(8), 2); // every 4 s while live
      transport.refuse = true; // and it can't reconnect for now
      transport.current.drop();
      await tester.pump();
      expect(store.live, isFalse);
      expect(await pollsOver(4), 4); // every second again
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  });

  test('GrigriApp still builds with a store that has live updates', () {
    final store = storeFor(sampleApi(), realtime: FakeRealtimeTransport());
    expect(GrigriApp(store: store), isA<GrigriApp>());
    store.dispose();
  });
}
