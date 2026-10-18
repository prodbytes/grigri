import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/grigri_store.dart';
import 'package:grigri_app/data/realtime.dart';
import 'package:grigri_app/main.dart';
import 'package:grigri_app/model/premium.dart';
import 'package:grigri_app/ui/chat_screen.dart';
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
    late int infoCalls;
    late DateTime clock;
    RealtimeInfo? info;

    setUp(() {
      transport = FakeRealtimeTransport();
      scheduler = FakeScheduler();
      hints = [];
      reconnects = 0;
      infoCalls = 0;
      clock = DateTime(2030, 1, 1, 9);
      info = fakeRealtimeInfo;
      realtime = Realtime(
        transport: transport,
        info: () async {
          infoCalls++;
          return info;
        },
        token: () async => 'session-1',
        onHint: hints.add,
        onReconnected: () => reconnects++,
        schedule: scheduler.call,
        now: () => clock,
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
      'reconnects with backoff, up to a minute, and resets once it stayed up',
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
        // It comes back: connected, and once it has stayed up a while the
        // next drop starts from 1 s again.
        transport.refuse = false;
        await scheduler.fire();
        expect(realtime.connected, isTrue);
        expect(reconnects, 0);
        clock = clock.add(Realtime.stableAfter);
        transport.current.drop();
        await pumpEventQueue();
        expect(realtime.connected, isFalse);
        expect(scheduler.delays.last.inMilliseconds, lessThanOrEqualTo(1000));
        await scheduler.fire();
        expect(realtime.connected, isTrue);
        expect(reconnects, 1);
      },
    );

    test('a connection dropped at once keeps backing off', () async {
      realtime.start();
      await pumpEventQueue();
      // Accepted, then dropped straight away, again and again: no loop
      // every second, the backoff keeps growing.
      for (var i = 0; i < 4; i++) {
        transport.current.drop();
        await pumpEventQueue();
        clock = clock.add(const Duration(seconds: 1));
        await scheduler.fire();
        expect(realtime.connected, isTrue);
      }
      final seconds = [1, 2, 4, 8];
      for (final (i, delay) in scheduler.delays.indexed) {
        expect(delay.inMilliseconds, greaterThanOrEqualTo(seconds[i] * 500));
        expect(delay.inMilliseconds, lessThanOrEqualTo(seconds[i] * 1000));
      }
      // Each short-lived one asks where to connect again.
      expect(infoCalls, 5);
    });

    test('where to connect is asked once, while it works', () async {
      realtime.start();
      await pumpEventQueue();
      clock = clock.add(const Duration(minutes: 5));
      transport.current.drop();
      await pumpEventQueue();
      await scheduler.fire();
      expect(realtime.connected, isTrue);
      realtime.stop();
      realtime.start();
      await pumpEventQueue();
      expect(transport.connects, hasLength(3));
      expect(infoCalls, 1);
      // Refused: asked again before the next try.
      clock = clock.add(const Duration(minutes: 5));
      transport.refuse = true;
      transport.current.drop();
      await pumpEventQueue();
      await scheduler.fire();
      expect(infoCalls, 1);
      transport.refuse = false;
      await scheduler.fire();
      expect(realtime.connected, isTrue);
      expect(infoCalls, 2);
      // A new session asks again.
      realtime
        ..stop()
        ..forget()
        ..start();
      await pumpEventQueue();
      expect(infoCalls, 3);
    });

    test(
      'a restart is not a reconnect: only drops while running catch up',
      () async {
        realtime.start();
        await pumpEventQueue();
        // Back from the background: the app refreshes by itself.
        realtime.stop();
        realtime.start();
        await pumpEventQueue();
        expect(realtime.connected, isTrue);
        expect(reconnects, 0);
        // A drop while in the foreground: hints may have been missed.
        transport.current.drop();
        await pumpEventQueue();
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

    test('back from the background: no catch-up on top of the resume '
        'refresh, nor where to connect again', () async {
      store.goQuiet();
      api.calls.clear();
      store.goLive();
      await pumpEventQueue();
      expect(store.live, isTrue);
      expect(api.calls, isEmpty);
      // A drop in the foreground still catches up.
      transport.current.drop();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await pumpEventQueue();
      expect(store.live, isTrue);
      expect(
        api.calls,
        unorderedEquals([
          // It dropped at once: where to connect may have changed.
          'GET /api/realtime',
          'GET /api/plans',
          'GET /api/requests',
          'GET /api/notices',
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

  group('no duplicate refreshes', () {
    Future<(FakeApi, GrigriStore, GlobalKey<NavigatorState>)> pumpShell(
      WidgetTester tester, {
      FakeRealtimeTransport? transport,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final api = sampleApi();
      final store = storeFor(api, realtime: transport);
      final navigator = GlobalKey<NavigatorState>();
      await tester.runAsync(store.start);
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [HomeShell.routes],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeShell(refreshEvery: Duration(seconds: 1)),
          ),
        ),
      );
      await tester.pump();
      return (api, store, navigator);
    }

    int count(FakeApi api, String call) =>
        api.calls.where((c) => c == call).length;

    testWidgets('the deck waits while a screen covers it, then refreshes '
        'once', (tester) async {
      final (api, store, navigator) = await pumpShell(tester);
      api.calls.clear();
      await tester.pump(const Duration(seconds: 1));
      expect(count(api, 'GET /api/discover'), 1);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      api.calls.clear();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      // The badges' refreshes go on; the deck under the screen waits.
      expect(count(api, 'GET /api/plans'), 3);
      expect(count(api, 'GET /api/discover'), 0);
      navigator.currentState!.pop();
      await tester.pump();
      expect(count(api, 'GET /api/discover'), 1);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('a screen that closes before a refresh was due refreshes '
        'nothing extra', (tester) async {
      final (api, store, navigator) = await pumpShell(tester);
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pump();
      api.calls.clear();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(count(api, 'GET /api/discover'), 0);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('Premium is checked on return once after its pages opened, '
        'afresh', (tester) async {
      final (api, store, _) = await pumpShell(tester);
      int premiumCalls() =>
          api.calls.where((c) => c.startsWith('GET /api/premium')).length;
      Future<void> awayAndBack() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }

      // The profile's card asks at launch, as ever.
      expect(premiumCalls(), 1);
      api.calls.clear();
      await awayAndBack();
      expect(premiumCalls(), 0);
      expect(count(api, 'GET /api/plans'), greaterThan(0));
      await tester.runAsync(() => store.subscribe(PremiumPlan.monthly));
      expect(api.opened, isNotEmpty);
      api.calls.clear();
      await awayAndBack();
      expect(api.calls.where((c) => c.startsWith('GET /api/premium')), [
        'GET /api/premium?fresh=1',
      ]);
      await awayAndBack();
      expect(premiumCalls(), 1);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('with the profile on screen, a return checks Premium', (
      tester,
    ) async {
      final (api, store, _) = await pumpShell(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.person_outline),
        ),
      );
      await tester.pump();
      api.calls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.calls, contains('GET /api/premium'));
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets("a hint's fetch of the open chat puts off its next poll", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final api = sampleApi()..realtimeInfo = fakeRealtimeInfo;
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: ['robin', 'me'],
      );
      final transport = FakeRealtimeTransport();
      final store = storeFor(api, realtime: transport);
      await tester.runAsync(store.start);
      store.goLive();
      await tester.pumpWidget(
        StoreScope(
          store: store,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatScreen(
              planId: 'crag-day',
              pollEvery: Duration(seconds: 1),
              livePollEvery: Duration(seconds: 3),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(store.live, isTrue);
      final first = api.calls
          .where((c) => c.startsWith('GET /api/plans/crag-day/messages'))
          .length;
      int polls() =>
          api.calls
              .where((c) => c.startsWith('GET /api/plans/crag-day/messages'))
              .length -
          first;
      Future<void> wait(int millis) =>
          tester.pump(Duration(milliseconds: millis));

      // Live: every third tick (at 3 s).
      await wait(3000);
      expect(polls(), 1);
      await wait(2500);
      expect(polls(), 1);
      // A hint brings the new message at 5.5 s: the chat's poll due at
      // 6 s starts its round over, to 8 s.
      transport.current.send('{"kind":"message","planId":"crag-day"}');
      await tester.pump();
      expect(polls(), 2);
      await wait(2000);
      expect(polls(), 2);
      await wait(1000);
      expect(polls(), 3);
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
