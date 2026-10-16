# Screens

Before the tabs: **sign-in** (the first one makes my profile from my
Google account, with no screen of its own; [sign-in](sign-in.md)). Then
five tabs, in a bottom navigation
bar: Discover, Plans, Chats, Notifications and Profile, and a sixth,
**Admin**, for [admins](sign-in.md#admins). The bar's labels are short
words in 11 pt, so each fits on one line on a 360 dp wide phone, and
every tab always shows its label, six tabs too: in English **Find**, **Plans**,
**Chats**, **Alerts**, **Me** and **Admin** (Spanish Buscar, Planes, Chats,
Avisos, Yo; German Suche, Pläne, Chats, Infos, Ich; French Trouve, Plans,
Tchats, Alertes, Moi; Portuguese Buscar, Planos, Chats, Avisos, Eu;
Catalan Cerca, Plans, Xats, Avisos, Jo). The Notifications screen's title
is "Alerts" in English.

| Tab | Shows |
|---|---|
| **Discover** | The plans deck ([matching](matching.md#the-deck)), best first, with ✕ and ✓ buttons (centered) and, to the right of ✓, a smaller share button, and ⟳ to refresh, which also brings back the plans I passed on (I may have changed my mind). Each card, in slightly smaller text, shows the plan (date and time on separate lines, no distance; notes cut to three lines with "…") and the organizer with **+N** for the rest of the group, whose list opens when tapped. Without a location on my profile, the app first takes my location from the phone or browser ([matching](matching.md)); only when the device can't tell (and I have no area either) does a line above the deck say "Set where you climb to see plans near you first." with **Set** (the profile editor). Empty: "No plans to join right now" and **New plan**. |
| **Plans** | The plans I'm in, soonest first (discipline, place, date and time range, the group's avatars, "Organizing" or "Accepted", "N to review", and ⋮ with **Cancel the plan**, after the same confirmation as on the plan screen), then **Asked to join**: "Pending" and who it's waiting for, with **Nudge** to remind them (once every 12 hours; "Nudged" until then; a snackbar confirms it), or "Declined" with ✕ to dismiss. **New plan** (a floating button). Pull to refresh. Empty: "No plans yet" and **New plan**. |
| **Chats** | One group chat per plan I'm in, most recent first, with the last message and "N to answer" when join requests wait for my answer. The tab's badge counts those requests. Empty: "No chats yet" and **Find a plan** (to Discover). |
| **Notifications** | Join requests for my plans, nudges to answer them, and the groups' answers to mine ([matching](matching.md#notifications)). The tab's badge counts the unread ones. Empty: "Nothing yet". |
| **Profile** | My profile as others see it: my photo (tap to see it whole), name and age, about, climbs, and gear with its photos (tap one to see it whole); **Edit profile**; **Where you climb** (private, only I see it): my location, a spinner while the app takes it from the device, "Set your location" when it has none; tap it to pick a place or "Use my current location" ([matching](matching.md)), saved at once, without the editor; the **Language** picker ([languages](i18n.md)); in ⋯, **Sign out** and **Sign out everywhere** (on every phone and browser, this one too), each after a confirmation. Then my [roles](roles.md), from rbacr. The version at the bottom. |
| **Admin** | Admins only: first the **Match scores** card, the latest [scoring run](match-scores.md#the-admin-tabs-preview) and its best 20 scores; then every open join request, anyone's: who (avatar, name and age; tap for their profile) and when they asked, the plan (discipline, place, where it is, date), how many of the group said yes, its grades, and **Approve** (they join now) and **Reject**, each after a confirmation. Its badge counts the requests. Empty: "No open requests". |

- **Sign-in**: the app's name and tagline on the mountain night gradient,
  and **Sign in with Google** (Google's own button on the web). See
  [sign-in](sign-in.md).
- **Plan** (from Plans, a notification, or a chat's title): the plan
  highlighted, my request's status when I'm not in it yet (Pending, N of
  M said yes, or Declined), the group (tap someone for their profile),
  who's asking to join and how many have said yes ("Answer in the chat",
  or "You said yes"), and the plan's [photos](pics.md): **Your Pics**
  (members only: a row of thumbnails led by an add tile, camera or
  gallery, with a progress ring while one goes up; "No photos yet" when
  empty; tap one to see it whole, who added it or sent it in the chat,
  and **Delete photo** for whoever added it or the organizer, after a
  confirmation that says a chat photo stays in the chat) and **GriGri
  Pics** (everyone: wider thumbnails with the crag's name; tap one for
  the photo, its caption and its credit, "Photo: <author>, <license>",
  and its source, tapped to copy; "No GriGri Pics of this place yet"
  when there are none). Members get
  **Group chat** and **Cancel the plan**. Its confirmation ("Cancel the
  plan?", **Keep it** or **Cancel it**) says what happens: alone, the plan
  and its chat are gone; with others, it leaves my plans and chats while
  they keep it, and, when I organize it, one of them picked at random
  organizes it now; I can't rejoin it. The organizer can **Edit**. "Plan
  gone" when it no longer exists.
- **Plan editor**, top to bottom:
  - **Climbing**: the discipline.
  - **Where**: one search field, "Sector, crag or gym". As I type it
    lists the [sector index](sectors.md)'s matches, each with where it
    is; picking one shows where it is under the field. A place the index
    lacks is just typed in. Required.
  - **When**: the day, then a time range slider, from and to, in half
    hours between 05:00 and 23:30 (09:00–17:00 to start); the start must
    be still to come.
  - **Grades**: the European / American switch (my grade system,
    everywhere in the app), then a range on the discipline's scale,
    starting at my own grades.
  - **Notes**, then **Publish the plan** (Save when editing).

  There's no title and no group size.
- **Profile editor**: my photo (tap it: take a photo, where the device has
  a camera, choose one, or remove it), name, age (optional, 16–99
  when given), about, **where you climb** ("Only you see it"): my
  location (tap to pick, ✕ clears) and up to 5 other areas (chips: ✕
  removes one, **Add an area** adds one), then the European / American grade switch, per
  discipline a switch and a grade range, and gear: the gear chips, then
  its photos (✕ removes one, + adds one, up to 6), then **Language**:
  System default or one of the app's six languages, each named in itself,
  switching the app at once ([languages](i18n.md)). Saving uploads the new
  photos first, and then refreshes the deck, which my grades, location
  and areas rank.
- **Location picker** (full screen, for the location or an area): a
  search of the [sector index](sectors.md) ("A crag or gym near there";
  "Kept to about 1 km, and only you see it."), listing only places with a
  point; tap one to take it, as "name, area, country". Before I type,
  **Use my current location** takes where the phone or browser is (named
  "Near area, country" after the closest place in the index), or says
  "Couldn't tell where you are. Search for a place instead."
- **Match**: see [matching](matching.md#matches).
- **Chat**: the group's avatars, the plan's place and date, the plan pinned
  under the bar, then a callout for each join request still waiting for
  my answer ("Wants to join · your answer", their avatar and name, N of M
  said yes, ✕ / ✓; tap them for their profile), then the messages (mine on
  the right in pine, others' on the left with their name), the join and
  leave notes, the join request cards, and a message box with an attach
  button ("Add a photo or video": take a photo, choose a photo, record a
  video, choose a video; the camera options only where there's a camera).
  The picked photo or video shows above the box (a thumbnail, or a video
  icon, with its size and ✕), and while it sends, "Uploading…" and a
  progress bar. In the messages a photo shows inline, cropped to a
  240×180 frame (tap to see it whole, pinch to zoom); a video shows as a
  poster with ▶ that loads nothing until tapped, then plays full screen
  (tap to pause; a scrubbable progress bar; "This video can't be played."
  if it fails). Chats previews them as "📷 Photo" or "🎬 Video" (or 📷/🎬
  and their text).
- Tapping a person anywhere opens their whole profile in a sheet.
- While something loads, a spinner; when an action fails, the server's
  message at the bottom of the screen (or the app's own, in the user's
  language, when the server couldn't say).
- Every text is in the user's [language](i18n.md); the quoted labels
  here are the English ones.

The browser tab's title is **Grigri** (**🧪 Grigri RC** on the RC site).
The look is the app's [theme](theme.md).
