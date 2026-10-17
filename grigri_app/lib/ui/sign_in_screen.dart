import 'dart:async';

import 'package:flutter/material.dart';

import '../app_version.dart';
import '../data/auth.dart';
import '../data/grigri_store.dart';
import '../model/pics.dart';
import '../theme.dart';
import 'common.dart';
import 'google_button/google_button.dart';

/// The sign-in screen, in the landing page's look (specs/sign-in.md,
/// specs/landing.md): a GriGri Pics photo edge to edge, the headline and
/// the sign-in buttons (Google's first, its own on the web; then Sign in
/// with Apple, as prominent, in Apple's white style), a demo plan card
/// swiping right, how it works, what's free,
/// and a last call.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _heroKey = GlobalKey();
  bool _busy = false;

  /// The hero's photo and the demo cards', from GriGri Pics' catalog; none
  /// until it loads, or when it can't be read.
  GrigriPic? _heroPic;
  List<GrigriPic> _cardPics = const [];

  @override
  void initState() {
    super.initState();
    _loadPics();
  }

  Future<void> _loadPics() async {
    final store = StoreScope.read(context);
    final List<GrigriPic> catalog;
    try {
      catalog = await store.api.picsCatalog();
    } catch (_) {
      return; // No photos: the screen works without them.
    }
    if (!mounted || catalog.isEmpty) return;
    // The first photo of the first crag for the hero, and one photo each
    // of up to three other crags for the demo cards (the hero's crag last).
    final firsts = <String, GrigriPic>{};
    for (final pic in catalog) {
      firsts.putIfAbsent(pic.crag, () => pic);
    }
    final crags = firsts.values.toList();
    setState(() {
      _heroPic = catalog.first;
      _cardPics = [...crags.skip(1), ...crags.take(1)].take(3).toList();
    });
  }

  Future<void> _signIn(Future<void> Function() signIn) async {
    setState(() => _busy = true);
    await signIn();
    if (mounted) setState(() => _busy = false);
  }

  /// The last call's button: signs in, or on the web (where only Google's
  /// button can) scrolls back up to it.
  void _join(Auth auth) {
    if (auth.mode == SignInMode.googleWebButton) {
      final hero = _heroKey.currentContext;
      if (hero != null) {
        Scrollable.ensureVisible(
          hero,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    } else if (!_busy) {
      _signIn(auth.signIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final auth = store.auth;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(
                key: _heroKey,
                photo: _heroPic == null ? null : store.grigriPic(_heroPic!.key),
                credit: _heroPic == null || _heroPic!.author.isEmpty
                    ? null
                    : l.signInPhotoBy(_heroPic!.author, _heroPic!.license),
                copy: _HeroCopy(
                  button: _signInButton(auth),
                  error: switch (auth.error) {
                    SignInError.session => l.errorSession,
                    SignInError.google => l.errorSignIn,
                    SignInError.apple => l.errorSignInApple,
                    null => null,
                  },
                ),
                deck: _DemoDeck(plans: _demoPlans(store)),
              ),
              const _Section(child: _HowItWorks()),
              const _Section(child: _Free()),
              _Section(
                child: _FinalCall(onJoin: _busy ? null : () => _join(auth)),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }

  /// The demo cards: three made-up plans, at the catalog's crags (or, with
  /// no catalog, at three well-known ones, without photos).
  List<_DemoPlan> _demoPlans(GrigriStore store) {
    final l = context.l10n;
    const crags = ['Siurana', 'Margalef', 'Montserrat'];
    final details = [
      (l.signInDeckWhen, l.signInDeckWho),
      (l.signInDeckWhen2, l.signInDeckWho2),
      (l.signInDeckWhen3, l.signInDeckWho3),
    ];
    return [
      for (final (i, (day, who)) in details.indexed)
        if (_cardPics.isEmpty)
          _DemoPlan(crag: crags[i], when: day, who: who)
        else
          _DemoPlan(
            photo: store.grigriPic(_cardPics[i % _cardPics.length].key),
            crag: _cardPics[i % _cardPics.length].crag,
            when: day,
            who: who,
          ),
    ];
  }

  Widget _signInButton(Auth auth) {
    final google = switch (auth.mode) {
      SignInMode.google => _GoogleButton(
        label: context.l10n.signInWithGoogle,
        onPressed: _busy ? null : () => _signIn(auth.signIn),
      ),
      SignInMode.googleWebButton => SizedBox(
        height: 50,
        child: googleWebButton(),
      ),
    };
    if (!auth.appleAvailable) return google;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        google,
        const SizedBox(height: 12),
        _AppleButton(
          label: context.l10n.signInWithApple,
          onPressed: _busy ? null : () => _signIn(auth.signInWithApple),
        ),
      ],
    );
  }
}

/// Wider than this, the hero's copy and the demo card sit side by side.
const _wide = 820.0;

/// The top of the screen: the photo edge to edge under a shade, the bar,
/// the copy and the demo card.
class _Hero extends StatelessWidget {
  const _Hero({
    super.key,
    required this.photo,
    required this.credit,
    required this.copy,
    required this.deck,
  });

  final ImageProvider? photo;
  final String? credit;
  final Widget copy;
  final Widget deck;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height * 0.9),
      child: Stack(
        children: [
          Positioned.fill(
            child: photo == null
                ? const ColoredBox(color: Mountain.night)
                : Image(
                    image: photo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Mountain.night),
                  ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99161A16),
                    Color(0xB3161A16),
                    Mountain.night,
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _Bar(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: size.width >= _wide
                          ? Row(
                              children: [
                                Expanded(child: copy),
                                const SizedBox(width: 48),
                                deck,
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                copy,
                                const SizedBox(height: 40),
                                Center(child: deck),
                              ],
                            ),
                    ),
                  ),
                ),
                if (credit != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      credit!,
                      style: const TextStyle(
                        color: Mountain.granite,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
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

/// The logo and the app's name.
class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/logo.png', width: 32, height: 32),
        ),
        const SizedBox(width: 10),
        Text(
          AppVersion.title,
          style: const TextStyle(
            color: Mountain.sand,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// The headline, the tagline and the sign-in buttons.
class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.button, required this.error});

  final Widget button;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.signInHeadline,
          style: (wide ? text.displayMedium : text.displaySmall)?.copyWith(
            color: Mountain.snow,
            fontWeight: FontWeight.w800,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.signInTagline,
          style: text.titleMedium?.copyWith(color: Mountain.sand, height: 1.4),
        ),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: button,
        ),
        const SizedBox(height: 12),
        Text(
          l.signInFreeLine,
          style: text.bodySmall?.copyWith(color: Mountain.granite),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Mountain.clay)),
        ],
      ],
    );
  }
}

