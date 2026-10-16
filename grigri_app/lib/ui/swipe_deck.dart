import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Swipes the deck's top card from outside it: the deck's buttons.
class SwipeController {
  _SwipeDeckState<Object?>? _deck;

  /// Throws the top card right (yes) or left (no).
  void swipe({required bool right}) => _deck?._fling(right: right);
}

/// A stack of cards: drag the top one right for yes, left for no, as in
/// dating apps. The next card waits underneath. The owner removes the
/// swiped item from [items] in [onSwiped].
class SwipeDeck<T> extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.items,
    required this.keyOf,
    required this.builder,
    required this.onSwiped,
    required this.yesLabel,
    required this.noLabel,
    this.labelsOf,
    this.controller,
  });

  final List<T> items;
  final String Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) builder;
  final void Function(T item, {required bool right}) onSwiped;

  /// The stamps shown while dragging, e.g. "JOIN" and "PASS".
  final String yesLabel;
  final String noLabel;

  /// Other stamps for some cards (an ad's "OPEN" and "SKIP"); null keeps
  /// [yesLabel] and [noLabel].
  final (String yes, String no)? Function(T item)? labelsOf;
  final SwipeController? controller;

  @override
  State<SwipeDeck<T>> createState() => _SwipeDeckState<T>();
}

class _SwipeDeckState<T> extends State<SwipeDeck<T>>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Offset _drag = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool? _leaving;
  double _width = 400;

  @override
  void initState() {
    super.initState();
    widget.controller?._deck = this as _SwipeDeckState<Object?>;
    _animation.addListener(() {
      setState(() {
        _drag = Offset.lerp(
          _from,
          _to,
          Curves.easeOut.transform(_animation.value),
        )!;
      });
    });
    _animation.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      final leaving = _leaving;
      _leaving = null;
      if (leaving != null && widget.items.isNotEmpty) {
        final item = widget.items.first;
        setState(() => _drag = Offset.zero);
        widget.onSwiped(item, right: leaving);
      }
    });
  }

  @override
  void didUpdateWidget(SwipeDeck<T> old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._deck = null;
      widget.controller?._deck = this as _SwipeDeckState<Object?>;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._deck == this) widget.controller?._deck = null;
    _animation.dispose();
    super.dispose();
  }

  void _animateTo(Offset target, {bool? leaving}) {
    _from = _drag;
    _to = target;
    _leaving = leaving;
    _animation.forward(from: 0);
  }

  void _fling({required bool right}) {
    if (widget.items.isEmpty || _animation.isAnimating) return;
    _animateTo(
      Offset((right ? 1 : -1) * _width * 1.5, _drag.dy + 40),
      leaving: right,
    );
  }

  void _end(DragEndDetails details) {
    final vx = details.velocity.pixelsPerSecond.dx;
    if (_drag.dx.abs() > _width * 0.28 || vx.abs() > 900) {
      final right = (_drag.dx.abs() > _width * 0.28 ? _drag.dx : vx) > 0;
      _fling(right: right);
    } else {
      _animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final items = widget.items;
        final progress = (_drag.dx / (_width * 0.28)).clamp(-1.0, 1.0);
        final labels = items.isEmpty
            ? null
            : widget.labelsOf?.call(items.first);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (items.length > 1)
              Positioned.fill(
                key: ValueKey('next-${widget.keyOf(items[1])}'),
                child: Transform.scale(
                  scale: 0.95 + 0.05 * progress.abs(),
                  child: Opacity(
                    opacity: 0.6 + 0.4 * progress.abs(),
                    child: IgnorePointer(
                      child: widget.builder(context, items[1]),
                    ),
                  ),
                ),
              ),
            if (items.isNotEmpty)
              Positioned.fill(
                key: ValueKey('top-${widget.keyOf(items.first)}'),
                child: GestureDetector(
                  onPanUpdate: _animation.isAnimating
                      ? null
                      : (d) => setState(() => _drag += d.delta),
                  onPanEnd: _animation.isAnimating ? null : _end,
                  child: Transform.translate(
                    offset: _drag,
                    child: Transform.rotate(
                      angle: _drag.dx / _width * (math.pi / 10),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: widget.builder(context, items.first),
                          ),
                          if (progress > 0)
                            _Stamp(
                              labels?.$1 ?? widget.yesLabel,
                              Mountain.olive,
                              progress,
                              left: true,
                            ),
                          if (progress < 0)
                            _Stamp(
                              labels?.$2 ?? widget.noLabel,
                              Mountain.clay,
                              -progress,
                              left: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// "JOIN" or "PASS", stamped on the card as it's dragged.
class _Stamp extends StatelessWidget {
  const _Stamp(this.label, this.color, this.strength, {required this.left});

  final String label;
  final Color color;
  final double strength;
  final bool left;

  @override
  Widget build(BuildContext context) => Positioned(
    top: 28,
    left: left ? 24 : null,
    right: left ? null : 24,
    child: Opacity(
      opacity: strength,
      child: Transform.rotate(
        angle: (left ? -1 : 1) * 0.25,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Mountain.night.withValues(alpha: 0.6),
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    ),
  );
}
