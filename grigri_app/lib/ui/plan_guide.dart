import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/guides.dart';
import '../model/guide.dart';
import '../model/plan.dart';
import '../theme.dart';
import 'common.dart';

/// The plan screen's "Area guide" (specs/guides.md): the climbing guide's
/// page on the plan's area, when a bundled guide covers it. Opens the
/// area's whole page.
class PlanGuideSection extends StatefulWidget {
  const PlanGuideSection({super.key, required this.plan, this.guides});

  final Plan plan;

  /// The guides to look in; null: the bundled ones. Tests pass their own.
  final Guides? guides;

  @override
  State<PlanGuideSection> createState() => _PlanGuideSectionState();
}

class _PlanGuideSectionState extends State<PlanGuideSection> {
  late Future<Guides> _guides;

  @override
  void initState() {
    super.initState();
    _guides = widget.guides != null
        ? Future.value(widget.guides)
        : Guides.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Guides>(
    future: _guides,
    builder: (context, snapshot) {
      final plan = widget.plan;
      final found = snapshot.data?.areaFor(
        lat: plan.lat,
        lon: plan.lon,
        place: plan.place,
        area: plan.area,
      );
      if (found == null) return const SizedBox.shrink();
      return _AreaCard(guide: found.guide, area: found.area);
    },
  );
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.guide, required this.area});

  final ClimbingGuide guide;
  final GuideArea area;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = l.localeName.split('_').first;
    final text = Theme.of(context).textTheme;
    final closedNow = area.closures.where((c) => c.covers(DateTime.now()));
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(l.areaGuide),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GuideAreaScreen(guide: guide, area: area),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Number(area.number),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(area.name, style: text.titleMedium),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Mountain.granite,
                        ),
                      ],
                    ),
                    if (!area.tagline.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        area.tagline.of(lang),
                        style: text.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Mountain.sand,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (!area.rock.isEmpty)
                          Tag(
                            _plain(area.rock.of(lang)),
                            icon: Icons.terrain_outlined,
                          ),
                        for (final _ in closedNow)
                          Tag(
                            l.guideClosedNow,
                            icon: Icons.block,
                            color: Mountain.clay,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      guide.title.of(lang),
                      style: text.labelSmall?.copyWith(color: Mountain.granite),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Limestone." → "Limestone": a short value as a tag.
String _plain(String s) => s.endsWith('.') ? s.substring(0, s.length - 1) : s;

/// A climbing area's page in its guide: what it's like, then access, the
/// climbing, rock, routes, season, tips and books, its sectors, featured
/// routes and closures, and where the text comes from.
class GuideAreaScreen extends StatelessWidget {
  const GuideAreaScreen({super.key, required this.guide, required this.area});

  final ClimbingGuide guide;
  final GuideArea area;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = l.localeName.split('_').first;
    final text = Theme.of(context).textTheme;
    final dates = DateFormat.MMMd(l.localeName);
    String day(({int month, int day}) d) =>
        dates.format(DateTime(2000, d.month, d.day));
    final facts = [
      (l.guideAccess, area.access),
      (l.guideClimbing, area.climbing),
      (l.guideRock, area.rock),
      (l.guideRoutes, area.routes),
      (l.guideSeason, area.season),
      (l.guideTips, area.tips),
      (l.guideReading, area.reading),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(area.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _Number(area.number),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area.name, style: text.headlineSmall),
                    if (area.subtitle.isNotEmpty)
                      Text(
                        area.subtitle,
                        style: text.bodyMedium?.copyWith(
                          color: Mountain.granite,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!area.tagline.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              area.tagline.of(lang),
              style: text.titleSmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Mountain.sand,
              ),
            ),
          ],
          if (!area.intro.isEmpty) ...[
            const SizedBox(height: 12),
            Text(area.intro.of(lang), style: text.bodyMedium),
          ],
          if (area.closures.isNotEmpty) ...[
            _Heading(l.guideClosures),
            for (final c in area.closures)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.block, size: 18, color: Mountain.clay),
                    ),
                    Expanded(
                      child: Text(
                        l.guideClosure(
                          c.sector,
                          day(c.from),
                          day(c.to),
                          c.reason.of(lang),
                        ),
                      ),
                    ),
                    if (c.covers(DateTime.now()))
                      Tag(l.guideClosedNow, color: Mountain.clay),
                  ],
                ),
              ),
          ],
          for (final (heading, body) in facts)
            if (!body.isEmpty) ...[
              _Heading(heading),
              Text(body.of(lang), style: text.bodyMedium),
            ],
          if (area.accessMap.isNotEmpty) ...[
            _Heading(l.guideAccessMap),
            _Map(area.accessMap),
          ],
          if (area.sectors.isNotEmpty) ...[
            _Heading(l.guideSectors),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final s in area.sectors) Tag(s)],
            ),
          ],
          if (area.climbs.isNotEmpty) ...[
            _Heading(l.guideClimbs),
            for (final c in area.climbs)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route_outlined),
                title: Text(c.name),
                subtitle: c.sector.isEmpty || c.sector == c.name
                    ? null
                    : Text(c.sector),
                trailing: Text(c.grade, style: text.titleSmall),
              ),
          ],
          const SizedBox(height: 24),
          _Source(guide),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(l.guideOpenAll),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GuideScreen(guide: guide),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A whole climbing guide: its introduction, its areas (each opens its
/// page), its advice, the services, links and books it lists, and its
/// credits.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.guide});

  final ClimbingGuide guide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = l.localeName.split('_').first;
    final text = Theme.of(context).textTheme;
    final dim = text.bodySmall?.copyWith(color: Mountain.granite);
    return Scaffold(
      appBar: AppBar(title: Text(guide.title.of(lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!guide.intro.isEmpty)
            Text(guide.intro.of(lang), style: text.bodyMedium),
          _Heading(l.guideAreas),
          if (guide.map.isNotEmpty) _Map(guide.map),
          for (final a in guide.areas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Number(a.number),
              title: Text(a.name),
              subtitle: a.rock.isEmpty ? null : Text(_plain(a.rock.of(lang))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GuideAreaScreen(guide: guide, area: a),
                ),
              ),
            ),
          if (!guide.advice.isEmpty) ...[
            _Heading(l.guideAdvice),
            Text(guide.advice.of(lang), style: text.bodyMedium),
          ],
          if (guide.services.isNotEmpty) ...[
            _Heading(l.guideServices),
            for (final s in guide.services)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: text.titleSmall),
                    if (s.activities.isNotEmpty) Text(s.activities),
                    for (final line in [s.address, s.phone, s.web, s.email])
                      if (line.isNotEmpty) _Copyable(line, style: dim),
                  ],
                ),
              ),
          ],
          if (guide.links.isNotEmpty) ...[
            _Heading(l.guideLinks),
            for (final link in guide.links)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(link.label.of(lang))),
                    _Copyable(link.url, style: dim),
                  ],
                ),
              ),
          ],
          if (guide.bibliography.isNotEmpty) ...[
            _Heading(l.guideBibliography),
            for (final b in guide.bibliography)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: text.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      [
                        b.authors,
                        b.publisher,
                        b.languages,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: dim,
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          _Source(guide),
        ],
      ),
    );
  }
}

