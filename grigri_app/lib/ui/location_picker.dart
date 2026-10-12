import 'package:flutter/material.dart';

import '../data/sector_index.dart';
import '../model/location.dart';
import '../model/sector.dart';
import '../theme.dart';

/// Picks a place from the sector index (a crag, sector or gym near where
/// I am or want to climb), for my profile's location or areas. Null when
/// cancelled.
Future<Location?> pickLocation(BuildContext context, {required String title}) =>
    Navigator.of(context).push<Location>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LocationPicker(title: title),
      ),
    );

class _LocationPicker extends StatefulWidget {
  const _LocationPicker({required this.title});

  final String title;

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  final _query = TextEditingController();
  SectorIndex? _index;

  @override
  void initState() {
    super.initState();
    SectorIndex.load().then((index) {
      if (mounted) setState(() => _index = index);
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Only places with a point: distance needs one.
    final List<Sector> found = [
      for (final s
          in _index?.search(_query.text, limit: 40) ?? const <Sector>[])
        if (s.location != null) s,
    ];
    final attribution = _index?.attribution ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'A crag or gym near there',
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search),
                helperText: attribution.isEmpty
                    ? 'Kept to about 1 km, and only you see it.'
                    : 'Kept to about 1 km, and only you see it. '
                          'Places: $attribution',
                helperMaxLines: 2,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _query.text.trim().isEmpty
                ? const SizedBox.shrink()
                : found.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _index == null ? 'Loading places…' : 'No places found',
                      style: text.bodyMedium?.copyWith(color: Mountain.granite),
                    ),
                  )
                : ListView(
                    children: [
                      for (final s in found)
                        ListTile(
                          leading: const Icon(
                            Icons.place_outlined,
                            color: Mountain.sky,
                          ),
                          title: Text(s.name),
                          subtitle: s.where.isEmpty
                              ? null
                              : Text(
                                  s.where,
                                  style: const TextStyle(
                                    color: Mountain.granite,
                                  ),
                                ),
                          onTap: () => Navigator.of(context).pop(s.location),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