/// The app's own Google button (not on the web): a light pill with
/// Google's "G".
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      icon: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Mountain.snow,
        foregroundColor: Mountain.night,
        disabledBackgroundColor: Mountain.granite,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
    ),
  );
}

/// Sign in with Apple in Apple's white style: the Apple logo and Apple's
/// wording on a white pill, as tall as Google's button. The label is 16
/// px and stays on one line, shrinking to fit a narrow screen.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Mountain.granite,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apple, size: 20),
            const SizedBox(width: 6),
            Text(label, maxLines: 1, softWrap: false),
          ],
        ),
      ),
    ),
  );
}

/// A made-up plan on the demo deck.
class _DemoPlan {
  const _DemoPlan({
    this.photo,
    required this.crag,
    required this.when,
    required this.who,
  });

  final ImageProvider? photo;
  final String crag;
  final String when;
  final String who;
}

/// Plan cards that swipe right on a loop, one after another, with a JOIN
/// stamp, like the Discover deck. Still (on the first plan) when the
/// device asks for less motion.
class _DemoDeck extends StatefulWidget {
  const _DemoDeck({required this.plans});

  final List<_DemoPlan> plans;

  @override
  State<_DemoDeck> createState() => _DemoDeckState();
}

/// Where the demo card is in its loop.
enum _Swipe { resting, stamped, gone }

class _DemoDeckState extends State<_DemoDeck> {
  _Swipe _swipe = _Swipe.resting;
  Timer? _timer;

