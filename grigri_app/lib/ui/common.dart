import 'package:flutter/material.dart';

import '../data/grigri_store.dart';
import '../model/climber.dart';
import '../model/climbing.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'l10n.dart';

export 'l10n.dart';

/// Gives the widgets below it the [GrigriStore], rebuilding them when it
/// changes.
class StoreScope extends InheritedNotifier<GrigriStore> {
  const StoreScope({
    super.key,
    required GrigriStore store,
    required super.child,
  }) : super(notifier: store);

  static GrigriStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// The store, without rebuilding on its changes: for callbacks and
  /// initState.
  static GrigriStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

/// A climber's photo, or their initials on a color of the palette, always
/// the same one for the same person.
class Avatar extends StatelessWidget {
  const Avatar(this.climber, {super.key, this.radius = 20, this.image});

  final Climber climber;
  final double radius;

  /// The picture to show instead of their saved photo (the profile
  /// editor's, before it's uploaded).
  final ImageProvider? image;

  static const _colors = [
    Mountain.olive,
    Mountain.sky,
    Mountain.tan,
    Mountain.moss,
    Mountain.sand,
    Mountain.granite,
  ];

  @override
  Widget build(BuildContext context) {
    final color =
        _colors[climber.id.codeUnits.fold(0, (a, b) => a + b) % _colors.length];
    final photo =
        image ??
        (climber.photo == null
            ? null
            : StoreScope.of(context).photo(climber.photo!));
    if (photo != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: color,
        backgroundImage: photo,
        onBackgroundImageError: (_, _) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        climber.initials,
        style: TextStyle(
          color: Mountain.night,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// Overlapping avatars of a group.
class AvatarRow extends StatelessWidget {
  const AvatarRow(this.climbers, {super.key, this.radius = 16});

  final List<Climber> climbers;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final step = radius * 1.4;
    return SizedBox(
      height: radius * 2 + 4,
      width: climbers.isEmpty
          ? 0
          : step * (climbers.length - 1) + radius * 2 + 4,
      child: Stack(
        children: [
          for (final (i, c) in climbers.indexed)
            Positioned(
              left: i * step,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Mountain.night,
                  shape: BoxShape.circle,
                ),
                child: Avatar(c, radius: radius),
              ),
            ),
        ],
      ),
    );
  }
}

/// A small rounded label with an optional icon.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.icon, this.color});

  final String label;
  final IconData? icon;

  /// The text and icon color; the background is a faint wash of it.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Mountain.snow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color == null ? Mountain.surfaceHigh : c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
          ],
          // Long labels (the chat's notes) wrap instead of overflowing.
          Flexible(
            child: Text(label, style: TextStyle(color: c, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Says a plan or profile is made up (`demo`): not real data, just a
/// demonstration of how Grigri works.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Clear but discreet: one quiet line, not a banner.
    return Semantics(
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.auto_awesome_outlined,
              size: 14,
              color: Mountain.tan,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.demoNotice,
              style: const TextStyle(
                color: Mountain.tan,
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The plan, highlighted: what, where, when and which grades. On the
/// swipe cards, the match screen and the chat.
class PlanHighlight extends StatelessWidget {
  const PlanHighlight(
    this.plan, {
    super.key,
    this.fit,
    this.showNotes = true,
    this.compact = false,
  });

  final Plan plan;

  /// How it fits my profile, to show as badges.
  final Fit? fit;

  final bool showNotes;

  /// Tighter, for the swipe cards, to fit small phones.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B4152), Mountain.pine],
        ),
        border: Border.all(color: Mountain.sky.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.demo) ...[const DemoNotice(), const SizedBox(height: 10)],
          Row(
            children: [
              Text(
                l.thePlan.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: Mountain.sky,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${plan.discipline.emoji} ${plan.discipline.label(l)}',
                style: text.labelMedium?.copyWith(color: Mountain.sand),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            plan.title,
            style: (compact ? text.titleLarge : text.headlineSmall)?.copyWith(
              color: Mountain.sand,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          if (plan.area.isNotEmpty) _Line(Icons.place_outlined, plan.area),
          _Line(Icons.event_outlined, dayLabel(context, plan.start)),
          _Line(Icons.schedule, timeRangeLabel(plan)),
          _Line(Icons.trending_up, StoreScope.of(context).grades(plan.grades)),
          if (showNotes && plan.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plan.notes,
              style: text.bodyMedium?.copyWith(color: Mountain.snow),
            ),
          ],
          if (fit?.grades ?? false) ...[
            const SizedBox(height: 12),
            Tag(l.yourGrades, icon: Icons.check, color: Mountain.sand),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icon, size: 17, color: Mountain.sky),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(color: Mountain.snow)),
        ),
      ],
    ),
  );
}

/// A climber's profile: who they are, their grades, when and where they
/// climb, and their gear.
class ProfileDetails extends StatelessWidget {
  const ProfileDetails(this.climber, {super.key, this.compact = false});

  final Climber climber;

  /// Leaves out the gear.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    Widget heading(String label) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: text.labelSmall?.copyWith(
          color: Mountain.granite,
          letterSpacing: 1.2,
        ),
      ),
    );
    final showGear =
        !compact && (climber.gear.isNotEmpty || climber.gearPhotos.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (climber.bio.isNotEmpty) Text(climber.bio, style: text.bodyMedium),
        if (climber.levels.isNotEmpty) ...[
          heading(l.profileClimbs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in climber.levels.entries)
                Tag(
                  '${e.key.emoji} ${e.key.label(l)} ${StoreScope.of(context).grades(e.value)}',
                  color: Mountain.olive,
                ),
            ],
          ),
        ],
        if (showGear) ...[
          heading(l.profileGear),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final g in climber.gear) Tag(g.label(l))],
          ),
          if (climber.gearPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, key) in climber.gearPhotos.indexed)
                  PhotoThumb(
                    StoreScope.of(context).photo(key),
                    label: l.gearPhotoOf(climber.name, i + 1),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// A square photo thumbnail; tap to see it whole.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb(
    this.photo, {
    super.key,
    required this.label,
    this.size = 84,
  });

  final ImageProvider photo;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showPhoto(context, photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: Mountain.surfaceHigh,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Mountain.granite,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A photo, whole, over the screen; pinch to zoom, tap to close.
Future<void> showPhoto(BuildContext context, ImageProvider photo) => showDialog(
  context: context,
  builder: (context) => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: InteractiveViewer(
      child: Center(
        child: Image(image: photo, fit: BoxFit.contain),
      ),
    ),
  ),
);

