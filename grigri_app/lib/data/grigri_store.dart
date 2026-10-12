import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/plan.dart';
import 'seed.dart';
import 'storage.dart';

/// How a made-up climber answers join requests for plans they're in, until
/// there's a backend with real people deciding: see specs/matching.md.
enum Policy {
  /// Accepts everyone.
  acceptsAll,

  /// Accepts newcomers whose grades for the plan's discipline overlap the
  /// plan's grades; turns down the rest.
  acceptsMatchingGrades,

  /// Never decides: the request waits.
  undecided,

  /// Turns everyone down.
  rejectsAll,
}

/// Everything the app knows, as one serializable value.
class GrigriState {
  GrigriState({
    required this.meId,
    required this.climbers,
    required this.plans,
    required this.requests,
    required this.messages,
    required this.policies,
    Set<String>? passed,
    List<Notice>? notices,
  }) : passed = passed ?? {},
       notices = notices ?? [];

  final String meId;
  final Map<String, Climber> climbers;
  final Map<String, Plan> plans;

  /// Join requests by [JoinRequest.id].
  final Map<String, JoinRequest> requests;
  final List<Message> messages;

  /// How each made-up climber decides; never set for [meId].
  final Map<String, Policy> policies;

  /// Plans I swiped left on, or whose "no" I dismissed.
  final Set<String> passed;

  /// My notifications, oldest first.
  final List<Notice> notices;

  Map<String, Object> toJson() => {
    'meId': meId,
    'climbers': [for (final c in climbers.values) c.toJson()],
    'plans': [for (final p in plans.values) p.toJson()],
    'requests': [for (final r in requests.values) r.toJson()],
    'messages': [for (final m in messages) m.toJson()],
    'policies': {for (final e in policies.entries) e.key: e.value.name},
    'passed': passed.toList(),
    'notices': [for (final n in notices) n.toJson()],
  };

  static GrigriState fromJson(Map<String, Object?> json) {
    List<Map<String, Object?>> list(String key) => [
      for (final e in json[key]! as List) (e as Map).cast(),
    ];
    return GrigriState(
      meId: json['meId']! as String,
      climbers: {
        for (final c in list('climbers').map(Climber.fromJson)) c.id: c,
      },
      plans: {for (final p in list('plans').map(Plan.fromJson)) p.id: p},
      requests: {
        for (final r in list('requests').map(JoinRequest.fromJson)) r.id: r,
      },
      messages: list('messages').map(Message.fromJson).toList(),
      policies: {
        for (final e in (json['policies']! as Map).entries)
          e.key as String: Policy.values.byName(e.value as String),
      },
      passed: {for (final p in json['passed'] as List? ?? []) p as String},
      notices: [
        for (final n in json['notices'] as List? ?? [])
          Notice.fromJson((n as Map).cast()),
      ],
    );
  }
}

/// A newcomer joined a plan I'm in, or I joined one: the match screen
/// shows it.
class Match {
  const Match({required this.plan, required this.newcomer});

  final Plan plan;
  final Climber newcomer;
}

/// The app's state and rules: the decks, swipes, matches, plans, the
/// profile and the group chats. Matching works on the device for now
/// (specs/matching.md); a backend would take its place behind this API.
class GrigriStore extends ChangeNotifier {
  GrigriStore(
    this._state, {
    this._storage,
    DateTime Function()? clock,
    this.answerAfter = Duration.zero,
  }) : _clock = clock ?? DateTime.now;

  /// The saved state, or the demo data when there's none (or it can't be
  /// read).
  static Future<GrigriStore> load({Storage? storage}) async {
    final store = storage ?? await Storage.open();
    GrigriState? state;
    final saved = store.read();
    if (saved != null) {
      try {
        state = GrigriState.fromJson((jsonDecode(saved) as Map).cast());
      } on Object catch (e) {
        debugPrint('grigri: saved state unreadable, starting over: $e');
      }
    }
    return GrigriStore(
      state ?? demoState(DateTime.now()),
      storage: store,
      answerAfter: const Duration(seconds: 10),
    );
  }

