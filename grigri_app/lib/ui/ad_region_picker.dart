import 'package:flutter/material.dart';

import '../model/ad.dart';
import '../theme.dart';
import 'common.dart';

/// Picks a region for an ad (specs/ads.md): a country, a region or a
/// town, from OpenStreetMap's place search through the API. It searches
/// only when asked (the search's terms rule out search-as-you-type). Null
/// when cancelled.
Future<AdRegion?> pickAdRegion(BuildContext context) => Navigator.of(context)
    .push<AdRegion>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _AdRegionPicker(),
      ),
    );

class _AdRegionPicker extends StatefulWidget {
  const _AdRegionPicker();

  @override
  State<_AdRegionPicker> createState() => _AdRegionPickerState();
}

class _AdRegionPickerState extends State<_AdRegionPicker> {
  final _query = TextEditingController();
  bool _searching = false;

  /// The last search's answer; null before any.
  List<AdRegion>? _found;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2 || _searching) return;
    setState(() => _searching = true);
    final found = await StoreScope.read(context)
        .searchPlaces(query, Localizations.localeOf(context).languageCode);
    if (!mounted) return;
    setState(() {
      _searching = false;
      if (found != null) _found = found;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final found = _found;
    return Scaffold(
      appBar: AppBar(title: Text(l.adAddRegion)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const ValueKey('region search'),
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l.adRegionSearchLabel,
                prefixIcon: const Icon(Icons.public),
                helperText: l.adRegionSearchHelp,
                helperMaxLines: 3,
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: l.search,
                        icon: const Icon(Icons.search),
                        onPressed: _search,
                      ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: found == null
                ? const SizedBox.shrink()
                : found.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.noPlacesFound,
                      style: text.bodyMedium?.copyWith(color: Mountain.granite),
                    ),
                  )
                : ListView(
                    children: [
                      for (final r in found)
                        ListTile(
                          leading: const Icon(
                            Icons.place_outlined,
                            color: Mountain.sky,
                          ),
                          title: Text(r.name),
                          subtitle: r.label == null || r.label == r.name
                              ? null
                              : Text(
                                  r.label!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Mountain.granite,
                                  ),
                                ),
                          onTap: () => Navigator.of(context).pop(r),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l.placesAttribution('© OpenStreetMap contributors'),
              style: text.bodySmall?.copyWith(color: Mountain.granite),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where an ad shows, for its tile: "Shows in Siurana, España" or
/// "Shows everywhere".
String adWhere(BuildContext context, Ad ad) => ad.regions.isEmpty
    ? context.l10n.adShowsEverywhere
    : context.l10n.adShowsIn(ad.regions.map((r) => r.name).join(' · '));
