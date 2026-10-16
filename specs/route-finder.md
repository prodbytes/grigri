# Route finder

**Premium** ([premium.md](premium.md)). Point the phone at the rock and see
its routes on it: each route Grigri knows there drawn as a line through
its bolts, from the ground up, and labeled at the top with its grade and
name. Climbers record new routes bolt by bolt, and Grigri learns each wall
better from every confirmed view.

## How it works: recognition on the device

Nothing leaves the phone while it looks: recognition runs in the app, so
it costs nothing per frame and works without a signal once the walls are
loaded.

- **Walls**: a rock face known by its reference photos ("views"). Routes
  are drawn on the wall's first view, as points 0..1 of its width and
  height; every other view carries the 3×3 transform (a homography) that
  takes its pixels to the first view's.
- **Finding a wall in a frame** ([lib/vision/](../grigri_app/lib/vision)):
  plain Dart, no native libraries, the same on Android, iOS and the web.
  - Corners: FAST-9 on the gray frame, the threshold lowered in dim or flat
    light until there are enough, kept to the strongest per grid cell
    (500), so they spread over the rock.
  - Descriptors: 256-bit BRIEF on a 5×5-blurred patch, **upright** (a
    phone is held upright in front of a wall; per-corner orientation on
    rock's soft patches cost more matches than it saved, and BRIEF takes a
    hand's tilt).
  - Each view's corners are found once, at 640 px wide, at five scales
    (1.4×, 1×, 0.75×, 0.56×, 0.42×), so the wall is found from nearer or
    farther than the photo was taken.
  - Matching: nearest descriptor by Hamming distance (≤ 64 bits), Lowe's
    ratio test (0.8), one frame corner per reference corner; then RANSAC
    (400 tries, 5 px) for the homography and a least-squares refit on its
    inliers. A wall is found with ≥ 15 inliers and a plausible transform
    (the view's corners stay a convex, same-handed quadrilateral, not
    shrunk or grown past 25× in area).
  - Measured on real rock photos warped by a known transform (6–12°
    tilt, 0.8–1.5× scale, perspective, light and noise changed): the
    route's points land within 0.6 px, in about 20 ms a frame on a laptop.
- **Live** (Android and iOS): the camera's frames (ResolutionPreset.high),
  one at a time, turned upright and scaled to 480 px, go to a background
  isolate that holds every view's features. It tries the view found last
  first, then six others in turn, so a frame stays fast however many views
  there are. A wall stays drawn 0.7 s after the last frame that found it.
- **The web**: browsers give no frames to the app, so **Find routes**
  takes a photo and finds the routes on it.

## The screens

- **Plan screen**: **Routes on the rock**, for premium climbers (members
  or not), where the plan is (its sector's point), or where I am for a
  place typed by hand. Hidden for everyone else.
- **Route finder**: the camera, the routes over the rock in six colors
  (a dark-edged line, a dot per bolt, a ring at the anchor, a label with
  the grade in my grade system and the name), and a line saying what's
  happening ("Getting the walls here ready…", "No walls known here yet.
  Record the first route.", "<wall>: N routes", "Point the camera at the
  wall"). **Record a route** and **Learn this view** (phones, once the
  wall is in sight) or **Find routes** (the web) take a photo and open it.
- **The photo**: its routes, if Grigri recognized the wall. **Record a
  route**: tap each bolt from the ground up to the anchor (a white line
  follows; **Undo** takes the last back), then **Save the route**: its
  name, Route or Boulder, and its grade. On rock Grigri doesn't know,
  the photo becomes a new wall (named after the plan's place by default)
  and its first view. **Learn this view**: the photo joins the wall as a
  view.

## Learning

Every wall gets better with use, without training anything:

- A **new route** on a known wall is placed on its first view through
  the photo's transform, so it shows from everywhere the wall is
  recognized.
- **Learn this view** adds the photo as a view, with its transform to the
  first view (from the recognition, scaled to the photo's full size).
  Later frames match it too, so the wall is found from that angle and in
  that light. A wall keeps 12 views: its first, and the 11 latest learned
  (the oldest goes, and its photo is deleted).
- Only a person's confirmation teaches: views are added when someone says
  this is right, so a bad match can't teach itself.

## Data

`/api/walls` ([api.md](api.md#routes)), premium only:

- A wall is one DynamoDB item (`WALL#<id>`), its views and routes inside
  (12 views, 80 routes of up to 40 bolts: well under 400 KB), in the gsi1
  `WALLS` partition. The lookup reads the partition and keeps walls within
  3 km, nearest first (20 at most): fine for thousands of walls; past that,
  partition them by area.
- Views are photos in the photos bucket (`photos/walls/<owner>/<id>.<ext>`,
  ≤ 2 MB, uploaded with presigned POSTs, pending until a wall or view uses
  them), read by the app through `/photos/*` like every photo.
- Changes are conditioned on the wall's version, and retried.
- Routes are deleted by whoever drew them, or an admin.

## Cost

$0 while idle; nothing per frame (recognition is on the phone).

- Per wall: a DynamoDB item (a few KB) and up to 12 photos (~0.3 MB each
  at the camera's high preset): ~$0.0001/month.
- Per lookup: one query of the `WALLS` partition (0.5 read units per 4 KB
  read), then each view's photo through CloudFront (free tier), once per
  visit: the app keeps the features in memory while the screen is open.
- Per route or view saved: one write (and for a view, one upload).

## Not yet

- Walls are matched as flat: a strongly three-dimensional face (a deep
  roof, an arête seen from the side) matches from fewer angles.
- Live frames aren't smoothed between matches; the drawing can jitter a
  pixel or two.