  GrigriState _state;
  final Storage? _storage;
  final DateTime Function() _clock;

  /// How long the made-up climbers take to answer a request, so it shows
  /// as pending first. [settle] applies their answers once it's up.
  final Duration answerAfter;

  /// Whether [_settle] changed anything.
  bool _touched = false;

  GrigriState get state => _state;
  Climber get me => _state.climbers[_state.meId]!;
  Climber climber(String id) => _state.climbers[id]!;
  Plan? plan(String id) => _state.plans[id];

  // --- Decks -------------------------------------------------------------

  /// Plans to swipe on: upcoming, with a spot open, that I'm not in and
  /// haven't swiped on yet, best fits first.
  List<Plan> get discover {
    final now = _clock();
    final plans = _state.plans.values.where(
      (p) =>
          p.start.isAfter(now) &&
          !p.isFull &&
          !p.memberIds.contains(me.id) &&
          !_state.passed.contains(p.id) &&
          !_state.requests.containsKey(_requestId(p.id, me.id)),
    );
    return plans.toList()..sort((a, b) {
      final byFit = fit(b).score.compareTo(fit(a).score);
      return byFit != 0 ? byFit : a.start.compareTo(b.start);
    });
  }

  /// People asking to join plans I'm in, that I haven't answered yet.
  List<JoinRequest> get toReview => [
    for (final r in _state.requests.values)
      if (!r.rejected &&
          !r.acceptedBy.contains(me.id) &&
          (_state.plans[r.planId]?.memberIds.contains(me.id) ?? false) &&
          !_state.plans[r.planId]!.memberIds.contains(r.climberId))
        r,
  ];

  /// People asking to join a plan: not turned down and not in it yet.
  /// Empty when the plan is gone.
  List<JoinRequest> asking(String planId) {
    final plan = _state.plans[planId];
    if (plan == null) return const [];
    return [
      for (final r in _state.requests.values)
        if (r.planId == planId &&
            !r.rejected &&
            !plan.memberIds.contains(r.climberId))
          r,
    ];
  }

  /// [toReview] for one plan: who asking to join it still needs my answer.
  /// Empty when I'm not in it.
  List<JoinRequest> toReviewIn(String planId) {
    if (!(_state.plans[planId]?.memberIds.contains(me.id) ?? false)) {
      return const [];
    }
    return [
      for (final r in asking(planId))
        if (!r.acceptedBy.contains(me.id)) r,
    ];
  }

  /// My swipes right still waiting for members to decide.
  List<JoinRequest> get waiting => [
    for (final r in _state.requests.values)
      if (r.climberId == me.id &&
          !r.rejected &&
          !(_state.plans[r.planId]?.memberIds.contains(me.id) ?? true))
        r,
  ];

  /// My swipes right that a group turned down, until I dismiss them.
  List<JoinRequest> get declined => [
    for (final r in _state.requests.values)
      if (r.climberId == me.id &&
          r.rejected &&
          _state.plans.containsKey(r.planId) &&
          !_state.passed.contains(r.planId))
        r,
  ];

  /// My notifications, newest first.
  List<Notice> get notices => _state.notices.reversed.toList();

  int get unreadNotices => _state.notices.where((n) => !n.read).length;

