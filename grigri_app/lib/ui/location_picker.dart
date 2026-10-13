import 'package:flutter/material.dart';

import '../data/sector_index.dart';
import '../model/location.dart';
import '../model/sector.dart';
import '../theme.dart';
import 'common.dart';

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

  /// Asking the device where it is.
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    SectorIndex.load().then((index) {
      if (mounted) setState(() => _index = index);
    });
  }

  /// Takes where the phone or browser is; says so when it can't tell.
  Future<void> _useCurrent() async {
    setState(() => _locating = true);
    final here = await StoreScope.read(context).locateMe();
    if (!mounted) return;
    setState(() => _locating = false);
    if (here != null) {
      Navigator.of(context).pop(here);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.locationNotFound)));
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
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
                labelText: l.locationSearchLabel,
                hintText: l.search,
                prefixIcon: const Icon(Icons.search),
                helperText: attribution.isEmpty
                    ? l.locationPrivacy
                    : '${l.locationPrivacy} ${l.placesAttribution(attribution)}',
                helperMaxLines: 2,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _query.text.trim().isEmpty
                ? ListView(
                    children: [
                      ListTile(
                        leading: _locating
                            ? const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: Mountain.sky,
                              ),
                        title: Text(l.useCurrentLocation),
                        onTap: _locating ? null : _useCurrent,
                      ),
                    ],
                  )
                : found.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _index == null ? l.loadingPlaces : l.noPlacesFound,
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