  /// The plan on top: it moves on each time a card has swiped away.
  int _at = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = null;
    if (MediaQuery.disableAnimationsOf(context)) {
      _swipe = _Swipe.resting;
      _at = 0;
    } else {
      _next(_Swipe.resting);
    }
  }

  /// Shows [swipe], then moves on after it has been on screen a while.
  void _next(_Swipe swipe) {
    _timer = Timer(
      switch (swipe) {
        _Swipe.resting => const Duration(milliseconds: 2200),
        _Swipe.stamped => const Duration(milliseconds: 700),
        _Swipe.gone => const Duration(milliseconds: 600),
      },
      () {
        if (!mounted) return;
        final next = _Swipe.values[(swipe.index + 1) % _Swipe.values.length];
        setState(() {
          _swipe = next;
          if (next == _Swipe.resting) _at++;
        });
        _next(next);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plan = widget.plans[_at % widget.plans.length];
    // Back from "gone", the next card fades in at once in place.
    final moving = _swipe != _Swipe.resting;
    final duration = Duration(milliseconds: moving ? 500 : 0);
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          SizedBox(
            height: 380,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Transform.rotate(
                    angle: -0.06,
                    child: Transform.scale(
                      scale: 0.94,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Mountain.surfaceHigh,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSlide(
                    offset: Offset(_swipe == _Swipe.gone ? 1.4 : 0, 0),
                    duration: duration,
                    curve: Curves.easeIn,
                    child: AnimatedRotation(
                      turns: switch (_swipe) {
                        _Swipe.resting => 0,
                        _Swipe.stamped => 0.012,
                        _Swipe.gone => 0.05,
                      },
                      duration: duration,
                      child: AnimatedOpacity(
                        opacity: _swipe == _Swipe.gone ? 0 : 1,
                        duration: _swipe == _Swipe.resting
                            ? const Duration(milliseconds: 300)
                            : duration,
                        child: _DemoCard(
                          plan: plan,
                          stamp: l.signInStampJoin,
                          stamped: _swipe != _Swipe.resting,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Round(icon: Icons.close, color: Mountain.clay),
              SizedBox(width: 24),
              _Round(icon: Icons.check, color: Mountain.olive),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.plan,
    required this.stamp,
    required this.stamped,
  });

  final _DemoPlan plan;
  final String stamp;
  final bool stamped;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (plan.photo == null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Mountain.pine, Color(0xFF4A3B2A)],
                ),
              ),
            )
          else
            Image(
              image: plan.photo!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Mountain.pine),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE6161A16)],
                stops: [0.45, 1],
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 20,
            child: AnimatedOpacity(
              opacity: stamped ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Transform.rotate(
                angle: -0.3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Mountain.olive, width: 3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      stamp,
                      style: const TextStyle(
                        color: Mountain.olive,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.crag,
                  style: const TextStyle(
                    color: Mountain.snow,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(plan.when, style: const TextStyle(color: Mountain.sand)),
                const SizedBox(height: 2),
                Text(plan.who, style: const TextStyle(color: Mountain.granite)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: Mountain.surface,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2),
    ),
    child: Icon(icon, color: color),
  );
}

/// A section below the hero, centered and as wide as reads well.
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1080),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: child,
      ),
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.headlineMedium
        ?.copyWith(color: Mountain.sand, fontWeight: FontWeight.w800),
  );
}

/// The three steps: make a plan, swipe right, climb together.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [
      ('🗓️', l.signInStep1Title, l.signInStep1Body),
      ('👉', l.signInStep2Title, l.signInStep2Body),
      ('🧗', l.signInStep3Title, l.signInStep3Body),
    ];
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final cards = [
      for (final (icon, title, body) in steps)
        _StepCard(icon: icon, title: title, body: body),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l.signInHowTitle),
        const SizedBox(height: 20),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, card) in cards.indexed) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: card),
                ],
              ],
            ),
          )
        else
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            card,
          ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Mountain.snow,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: Mountain.granite, height: 1.4),
          ),
        ],
      ),
    ),
  );
}

/// What's free, and what Premium is for.
class _Free extends StatelessWidget {
  const _Free();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(l.signInFreeTitle),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in [
              l.signInFree1,
              l.signInFree2,
              l.signInFree3,
              l.signInFree4,
            ])
              Chip(
                avatar: const Icon(Icons.check, color: Mountain.olive),
                label: Text(item),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l.signInFreePremium,
          style: const TextStyle(color: Mountain.granite, height: 1.4),
        ),
      ],
    );
  }
}

/// The last call: "Join free with Google".
class _FinalCall extends StatelessWidget {
  const _FinalCall({required this.onJoin});

  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Mountain.pine, Color(0xFF2B4152)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            Text(
              l.signInFinalTitle,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: Mountain.snow, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _GoogleButton(label: l.signInJoinFree, onPressed: onJoin),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
    child: SafeArea(
      top: false,
      child: Text(
        AppVersion.title,
        style: const TextStyle(color: Mountain.granite, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
