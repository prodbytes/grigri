# Sectors

A plan's **where** is a specific climbing sector, crag or gym, picked from
a searchable index ([plan editor](screens.md)), and so are a profile's
location and areas ([location picker](screens.md)). There are many of them, so
it's a search field, not a list.

## Cost first: no server

The index is a static file searched on the device, so it costs nothing to
run:

- **The file**: [assets/sectors.json](../grigri_app/assets/sectors.json),
  bundled with the app (an asset on Android, iOS and the web):
  `{"attribution": …, "sectors": [[id, name, area, country, lat, lon], …]}`
  (the point left out when OpenStreetMap has none).
- **The search**
  ([SectorIndex](../grigri_app/lib/data/sector_index.dart)): loaded once,
  when the plan editor or the location picker first opens. Every word typed must start a word of
  the sector's name or of where it is, ignoring case and accents ("pique"
  finds "Can Piqué"). At most 20.
  - **Nearest first** (the plan editor, when I've set where I am: my
    location, else my first area): matches sorted by distance from me
    (great circle), then as below; places without a point after all the
    others. With nothing typed it offers the nearest 20 places. Each
    shows how far it is ("Siurana, Spain · 0.7 km"; one decimal under
    10 km).
  - Otherwise: names that start with the query come first, then names
    with all its words, then matches on where it is; shorter names first.
- **The plan** keeps the sector's id (`sectorId`), its name (`place`) and
  where it is (`area`, e.g. "Siurana, Spain"), so it reads the same if the
  index changes, and its point (`lat`, `lon`), which places it for the
  [deck's ranking](matching.md#the-deck). A place typed in by hand has no
  id, area or point.

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
  run leaves the index as it was. It keeps the rows a climbing guide
  added (ids `guide:…`).
- It takes the country's crags and sectors (`climbing=crag`) and climbing
  gyms (`climbing=gym`, or `leisure=sports_centre` with `sport=climbing`),
  with their points (`out center`: a node's own, a way's or relation's
  center), kept to 5 decimals.
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

The bundled file is a placeholder with a few crags (ids
`demo:…`, approximate points, no attribution), until the build runs where Overpass can be
reached. It also has the [Costa Daurada guide](guides.md)'s areas and the
sectors it names (39 rows, ids `guide:…`: La Mussara, Arbolí, El
Montsant, Siuranella, El Racó de Missa, Fraguerau, Mola Roquerola…), with
points from OpenStreetMap's Nominatim where it has them, approximate;
the build keeps them. It needs no change in the app: the build's output replaces it.
Splitting the file per country, downloaded as needed, is the next step
once it grows big.
