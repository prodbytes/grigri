# Plan photos: Your Pics and GriGri Pics

A plan's screen shows two sets of photos, apart:

- **Your Pics**: what the group added to the plan, plus every photo sent
  in its chat. Members only. People's data, in the photos bucket with
  their profile and chat photos.
- **GriGri Pics**: Grigri's own photos of the plan's crag, freely
  licensed and credited. Anyone who can see the plan. App content, in a
  bucket of its own, never mixed with people's data.

Routes and JSON shapes are in [api.md](api.md#routes); the screen is in
[screens.md](screens.md).

## Your Pics

- **Adding**: a member picks a photo (camera or gallery; downsized to
  1600 px at 75%, as chat photos are). `POST /api/plans/{id}/pics/upload`
  gives a presigned POST (JPEG, PNG or WebP, ≤ 2 MB) for
  `plans/<planId>/<random>.<ext>`, tagged pending, and
  `POST /api/plans/{id}/pics` with the key adds it: it loses its pending
  tag and becomes a plan photo (item `PLAN#<id>` / `PIC#<picId>`).
- **From the chat**: a photo sent in the plan's chat joins its Your Pics
  at once (`fromChat`); videos don't.
- **Deleting**: whoever added it, the organizer, or an admin. A photo
  added to the plan is deleted from S3 too; a chat photo only leaves the
  pics, and the chat keeps it.
- **Limits**: at most 100 photos a plan (409 past that; a chat photo past
  it stays in the chat only). Like chat media, they're kept 400 days
  after their upload: the photos bucket's lifecycle rule
  (`photos/plans/`) and the item's TTL.
- **Live updates**: adding or deleting one sends the other members a
  `pics` hint, and their open plan screen reloads its photos.

## GriGri Pics

### Lookup

`GET /api/plans/{id}/pics` (with the plan's Your Pics) or `GET /api/pics`
(a point, a sector id, a place's name) gives up to 12 photos, best first
([domain/pics.ts](../grigri_api/src/domain/pics.ts)):

1. the plan's own crag: its sector id (the [sector index](sectors.md)'s
   OpenStreetMap id) in the catalog;
2. crags within 1 km of the plan's point, nearest first;
3. a crag whose name is the plan's place (ignoring case, accents and
   punctuation), for places typed by hand;
4. the climbing area's own photos (ids `area:<name>`): within 8 km of its
   center, or its name a word of the plan's place or area.

Each photo carries its crag's name, caption, author, license, license URL
and source page. The app shows the crag's name on it, and the caption and
credit ("Photo: <author>, <license>", and the source to copy) when opened,
as the licenses ask.

### On the deck

`GET /api/discover` gives each plan's first photo of that lookup as its
**cover** (`covers`: key, crag, author, license), worked out from the
catalog the function already keeps, so it costs no extra reads or calls.
The Discover card shows it edge to edge, with "<crag> · Photo: <author>,
<license>" over it ([screens](screens.md)); a plan without one shows a
backdrop instead.

### Storage: S3, with annotations

- **The bucket**: `<site stack>-pics-<account>` (`grigri-web-pics-…`,
  `grigri-rc-web-pics-…`; `grigri-local-pics` in Floci), in the site
  stack, private, served by the site's CloudFront at `/pics/*` (origin
  access control; only `pics/crags/*` is readable there). Photos are at
  `pics/crags/<crag>/<hash of their source>.jpg`: keys never change for a
  source, so they're cached for a year.
- **Metadata**: each photo carries an [S3
  annotation](https://aws.amazon.com/blogs/aws/amazon-s3-annotations-attach-rich-queryable-context-directly-to-your-objects/)
  named `grigri`, JSON: the crag (`id`, `name`, `area`, `lat`, `lon`), the
  photo's `key`, `width`, `height`, `caption`, `author`, `license`,
  `licenseUrl` and `source`. The annotations are the source of truth,
  kept on the objects themselves.
- **Querying**: `pics/catalog.json`, made from the annotations by the
  loader, holds every crag with its photos. The API reads it with one S3
  GET and keeps it while the function is warm (an hour at most), then
  looks photos up in memory. Its role may read that one object, nothing
  else in the bucket.
- **Why not query S3 directly.** S3 Select (SQL over an object) is closed
  to new AWS customers; this account gets `MethodNotAllowed`. Annotations
  are queryable only through S3 Metadata annotation tables and Athena:
  tables refreshed within about an hour, a few seconds per query, a
  results bucket, and charges for the metadata tables, S3 Tables and each
  query ($5 per TB scanned, 10 MB minimum). The catalog costs one GET
  ($0.0004 per 1,000) per warm function and answers in microseconds; it's
  rebuilt whenever the photos change. Annotation tables can still be
  turned on later for ad hoc SQL over the photos, without changing the
  data.

### The data and the loader

- [grigri_api/pics/crags.json](../grigri_api/pics/crags.json): the crags
  and their photos, checked by hand. Crags are OpenStreetMap's
  `climbing=crag` (and `climbing=area`) within 6 km of Siurana and
  Margalef; photos are from Wikimedia Commons, only CC0, public domain,
  CC BY or CC BY-SA, only ones that clearly show that place, and never
  with a watermark or a person's name (in the file's title, description
  or caption; the author's credit is the license's).
- As of 2026-10-16 it has **8 photos: 5 of Siurana and 3 of Margalef**,
  as areas (El Pati and Racó de la Finestra among them). Commons has no
  photo that can be tied to any single OpenStreetMap crag there, so the
  11 Margalef crags are listed with none (Siurana's sectors aren't tagged
  `climbing=crag` in OpenStreetMap). A plan at either place, or within
  8 km, shows its area's photos.
- [grigri_api/pics/load.mjs](../grigri_api/pics/load.mjs) loads it,
  idempotently: it downloads each photo not in the bucket yet (Commons'
  1920 px thumbnail; cached in `grigri_api/pics/.cache`, git-ignored),
  puts it, sets its annotation (again when `crags.json` changed it),
  deletes photos taken out of the file, and rebuilds the catalog from the
  annotations. A photo that fails to download is skipped and reported.
- **Where it runs**: `scripts/deploy.sh`, after the site stack, on every
  RC and GA deploy (only new photos are uploaded); locally, `6-pics`
  ([dev-environment.md](dev-environment.md)) runs it whenever Floci's
  pics bucket has no catalog (Floci keeps nothing between starts).

## Cost

Nothing while idle beyond storage; see [backend.md](backend.md#cost).

- **GriGri Pics storage**: ~6 MB now (8 photos of ~0.7 MB):
  $0.0002/month. Annotations are billed as S3 Standard storage (bytes).
- **Lookups**: the catalog GET, once per warm function: about $0.0004 per
  1,000 cold starts. The plan's photos come with one extra API call per
  plan screen opened (`GET /api/plans/{id}/pics`: ~$2 per million). The
  deck's covers ride on `GET /api/discover`: no extra call; each card's
  photo is one CloudFront request, cached by the app and the CDN.
- **Serving**: through the CloudFront the site already has, cached for a
  year: inside its free tier (1 TB and 10 million requests a month).
- **Loading**: per deploy, one LIST, one annotation GET per photo, and a
  catalog PUT: under $0.0001. New photos: one PUT and one annotation PUT
  each ($0.005 per 1,000).
- **Your Pics**: as chat photos ([backend.md](backend.md#chat-media)):
  storage at $0.023/GB-month, an upload and a tag clear per photo, kept
  400 days. A DynamoDB item per photo (a write to add, a delete to
  remove, the list a query).
