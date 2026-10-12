# Sectors

A plan's **where** is a specific climbing sector, crag or gym, picked from
a searchable index ([plan editor](screens.md)). There are many of them, so
it's a search field, not a list.

## Cost first: no server

The index is a static file searched on the device, so it costs nothing to
run:

- **The file**: [assets/sectors.json](../grigri_app/assets/sectors.json),
  bundled with the app (an asset on Android, iOS and the web):
  `{"attribution": …, "sectors": [[id, name, area, country], …]}`.
- **The search**
  ([SectorIndex](../grigri_app/lib/data/sector_index.dart)): loaded once,
  when the plan editor first opens. Every word typed must start a word of
  the sector's name or of where it is, ignoring case and accents ("pique"
  finds "Can Piqué"). Names that start with the query come first, then
  names with all its words, then matches on where it is; shorter names
  first; at most 20.
- **The plan** keeps the sector's id (`sectorId`), its name (`place`) and
  where it is (`area`, e.g. "Siurana, Spain"), so it reads the same if the
  index changes. A place typed in by hand has no id and no area.

A server (a database with text search) only pays off once people add
sectors for everyone; until then a place the index lacks is typed in.

## The data: OpenStreetMap

[tool/build_sectors.dart](../grigri_app/tool/build_sectors.dart) builds the
file from OpenStreetMap through the public Overpass API, per country:

```sh
cd grigri_app
flutter pub get  # dart run needs the Flutter packages resolved
dart run tool/build_sectors.dart assets/sectors.json ES FR IT PT
```

- It writes the file only when every country came through, so a failed
  run leaves the index as it was.
- It takes the country's crags and sectors (`climbing=crag`) and climbing
  gyms (`climbing=gym`, or `leisure=sports_centre` with `sport=climbing`).
- A sector's area is the climbing area (a `climbing=area` relation) it's a
  member of; a gym's is its town (`addr:city`). Ids are the OSM elements
  ("osm:n123", "osm:w45").
- OpenStreetMap data is © OpenStreetMap contributors, under the ODbL: the
  file carries the attribution, and the editor shows it under the field.

OpenBeta, the other open climbing database, was checked first and set
aside: its data is almost all in the US (in October 2026 it had 71 climbs
in France and 61 in Spain). theCrag, 27crags and Mountain Project don't
allow reuse.

## For now: a placeholder

The bundled file is a placeholder with the demo data's crags (ids
`demo:…`, no attribution), until the build runs where Overpass can be
reached. It needs no change in the app: the build's output replaces it.
Splitting the file per country, downloaded as needed, is the next step
once it grows big.