/// A climber's name line: "Marta Soler, 29".
class ClimberHeader extends StatelessWidget {
  const ClimberHeader(
    this.climber, {
    super.key,
    this.radius = 24,
    this.subtitle,
  });

  final Climber climber;
  final double radius;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Avatar(climber, radius: radius),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      climber.nameAndAge,
                      style: text.titleMedium?.copyWith(
                        color: Mountain.sand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (climber.demo) ...[
                    const SizedBox(width: 8),
                    Tag(context.l10n.demoTag, color: Mountain.tan),
                  ],
                ],
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(color: Mountain.granite),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A climber's whole profile in a bottom sheet.
Future<void> showProfileSheet(
  BuildContext context,
  Climber climber,
) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Mountain.surface,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (climber.demo) ...[const DemoNotice(), const SizedBox(height: 14)],
          ClimberHeader(climber, radius: 30),
          const SizedBox(height: 14),
          ProfileDetails(climber),
        ],
      ),
    ),
  ),
);

/// A big round swipe button.
class DeckButton extends StatelessWidget {
  const DeckButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.size = 56,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  /// Across, in dp; the icon scales with it.
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: filled ? color : Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: color, width: 2)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.46,
            color: filled ? Mountain.night : color,
          ),
        ),
      ),
    ),
  );
}

/// What a screen shows when there's nothing in it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Mountain.moss),
            const SizedBox(height: 16),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: text.bodyMedium?.copyWith(color: Mountain.granite),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// European or American grades, like Celsius or Fahrenheit: switches how
/// grades are written everywhere in the app.
class GradeSystemToggle extends StatelessWidget {
  const GradeSystemToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SegmentedButton<GradeSystem>(
      showSelectedIcon: false,
      segments: [
        for (final s in GradeSystem.values)
          ButtonSegment(value: s, label: Text(s.label(context.l10n))),
      ],
      selected: {store.gradeSystem},
      onSelectionChanged: (s) => store.gradeSystem = s.single,
    );
  }
}

/// The app's language: the device's (System default), or one picked here,
/// each named in itself. Switches the whole app at once and is kept on the
/// device, like the grade system.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  /// The System default option.
  static const _system = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final l = context.l10n;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l.language,
        prefixIcon: const Icon(Icons.language),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: store.locale?.languageCode ?? _system,
          items: [
            DropdownMenuItem(value: _system, child: Text(l.languageSystem)),
            for (final MapEntry(key: code, value: name)
                in languageNames.entries)
              DropdownMenuItem(value: code, child: Text(name)),
          ],
          onChanged: (code) => store.locale = code == null || code == _system
              ? null
              : Locale(code),
        ),
      ),
    );
  }
}
