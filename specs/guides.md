# Climbing guides

Grigri carries climbing guides to whole regions, so a plan's screen can
say what its area is like: the rock, the routes, the season, how to get
there, where to find water and a bed, and what's closed when. The first
is the **Costa Daurada** guide.

## The Costa Daurada guide

*Escalada / Rock Climbing, Costa Daurada*: a 24-page brochure published
by the Patronat de Turisme de la Diputació de Tarragona in 2004 (text by
Albert Folch, photos by Joan Alberich), in Catalan and English, used
with the rights holder's permission. The PDF itself isn't in the
repository: it's kept in `.local/guides/costa-daurada/` (git-ignored, as
everything `*.local*` is), with what was extracted from it (each page's
text and render, its 68 embedded images, the access maps).

Everything it says is in the app:

- **Its 11 areas**, numbered as on its map: 1 Siurana, 2 La Mussara,
  3 Arbolí, 4 El Montsant, 5 Vilanova de Prades, 6 Ulldemolins,
  7 Margalef, 8 La Riba, 9 Mont-ral, 10 Els Cogullons, 11 L'Hospitalet
  (a via ferrata). Each has its tagline, its introduction, and its
  practical information: access, type of climbing, rock, routes, season,
  tips and advice (water, shops, refuges, campsites, tourist offices'
  phones) and further reading; the sectors and the routes (with their
  grades) it names; and its yearly closures (Mola Roquerola, at Els
  Cogullons: no climbing 1 January to 30 June, for nesting birds).
- **Its maps**: the region's map of the areas, and the access maps of
  Siurana, El Montsant, Margalef and Els Cogullons (rendered from the
  PDF's vector drawings).
- **Its general text**: the introduction to the region; the advice
  (check for temporary restrictions, the equippers aren't responsible for
  bolts, insurance, the environment and keeping to the paths); the 14
  services it lists (guides, gear shops, clubs, activity companies: their
  activities, address, phone, web and e-mail); useful links; and its
  bibliography (nine guidebooks).
- **Its photos**: 33 of them, as [GriGri Pics](pics.md#the-costa-daurada-guides-photos).
- **Its areas and sectors** in the [sector index](sectors.md), so plans
  can be made at them.

The text is the guide's own, in both its languages, with obvious typos
fixed (the English said La Rambla is 9a; it's 9a+, as the Catalan says)
and one dead link replaced (the weather service, now www.meteo.cat).
Points (each area's center, roughly, and how far its crags reach) are
from OpenStreetMap's Nominatim.

## In the app

- **Plan screen**: below the plan's photos, **Area guide**, when a guide
  covers the plan's place: a card with the area's number and name, its
  tagline, its rock, **Closed now** when one of its closures applies
  today, and the guide's title. It opens the area's page.
- **Area page**: its name and subtitle, tagline and introduction, its
  closures (with **Closed now**), then **Access**, **Type of climbing**,
  **Rock**, **Routes**, **Season**, **Tips and advice**, **Further
  reading**, its **Access map** (tap to zoom), its **Sectors** and
  **Featured routes** (name, sector and grade), where the text comes from
  ("From “Rock Climbing · Costa Daurada”, Patronat de Turisme de la
  Diputació de Tarragona, 2004." and "Text: … · Photos: …"), and **The
  whole guide**.
- **The whole guide**: its introduction, the map and the list of its
  areas (each opens its page), **Before you climb** (the advice),
  **Services**, **Useful links** and **Bibliography**; phones, addresses
  and links are tapped to copy.
- **Language**: the guide's text in Catalan when the app is in Catalan,
  and in English in every other language (the guide has no other); the
  headings are in the app's language, like the rest of it.

### Which area a plan is in

([Guides.areaFor](../grigri_app/lib/data/guides.dart))

- With the plan's point: the nearest area whose crags reach it (each
  area has a center and a reach, 4 to 8 km). El Falcó, 0.9 km from
  Arbolí and 1.9 km from Siurana, is Arbolí's, as the guide says.
- Without one (a place typed in by hand): the area named in the plan's
  place or area, as whole words, ignoring case and accents ("Montsant"
  is El Montsant's other name), or else the area whose sectors include
  the place ("Fraguerau" is Ulldemolins').
- None: no **Area guide**.

## The data

- [assets/guides/costa-daurada.json](../grigri_app/assets/guides/costa-daurada.json):
  the guide (texts as `{"en": …, "ca": …}`), with its maps in
  [assets/guides/costa-daurada/](../grigri_app/assets/guides/costa-daurada).
  Another guide is another file, listed in `Guides.assets`.
- Read on the device, once, when a plan screen first opens; no server.
- A test ([guide_test.dart](../grigri_app/test/guide_test.dart)) checks
  the guide is complete in both languages, its maps are bundled, and
  which area places are in.

## Cost

Nothing to run: the guide is part of the app (about 0.6 MB of JSON and
maps; on the web, fetched only when a plan screen opens, then cached).
Its photos are GriGri Pics: about 0.5 MB more in the pics bucket
($0.00001 a month) and served through the CloudFront the site has.
