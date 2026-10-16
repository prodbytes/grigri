import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../data/grigri_store.dart';
import '../model/climbing.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';
import 'match_score.dart';
import 'profile_editor.dart';
import 'swipe_deck.dart';

/// The plans deck: swipe right (or tap ✓) to ask to join a plan, left to
/// pass. The plan comes first on each card; the people in it below.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.onCreatePlan});

  /// Opens the plan editor, when the deck runs out.
  final VoidCallback onCreatePlan;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  /// The share button: small, to the right of ✓.
  static const _shareSize = 36.0;
  static const _shareGap = 16.0;

  /// ✓ is bigger than ✕, as on dating apps.
  static const _passSize = 56.0;
  static const _joinSize = 66.0;

  final _controller = SwipeController();

  Future<void> _swiped(
    GrigriStore store,
    Plan plan, {
    required bool right,
  }) async {
    if (!right) {
      await store.pass(plan.id);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    if (!await store.like(plan.id)) return;
    // A demo plan matches at once, and the match screen says so.
    if (plan.demo) return;
    messenger.showSnackBar(SnackBar(content: Text(l.askedToJoinSent)));
  }

  /// Shares the top plan as text with the app's link, through the
  /// system's share sheet (the browser's, or copying, on the web).
  Future<void> _share(BuildContext button, Plan plan) async {
    final l = context.l10n;
    final box = button.findRenderObject() as RenderBox?;
    final text = l.sharePlanText(
      plan.discipline.label(l),
      plan.title,
      whenLabel(context, plan),
      AppConfig.origin.resolve('/app/').toString(),
    );
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: plan.title,
        // Where the sheet points from, on iPad.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final plans = store.discover;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.discoverTitle),
        actions: [
          IconButton(
            tooltip: l.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => store.refreshDiscover(again: true),
          ),
        ],
      ),
      body: !store.isLoaded(Section.discover)
          ? const Center(child: CircularProgressIndicator())
          : plans.isEmpty
          ? EmptyState(
              icon: Icons.landscape_outlined,
              title: l.noPlansToJoinTitle,
              message: l.noPlansToJoinMessage,
              action: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.newPlan),
                onPressed: widget.onCreatePlan,
              ),
            )
          : Column(
              children: [
                if (store.me.location == null &&
                    store.me.areas.isEmpty &&
                    !store.locating)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 18,
                          color: Mountain.sky,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.setWhereYouClimbHint,
                            style: const TextStyle(color: Mountain.snow),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ProfileEditor(),
                            ),
                          ),
                          child: Text(l.setAction),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: SwipeDeck<Plan>(
                          items: plans,
                          keyOf: (p) => p.id,
                          controller: _controller,
                          yesLabel: l.swipeJoin.toUpperCase(),
                          noLabel: l.swipePass.toUpperCase(),
                          onSwiped: (plan, {required right}) =>
                              _swiped(store, plan, right: right),
                          builder: (context, plan) => _PlanCard(plan: plan),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // As wide as the share button and its gap (and half
                      // what ✓ has over ✕), so ✕ and ✓ stay centered.
                      const SizedBox(
                        width:
                            _shareSize +
                            _shareGap +
                            (_joinSize - _passSize) / 2,
                      ),
                      DeckButton(
                        icon: Icons.close,
                        color: Mountain.clay,
                        tooltip: l.pass,
                        onPressed: () => _controller.swipe(right: false),
                      ),
                      const SizedBox(width: 32),
                      DeckButton(
                        icon: Icons.check,
                        color: Mountain.olive,
                        filled: true,
                        size: _joinSize,
                        tooltip: l.askToJoin,
                        onPressed: () => _controller.swipe(right: true),
                      ),
                      const SizedBox(width: _shareGap),
                      Builder(
                        builder: (context) => DeckButton(
                          icon: Icons.share_outlined,
                          color: Mountain.sky,
                          size: _shareSize,
                          tooltip: l.sharePlan,
                          onPressed: () => _share(context, plans.first),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// A plan on the deck, like a dating app's profile card: the plan's crag
/// photo (its GriGri Pics cover, or a backdrop in its discipline's colors)
/// fills the card, with the plan over it; below, always in view, its
/// organizer with how many others are in the group ("+3"), which opens
/// their list; then the notes and the organizer's profile, on scrolling.
class _PlanCard extends StatefulWidget {
  const _PlanCard({required this.plan});

  final Plan plan;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  /// The group's list, collapsed until the "+3" is tapped.
  bool _showGroup = false;

  /// What the card keeps below the photo, in view: the organizer's row.
  static const _belowPhoto = 76.0;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final organizer = store.climber(plan.organizerId);
    final others = [
      for (final id in plan.memberIds)
        if (id != organizer.id) store.climber(id),
    ];
    // A little smaller than the rest of the app, to fit more of the plan
    // and the organizer on a small phone; still following the system's
    // text size.
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: _Scaled(media.textScaler, _cardTextScale),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Mountain.surface,
            child: LayoutBuilder(
              builder: (context, box) {
                final photoHeight = (box.maxHeight - _belowPhoto).clamp(
                  220.0,
                  box.maxHeight * 0.8,
                );
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: photoHeight,
                        child: _PlanCover(plan: plan),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    showProfileSheet(context, organizer),
                                child: ClimberHeader(
                                  organizer,
                                  radius: 22,
                                  subtitle: l.organizedBy,
                                ),
                              ),
                            ),
                            if (others.isNotEmpty)
                              Tooltip(
                                message: _showGroup ? l.hideGroup : l.showGroup,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(99),
                                  onTap: () =>
                                      setState(() => _showGroup = !_showGroup),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AvatarRow(
                                          others.take(3).toList(),
                                          radius: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '+${others.length}',
                                          style: text.titleMedium?.copyWith(
                                            color: Mountain.sky,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Icon(
                                          _showGroup
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: Mountain.sky,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_showGroup && others.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                l.alsoInGroup.toUpperCase(),
                                style: text.labelSmall?.copyWith(
                                  color: Mountain.granite,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              for (final c in others)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Avatar(c),
                                  title: Text(c.nameAndAge),
                                  subtitle: Text(
                                    c.levels.entries
                                        .map(
                                          (e) =>
                                              '${e.key.label(l)} ${store.grades(e.value)}',
                                        )
                                        .join(' · '),
                                    style: const TextStyle(
                                      color: Mountain.granite,
                                    ),
                                  ),
                                  onTap: () => showProfileSheet(context, c),
                                ),
                            ],
                            if (plan.notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  8,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Mountain.olive,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  plan.notes,
                                  style: text.bodyMedium?.copyWith(
                                    color: Mountain.snow,
                                  ),
                                  // About three lines, then "…".
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            ProfileDetails(organizer, compact: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The top of a deck card: the plan's cover photo edge to edge (or, without
/// one, a backdrop in its discipline's colors), darkened at the top and
/// bottom so the plan reads over it: the discipline (and, for admins, the
/// match score) at the top; the place, area, date and time, grades and
/// whether they're mine at the bottom, with the photo's credit.
class _PlanCover extends StatelessWidget {
  const _PlanCover({required this.plan});

  final Plan plan;

  /// Each discipline's backdrop when there's no photo.
  static const _backdrops = {
    Discipline.sport: [Color(0xFF3F5C45), Color(0xFF1C2A20)],
    Discipline.trad: [Color(0xFF5A4630), Color(0xFF231C14)],
    Discipline.bouldering: [Color(0xFF2B4152), Color(0xFF151F27)],
    Discipline.gym: [Color(0xFF4A3B4F), Color(0xFF1E1822)],
  };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final cover = store.cover(plan.id);
    // Admins only: the API scores their decks.
    final match = store.matchScore(plan.id);
    final mine = store.fit(plan).grades;
    final backdrop = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backdrops[plan.discipline]!,
        ),
      ),
      // A mountain's silhouette, faint, as if behind a mist.
      child: const Align(
        alignment: Alignment(1.4, 0.2),
        child: Icon(Icons.terrain, size: 320, color: Color(0x1FFFFFFF)),
      ),
    );
    const shadow = [Shadow(color: Color(0xAA000000), blurRadius: 8)];
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover == null)
          backdrop
        else
          Image(
            key: ValueKey('cover ${plan.id}'),
            image: store.grigriPic(cover.key),
            fit: BoxFit.cover,
            // Fades in when it arrives; the backdrop until then, or if
            // it fails.
            frameBuilder: (context, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: child,
                  ),
            errorBuilder: (_, _, _) => backdrop,
          ),
        // The scrims: a little at the top, more at the bottom.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.22, 0.45, 1],
              colors: [
                Color(0x73000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xE6000000),
              ],
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Glass(
                child: Text(
                  '${plan.discipline.emoji} ${plan.discipline.label(l)}',
                  style: text.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (match != null) ...[
                MatchScoreTag(
                  match,
                  key: ValueKey('match ${plan.id}'),
                  compact: true,
                ),
                _Glass(
                  child: Text(
                    match.reason.label(l),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plan.demo) ...[const DemoNotice(), const SizedBox(height: 6)],
              Text(
                plan.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  shadows: shadow,
                ),
              ),
              const SizedBox(height: 6),
              if (plan.area.isNotEmpty)
                _OverLine(Icons.place_outlined, plan.area),
              _OverLine(Icons.event_outlined, dayLabel(context, plan.start)),
              _OverLine(Icons.schedule, timeRangeLabel(plan)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Glass(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          store.grades(plan.grades),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (mine)
                    _Glass(
                      color: Mountain.olive,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 16,
                            color: Mountain.night,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l.yourGrades,
                            style: const TextStyle(
                              color: Mountain.night,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (cover != null && cover.author.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (cover.crag.isNotEmpty) cover.crag,
                    l.picCredit(cover.author, cover.license),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A line of the plan over its photo: an icon and white text.
class _OverLine extends StatelessWidget {
  const _OverLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Icon(icon, size: 17, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Color(0xAA000000), blurRadius: 6)],
            ),
          ),
        ),
      ],
    ),
  );
}

/// A pill over the photo: dark and see-through, or in [color].
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color ?? const Color(0x66000000),
      borderRadius: BorderRadius.circular(99),
      border: color == null ? Border.all(color: const Color(0x33FFFFFF)) : null,
    ),
    child: child,
  );
}

/// How much smaller the Discover card's text is than the app's.
const _cardTextScale = 0.9;

/// The system's text scaling, then [factor] on top.
class _Scaled extends TextScaler {
  const _Scaled(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(1) * factor;

  @override
  bool operator ==(Object other) =>
      other is _Scaled && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
