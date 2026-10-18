# Landing page

The site root (`/`, [grigri_index/site](../grigri_index/site)) is a
landing page that gets visitors to sign in. The app stays at `/app/`,
where the Google sign-in actually happens. The app's sign-in screen has
the same look, on the web, Android and iOS ([sign-in](sign-in.md)), so
the **Sign in** buttons lead to a matching page. The page takes its look from
popular apps: Tinder's full-bleed photo and swiping card, Airbnb's row of
photo cards, and Strava's "join for free".

## Who sees it

- **Signed-in climbers skip it.** [redirect.js](../grigri_index/site/redirect.js)
  runs first, in `<head>`. When the app's session token is in this
  origin's local storage (`flutter.grigri.session`, kept by
  shared_preferences, see [sign-in](sign-in.md)), it sends the browser
  straight to `/app/`.
- **Links with a query string** go to `/app/` with the query string kept,
  as `/` always did.
- Everyone else sees the page. It works without JavaScript too: the page
  is static HTML in English and every button is a link to `/app/`.

## What's on it

From top to bottom:

1. **The bar**: just a **Sign in** button, on the right (no logo or
   name; the hero says what Grigri is).
2. **The hero**: a GriGri Pics photo edge to edge (the nearest crag's,
   when the visitor's location is known), the
   headline ("Join a climbing plan."), the tagline, a
   **Sign in with Google** button and "Free for every climber: no card, no
   subscription." Beside it (below it on phones) is a demo plan card that
   swipes right on a loop with a JOIN stamp. Each loop brings in the next
   of three made-up plans (Saturday sport with Mara and Jonas, Sunday
   multi-pitch with Iker and Lea, next weekend's bouldering with Noor
   and Tomás), each at another crag with its photo: up to three crags
   from the strip, the hero's crag last (without the catalog: Siurana,
   Margalef, Montserrat). The loop doesn't play when the browser
   asks for reduced motion.
3. **Crags near you**: a horizontal, snapping row of up to 12 GriGri Pics
   photo cards, at most 3 per crag. Each card shows the crag's name, its
   area, how far away it is, and the credit its license asks for
   ("Photo: <author>, <license>"), which links to the photo's source page.
   - Without the visitor's location, the row is titled "Crags on Grigri"
     and keeps the catalog's order, with a **Show crags near me** button.
     If the browser already allows location for the site, the page uses
     it without asking. If location is blocked, there's no button.
   - With the location, crags are sorted nearest first (great circle).
     The row is titled "Crags near you" when the nearest is within 150 km.
     Otherwise it's "The crags nearest you", with "No crag photos near you
     yet: these are the closest."
   - "Your location stays on your device": distances are worked out in
     the browser, and the point is never sent anywhere.
   - If the catalog can't be read, the row is hidden and the rest of the
     page works.
4. **How it works**: three steps (make a plan; swipe right, with the
   group letting newcomers in one at a time; climb together in the
   plan's group chat).
5. **Free. Really.**: plans and swiping, matches and group chats, crag
   photos, no card to sign up. Premium is described as optional, only for
   advertising and the route finder ([premium.md](premium.md)).
6. **A last call** ("This weekend's climbing plan is one swipe away.")
   with **Join free with Google**, and a footer saying the crag photos
   are freely licensed or used with permission, crediting
   the photos' authors and OpenStreetMap for the crags' locations, with
   links to the **Privacy policy** and **Support** pages.

**The privacy policy and support pages**, `/privacy.html` and
`/support.html` ([app-store](app-store.md)), are static pages in English
in the same look (`index.css` plus their own `legal.css`), with no
script, so the index CSP covers them as they are. The App Store listing
and the app's Profile link to them.

The look is the app's [theme](theme.md) (night, olive, pine, sand…), in
the system font. It's laid out for phones first: one column under 820 px.

## Languages

The page is in the app's six languages ([i18n.md](i18n.md)): English,
Spanish, German, French, Portuguese and Catalan. It picks the first of the
browser's languages that it has, and otherwise uses English. The strings
are in [index.js](../grigri_index/site/index.js) and follow the app's
wording (the tagline and "Sign in with Google" are the app's own).

## The photos: the catalog, read on the device

The page reads GriGri Pics' catalog ([pics.md](pics.md)) as a static file
at `/pics/catalog.json`, through the site's CloudFront. The bucket policy
lets CloudFront read that one object as well as `pics/crags/*`. The
photos are at `/pics/<key>` and load lazily.

The strip's cards and the demo card load the smallest of the photo's
[smaller copies](pics.md#sizes) whose pixels cover the card as laid out
(its width, or its height times the photo's shape, cropped to fill it,
times the screen's `devicePixelRatio`, and 5% more for the cards' hover
zoom), else the photo itself: when the catalog lists no copies, or none
is big enough. A wider window later loads a bigger one (never a
smaller), and a copy that fails to load gives way to the photo. The
hero, which fills the window and drifts, always shows the photo
itself.

## Security

The index's CSP ([grigri_infra/site.yaml](../grigri_infra/site.yaml),
`IndexHeadersPolicy`) allows only the page's own files: `script-src`,
`style-src`, `img-src` and `connect-src` are `'self'`, there's no inline
code, and nothing can frame it. `Permissions-Policy` allows location for
the page itself (`geolocation=(self)`), and denies the camera and the
microphone. Data from the catalog is written to the page as text, never
as HTML, and only `https:` source links become links.

## Cost

- **Nothing while idle**: the files and the catalog sit in S3, which the
  site already pays for.
- **Per visit**: the page's files and the catalog come from CloudFront's
  cache (the catalog is cached for an hour, and each deploy invalidates
  it). The photos are cached for a year. All of this is inside
  CloudFront's free tier (1 TB and 10 million requests a month). Beyond
  the free tier, a visit that loads the hero and the first cards (about
  2–3 MB; less once the loader has made the photos' smaller copies,
  which the cards load) costs about $0.0002 in data transfer.
- **Why this way**: a "photos near me" API call would be a Lambda and
  HTTP API request per visit, plus an unauthenticated route to defend.
  Sorting about 50 crags in the browser costs nothing and keeps the
  visitor's location on their device.