/// Where a guide's text comes from, and who wrote it and took its photos.
class _Source extends StatelessWidget {
  const _Source(this.guide);

  final ClimbingGuide guide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = l.localeName.split('_').first;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Mountain.granite);
    final writer = guide.credits['text'] ?? '';
    final photos = guide.credits['photos'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.guideSource(guide.title.of(lang), guide.publisher, guide.year),
          style: style,
        ),
        if (writer.isNotEmpty || photos.isNotEmpty)
          Text(l.guideCredits(writer, photos), style: style),
      ],
    );
  }
}

/// A phone number, address or link: tap to copy it.
class _Copyable extends StatelessWidget {
  const _Copyable(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => Clipboard.setData(ClipboardData(text: text)),
    child: Text(text, style: style),
  );
}

/// A guide's map, from the app's assets: tap to see it whole and zoom.
class _Map extends StatelessWidget {
  const _Map(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    final image = AssetImage(asset);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => showPhoto(context, image),
        child: Image(image: image, fit: BoxFit.cover),
      ),
    );
  }
}

/// An area's number in its guide, as on the guide's map.
class _Number extends StatelessWidget {
  const _Number(this.number);

  final int number;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 14,
    backgroundColor: Mountain.pine,
    child: Text(
      '$number',
      style: const TextStyle(
        color: Mountain.snow,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Mountain.granite, letterSpacing: 1.2),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: _Label(text),
  );
}