  /// Plans I'm in (organizing or joined), soonest first.
  List<Plan> get myPlans =>
      _state.plans.values.where((p) => p.memberIds.contains(me.id)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// Why a plan suits me.
  Fit fit(Plan plan) {
    final level = me.levels[plan.discipline];
    return Fit(
      grades: level != null && level.overlaps(plan.grades),
      time: me.availability.contains(Slot.at(plan.start)),
      place: me.places.any((p) => p.toLowerCase() == plan.place.toLowerCase()),
    );
  }

  // --- Swiping -----------------------------------------------------------

  /// I swipe right on a plan: I ask to join it. Its members decide; when
  /// they all accept, I join and get a [Match].
  Match? like(String planId) {
    final plan = _state.plans[planId]!;
    final request = JoinRequest(
      planId: planId,
      climberId: me.id,
      time: _clock(),
    );
    _state.requests[request.id] = request;
    final match = _settle(plan.id);
    _changed();
    return match.where((m) => m.newcomer.id == me.id).firstOrNull;
  }

  /// I swipe left on a plan: it leaves my deck.
  void pass(String planId) {
    _state.passed.add(planId);
    _changed();
  }

  /// I accept someone into a plan I'm in. When every member has accepted,
  /// they join, and I get a [Match].
  Match? accept(String requestId) {
    final request = _state.requests[requestId]!;
    _state.requests[requestId] = request.copyWith(
      acceptedBy: {...request.acceptedBy, me.id},
    );
    final matches = _settle(request.planId);
    _changed();
    return matches.where((m) => m.newcomer.id == request.climberId).firstOrNull;
  }

  /// I turn someone down for a plan I'm in: one "no" is enough.
  void reject(String requestId) {
    _state.requests[requestId] = _state.requests[requestId]!.copyWith(
      rejected: true,
    );
    _changed();
  }

  /// I clear a group's "no" from my plans; the plan stays out of my deck.
  void dismiss(String requestId) {
    final request = _state.requests.remove(requestId)!;
    _state.passed.add(request.planId);
    _changed();
  }

  /// Marks my notifications read.
  void readNotices() {
    if (unreadNotices == 0) return;
    for (final (i, n) in _state.notices.indexed) {
      _state.notices[i] = n.copyWith(read: true);
    }
    _changed();
  }

  /// Applies the made-up members' answers that are due, to every plan with
  /// open requests. Returns the notifications they made for me.
  List<Notice> settle() {
    final before = _state.notices.length;
    _touched = false;
    final planIds = {
      for (final r in _state.requests.values)
        if (!r.rejected && _state.plans.containsKey(r.planId)) r.planId,
    };
    for (final planId in planIds) {
      _settle(planId);
    }
    if (_touched) _changed();
    return _state.notices.sublist(before);
  }

  /// Applies the made-up members' decisions to a plan's open requests and
  /// adds whoever every member has accepted, until nothing changes (each
  /// newcomer must then accept the requests still open). Returns who
  /// joined.
  List<Match> _settle(String planId) {
    final joined = <Match>[];
    var changed = true;
    while (changed) {
      changed = false;
      final plan = _state.plans[planId]!;
      for (final request in _state.requests.values.toList()) {
        if (request.planId != planId ||
            request.rejected ||
            plan.memberIds.contains(request.climberId)) {
          continue;
        }
        var r = request;
        for (final memberId in plan.memberIds) {
          if (r.acceptedBy.contains(memberId)) continue;
          switch (_decide(memberId, r, plan)) {
            case true:
              r = r.copyWith(acceptedBy: {...r.acceptedBy, memberId});
            case false:
              r = r.copyWith(rejected: true);
            case null:
              break;
          }
          if (r.rejected) break;
        }
        if (!identical(r, request)) {
          _state.requests[r.id] = r;
          _touched = true;
          if (r.rejected) _notify(NoticeKind.declined, r);
        }
        if (!r.rejected &&
            !plan.isFull &&
            plan.memberIds.every(r.acceptedBy.contains)) {
          final grown = plan.copyWith(
            memberIds: [...plan.memberIds, r.climberId],
          );
          _state.plans[planId] = grown;
          _note(planId, '${climber(r.climberId).name} joined the plan 🎉');
          joined.add(Match(plan: grown, newcomer: climber(r.climberId)));
          _notify(NoticeKind.accepted, r);
          _touched = true;
          changed = true;
          break;
        }
      }
    }
    return joined;
  }

  /// Tells me when a group answered my request.
  void _notify(NoticeKind kind, JoinRequest request) {
    if (request.climberId != me.id) return;
    _state.notices.add(
      Notice(
        kind: kind,
        planId: request.planId,
        planTitle: _state.plans[request.planId]!.title,
        time: _clock(),
      ),
    );
  }

  /// A made-up member's answer: true, false, or null (not yet). I answer
  /// for myself, in the Requests deck or on the plan.
  bool? _decide(String memberId, JoinRequest request, Plan plan) {
    if (memberId == me.id) return null;
    final asked = request.time;
    if (asked != null && _clock().difference(asked) < answerAfter) return null;
    switch (_state.policies[memberId] ?? Policy.undecided) {
      case Policy.acceptsAll:
        return true;
      case Policy.rejectsAll:
        return false;
      case Policy.undecided:
        return null;
      case Policy.acceptsMatchingGrades:
        final level = climber(request.climberId).levels[plan.discipline];
        return level != null && level.overlaps(plan.grades);
    }
  }

  String _requestId(String planId, String climberId) => '$planId/$climberId';

  // --- Plans -------------------------------------------------------------

  /// A new plan, organized by me.
  Plan createPlan({
    required String title,
    required Discipline discipline,
    required String place,
    required String area,
    required DateTime start,
    required int hours,
    required GradeRange grades,
    required int spots,
    String notes = '',
  }) {
    final plan = Plan(
      id: 'plan-${_clock().microsecondsSinceEpoch}',
      organizerId: me.id,
      title: title,
      discipline: discipline,
      place: place,
      area: area,
      start: start,
      hours: hours,
      grades: grades,
      spots: spots,
      memberIds: [me.id],
      notes: notes,
    );
    _state.plans[plan.id] = plan;
    _note(plan.id, 'You created the plan. People who match will show up here.');
    _changed();
    return plan;
  }

  /// Saves my changes to a plan I organize (never its members).
  void updatePlan(Plan plan) {
    final current = _state.plans[plan.id]!;
    assert(current.organizerId == me.id);
    _state.plans[plan.id] = plan.copyWith(memberIds: current.memberIds);
    _changed();
  }

  /// I leave a plan's group. When the organizer leaves, the next member
  /// organizes it; when the last member leaves, the plan is gone.
  void leave(String planId) {
    final plan = _state.plans[planId]!;
    final members = [...plan.memberIds]..remove(me.id);
    if (members.isEmpty) {
      _state.plans.remove(planId);
      _state.requests.removeWhere((_, r) => r.planId == planId);
      _state.messages.removeWhere((m) => m.planId == planId);
    } else {
      _state.plans[planId] = Plan(
        id: plan.id,
        organizerId: plan.organizerId == me.id
            ? members.first
            : plan.organizerId,
        title: plan.title,
        discipline: plan.discipline,
        place: plan.place,
        area: plan.area,
        start: plan.start,
        hours: plan.hours,
        grades: plan.grades,
        spots: plan.spots,
        memberIds: members,
        notes: plan.notes,
      );
      _note(planId, '${me.name} left the plan');
      // One fewer member to wait for.
      _settle(planId);
    }
    _state.passed.add(planId);
    _changed();
  }

  // --- Profile -----------------------------------------------------------

  void updateProfile(Climber profile) {
    assert(profile.id == me.id);
    _state.climbers[me.id] = profile;
    _changed();
  }

  // --- Chat --------------------------------------------------------------

  /// A plan's group chat, oldest first.
  List<Message> messages(String planId) =>
      _state.messages.where((m) => m.planId == planId).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  void send(String planId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _state.messages.add(
      Message(planId: planId, authorId: me.id, text: trimmed, time: _clock()),
    );
    _changed();
  }

  void _note(String planId, String text) => _state.messages.add(
    Message(planId: planId, authorId: null, text: text, time: _clock()),
  );

  // --- Storage -----------------------------------------------------------

  /// Back to the demo data.
  void reset() {
    _state = demoState(_clock());
    _changed();
  }

  void _changed() {
    notifyListeners();
    _storage?.write(jsonEncode(_state.toJson()));
  }
}

/// How a plan fits my profile.
class Fit {
  const Fit({required this.grades, required this.time, required this.place});

  /// My grades for its discipline overlap its grades.
  final bool grades;

  /// It's at a time I like to climb.
  final bool time;

  /// It's at one of my places.
  final bool place;

  int get score => (grades ? 2 : 0) + (time ? 1 : 0) + (place ? 1 : 0);
}
