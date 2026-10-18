// The app's regular refreshes in as few requests as the data allows
// (specs/matching.md#refreshing): the same data, the same timing.
import 'package:flutter_test/flutter_test.dart';
import 'package:grigri_app/data/api.dart';
import 'package:grigri_app/data/grigri_store.dart';

import 'support/fakes.dart';

/// A server from before the batched routes: 404 for them.
class OlderApi extends FakeApi {
  @override
  Future<Updates> updates({String noticesStamp = '0'}) async {
    calls.add('GET /api/updates');
    throw const ApiException(404, 'no such route');
  }

  @override
  Future<ChatsMessages> chatsMessages(Map<String, DateTime?> chats) async {
    calls.add('GET /api/chats/messages');
    throw const ApiException(404, 'no such route');
  }
}

void main() {
  late FakeApi api;
  late GrigriStore store;

  setUp(() async {
    api = sampleApi();
    store = storeFor(api);
    await store.start();
  });

  tearDown(() => store.dispose());

  group('the regular refresh', () {
    test('is one request with my plans, requests and notifications', () async {
      api.ask('my-gym', 'kit');
      api.calls.clear();
      await store.refreshUpdates();
      expect(api.calls, ['GET /api/updates']);
      expect(store.myPlans.map((p) => p.id), contains('my-gym'));
      expect(
        store.toReview.map((r) => r.climberId),
        unorderedEquals(['jules', 'kit']),
      );
      expect(store.unreadNotices, 2);
      expect(store.climber('kit').name, kit.name);
    });

    test('keeps the notifications it has while they are unchanged, and '
        'brings new ones', () async {
      await store.refreshUpdates();
      final before = store.notices;
      expect(before, isNotEmpty);
      await store.refreshUpdates();
      expect(store.notices, before);
      await store.refreshNotices();
      expect(store.notices, before);
      api.ask('my-gym', 'sasha');
      await store.refreshUpdates();
      expect(store.notices, hasLength(before.length + 1));
    });

    test(
      'marking read that fails brings back the server\'s unread ones',
      () async {
        await store.refreshUpdates();
        expect(store.unreadNotices, 1);
        api.failNext = const ApiException(500, 'down');
        await store.readNotices();
        expect(store.unreadNotices, 0);
        await store.refreshUpdates();
        expect(store.unreadNotices, 1);
        await store.readNotices();
        await store.refreshUpdates();
        expect(store.unreadNotices, 0);
      },
    );

    test('an older server: the three routes', () async {
      final older = OlderApi();
      final seeded = sampleApi();
      older
        ..meId = seeded.meId
        ..climbers.addAll(seeded.climbers)
        ..plans.addAll(seeded.plans);
      older.ask('my-gym', 'jules');
      final oldStore = storeFor(older);
      addTearDown(oldStore.dispose);
      await oldStore.start();
      older.calls.clear();
      await oldStore.refreshUpdates();
      expect(
        older.calls,
        unorderedEquals([
          'GET /api/updates',
          'GET /api/plans',
          'GET /api/requests',
          'GET /api/notices',
        ]),
      );
      expect(oldStore.toReview.single.climberId, 'jules');
      older.calls.clear();
      await oldStore.refreshUpdates();
      expect(older.calls, isNot(contains('GET /api/updates')));
      // Chats too: each chat's own route (the server was found older).
      older.calls.clear();
      await oldStore.refreshChats();
      expect(older.calls, isNot(contains('GET /api/chats/messages')));
      expect(older.calls, contains('GET /api/plans/my-gym/messages'));
      expect(oldStore.messages('my-gym'), isNotEmpty);
    });
  });

  group("Chats' refresh", () {
    setUp(() {
      api.plans['crag-day'] = api.plans['crag-day']!.copyWith(
        memberIds: ['robin', 'me'],
      );
    });

    test('is one request for every chat, then only what is new', () async {
      api.say('crag-day', 'robin', 'Rope is packed');
      await store.refreshUpdates();
      api.calls.clear();
      await store.refreshChats();
      final chatCalls = [
        for (final c in api.calls)
          if (c.contains('messages') && !c.contains('/team/')) c,
      ];
      // (The team chat keeps its own route.)
      expect(chatCalls, ['GET /api/chats/messages']);
      expect(
        store.messages('crag-day').map((m) => m.text),
        contains('Rope is packed'),
      );
      expect(
        store.messages('my-gym').map((m) => m.text),
        contains('${jules.name} asked to join'),
      );
      expect(store.messagePolls('crag-day'), 1);
      expect(store.messagePolls('my-gym'), 1);
      api.say('crag-day', 'robin', 'See you at nine');
      await store.refreshChats();
      expect(
        store
            .messages('crag-day')
            .map((m) => m.text)
            .toList()
            .sublist(store.messages('crag-day').length - 2),
        ['Rope is packed', 'See you at nine'],
      );
      expect(store.messagePolls('crag-day'), 2);
    });

    test('an open chat polls its own route still', () async {
      await store.refreshUpdates();
      api.calls.clear();
      await store.pollMessages('crag-day');
      expect(api.calls, ['GET /api/plans/crag-day/messages']);
    });
  });
}
