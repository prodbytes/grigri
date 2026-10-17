# Screens

Before the tabs: **sign-in** (the first one makes my profile from my
Google account, with no screen of its own; [sign-in](sign-in.md)). Then
five tabs, in a bottom navigation
bar: Discover, Plans, Chats and Notifications, then **Ads**
while I'm [Premium](premium.md) ([ads](ads.md#the-ads-tab)), **Admin**
for [admins](sign-in.md#admins), and Profile, always last (the
rightmost). The bar's labels are short
words in 11 pt, so each fits on one line on a 360 dp wide phone, and
every tab always shows its label, seven tabs too: in English **Find**, **Plans**,
**Chats**, **Alerts**, **Ads**, **Admin** and **Me** (Spanish Buscar, Planes, Chats,
Avisos, Yo; German Suche, Pläne, Chats, Infos, Ich; French Trouve, Plans,
Tchats, Alertes, Moi; Portuguese Buscar, Planos, Chats, Avisos, Eu;
Catalan Cerca, Plans, Xats, Avisos, Jo). The Notifications screen's title
is "Alerts" in English.

| Tab | Shows |
|---|---|
| **Discover** | The plans deck ([matching](matching.md#the-deck)), best first, with raised round ✕ and ✓ buttons (centered, ✓ bigger) and, to the right of ✓, a smaller share button, and ⟳ to refresh, which also brings back the plans I passed on (I may have changed my mind). Now and then, between plans, an approved [ad](ads.md#on-the-deck), drawn the same way (its photo full-bleed, its text over a dark fade, an **Ad** tag): ✓ opens its link in the browser, ✕ skips it. Each plan's card, in slightly smaller text, is drawn like a dating app's profile card: the plan's crag photo (its [GriGri Pics cover](pics.md#on-the-deck)) fills the top edge to edge, or, without one, a backdrop in the discipline's colors with a faint mountain; over it, on a dark fade, at the top the discipline, beside it a pill with the plan's type and its icon (**Shared**, **Open: join at once** or **Guided · €60**), and an admin's match score, and at the bottom the place in large bold type, the area, the date and the time on separate lines (no distance), the grades and **Your grades**, and the photo's crag and credit. Below the photo, always in view, the organizer (avatar, a **Demo** tag above the name on a demo plan, the name on one line, cut with "…" when long, and "Organized by", in smaller text) with the others' avatars and **+N**, which opens the group's list; scrolling the card shows the notes (cut to three lines with "…") and the organizer's profile. Without a location on my profile, the app first takes my location from the phone or browser ([matching](matching.md)); only when the device can't tell (and I have no area either) does a line above the deck say "Set where you climb to see plans near you first." with **Set** (the profile editor). Swiping right on an open plan opens the match screen at once (no "request sent" snackbar). The card has no ⋮ (the row hadn't room for the name): report the plan from its screen, or the organizer from their profile sheet; an ad's ⋮, at its top right, **Report** and **Block** its owner ([moderation](moderation.md)). Empty: "No plans to join right now" and **New plan**. |
| **Plans** | The plans I'm in, soonest first (discipline, place, date ("+N days" for more days, or "Date to be decided") and time range, the group's avatars, "Organizing" or "Accepted", "N to review", and ⋮ with **Cancel the plan**, after the same confirmation as on the plan screen), then **Asked to join**: "Pending" and who it's waiting for, with **Nudge** to remind them (once every 12 hours; "Nudged" until then; a snackbar confirms it), or "Declined" with ✕ to dismiss. **New plan** (a floating button). Pull to refresh. Empty: "No plans yet" and **New plan**. |
| **Chats** | One group chat per plan I'm in, most recent first, with the last message and "N to answer" when join requests wait for my answer. The tab's badge counts those requests. Empty: "No chats yet" and **Find a plan** (to Discover). |
| **Notifications** | Join requests for my plans, nudges to answer them, and the groups' answers to mine ([matching](matching.md#notifications)); for admins, "New reports to review", which opens Admin → Reports. None about people I blocked. The tab's badge counts the unread ones. Empty: "Nothing yet". |
| **Profile** | My profile as others see it: my photo (tap to see it whole), name and age, about, climbs; **Edit profile**; my **Gear** card: what I own and its photos (tap one to see it whole), with **Edit gear** (or, with none, a line on what it's for and **Add your gear**), which opens the gear editor ([gear](gear.md)); **Where you climb** (private, only I see it): my location, a spinner while the app takes it from the device, "Set your location" when it has none; tap it to pick a place or "Use my current location" ([matching](matching.md)), saved at once, without the editor; **Grigri Premium** ([premium](premium.md)): the pitch, then on Android and the web **$20 a month** / **$200 a year** (each opens Stripe Checkout in the browser) and **I've paid: check again**; on iOS the App Store's localized prices (**$19.99 a month** / **$199.99 a year**, bought through the App Store's sheet; a spinner while a purchase goes through), the subscription's terms (auto-renewing, price and period, charged to the Apple ID, cancel at least 24 hours before the period ends in the App Store account settings), **Privacy policy**, **Terms of use (EULA)** and **Restore purchases**, and no Stripe at all ("The App Store can't be reached right now." with **Try again** and no buy buttons when its products don't load); once subscribed, "Premium: renews on <date>" (or "ends on <date>") and **Manage subscription** (Stripe's billing portal, or the App Store's subscriptions for one bought there; on iOS, none for one bought through Stripe); the **Language** picker ([languages](i18n.md)); in ⋯, **Sign out** and **Sign out everywhere** (on every phone and browser, this one too), each after a confirmation. Then my [roles](roles.md), from rbacr; **Blocked people** (whom I [blocked](moderation.md#blocking-someone), each with **Unblock**; "You haven't blocked anyone."); **Privacy policy** and **Support**, which open the site's `/privacy.html` and `/support.html` in the browser ([app-store](app-store.md)); and **Delete account** (in clay): a confirmation that says what's deleted (profile and photos, chat messages and photos, requests, ads; I leave every plan; Premium by card cancelled at once, an Apple subscription to cancel in iOS Settings; signed out everywhere), with a box to tick ("I understand this can't be undone") before **Delete for good** works; done, back to the sign-in screen ([sign-in](sign-in.md#deleting-my-account)). The version at the bottom. |
| **Ads** | Premium only ([ads.md](ads.md#the-ads-tab)): my ads, newest first, with their review status and **Delete**; **New ad**: text, link, a photo or video, a preview of the card, and **Send for review**. |
| **Admin** | Admins only ([admin.md](admin.md)), with a sub-navigation: **Users**, **Ads** ([ads.md](ads.md#admin--ads): how often the deck shows ads, and the ads waiting, approved or rejected, with **Approve** / **Reject**) and **Reports** ([moderation](moderation.md#answering-reports-admins): each open report's kind, reason, when, whose, "Reported by", the reporter's words and the content as it was, with **Dismiss**, **Remove content** and **Block climber**; "No reports to review."). Users: everyone, by name (avatar and name; tap for their profile), "Blocked" under a blocked person, and **Block** (after a confirmation) or **Unblock**; nothing on my own row. |

- **Sign-in**: the app's name and tagline ("Join a climbing plan: make
  one, or swipe right on one, and climb together.") on the mountain night gradient,
  **Sign in with Google** first (Google's own button on the web), then
  **Sign in with Apple** on every platform (Apple's white style, the
  same width as Google's, its label on one line). See [sign-in](sign-in.md#the-sign-in-screen).
- **Plan** (from Plans, a notification, or a chat's title): the plan
  highlighted (every one of its days, or "Date to be decided"), my request's status when I'm not in it yet (Pending, N of
  M said yes, or Declined), the group (tap someone for their profile),
  its **Gear**: what the plan needs for its discipline ticked off against
  the members' gear, a discreet tan line naming what's missing (or "The
  group has all it needs"), and each member's gear ([gear](gear.md)),
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
  when there are none), and, when a climbing guide covers the plan's
  place, **Area guide**: a card for the area that opens its page and the
  whole guide ([guides](guides.md#in-the-app)). Premium climbers get **Routes on the rock** (the
  [route finder](route-finder.md#the-screens)). Members get
  **Group chat** and **Cancel the plan**. Its confirmation ("Cancel the
  plan?", **Keep it** or **Cancel it**) says what happens: alone, the plan
  and its chat are gone; with others, it leaves my plans and chats while
  they keep it, and, when I organize it, one of them picked at random
  organizes it now; I can't rejoin it. The organizer can **Edit**; on
  others' plans, ⋮ has **Report** and **Block <organizer>**. "Plan
  gone" when it no longer exists.
- **Plan editor**, top to bottom:
  - **Climbing**: the discipline.
  - **Where**: one search field, "Sector, crag or gym". As I type a
    name it lists the [sector index](sectors.md)'s matches, **nearest
    to me first** when I've set where I am (else best match first), each
    with where it is and how far; with nothing typed it offers the
    nearest crags. Picking one shows where it is under the field. A place
    the index lacks is just typed in. Required.
  - **When**: the start date (the next Saturday for a new plan), with ✕
    to **leave the date open** ("Date to be decided"); then the plan's
    more days as chips (✕ removes one) and **Add a day** (a date after
    the first, not already in the plan; up to 13 more), only while it
    has a start date; then a time range slider, from and to, in half
    hours between 05:00 and 23:30 (09:00–17:00 to start), the same each
    day, while it has a start date. A hint says the date is optional and
    more days make a longer trip. Moving the start date drops the more
    days not after it. The first day's start must be still to come.
  - **Grades**: the European / American switch (my grade system,
    everywhere in the app), then a range on the discipline's scale,
    starting at my own grades.
  - **Who can join**: Shared (a group icon, the default), Open or Guided (off without Premium), with a
    line on what the chosen one means ([plan
    types](matching.md#plan-types-who-decides)). Guided adds **Price per
    climber** (typed with a dot or a comma; required, above 0, at most two
    decimals) and its currency (EUR first), with "Paid to the guide, not
    through Grigri."
  - **Notes**, then **Publish the plan** (Save when editing).

  There's no title and no group size.
- **Profile editor**: my photo (tap it: take a photo, where the device has
  a camera, choose one, or remove it), name, age (optional, 16–99
  when given), about, **where you climb** ("Only you see it"): my
  location (tap to pick, ✕ clears) and up to 5 other areas (chips: ✕
  removes one, **Add an area** adds one), then **Grade system**: the
  European / American switch on its own, each option showing a route and
  a boulder grade written its way (🧗 6a 🪨 7A, 🧗 5.10b 🪨 V6), then
  **What you climb**: per discipline a switch and a grade range, then **Language**:
  System default or one of the app's six languages, each named in itself,
  switching the app at once ([languages](i18n.md)). Saving uploads the new
  photo first, and then refreshes the deck, which my grades, location
  and areas rank.
- **Gear editor** (from the Profile tab's Gear card): chips under **For
  the group** (rope, quickdraws, trad rack, belay device, crash pad, car)
  and **Your own** (harness, helmet, climbing shoes), then **Photos** (✕
  removes one, + adds one, camera or library, up to 6); **Save** uploads
  the new photos, then saves ([gear](gear.md)).
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
  and their text). A long press on someone else's message offers
  **Report** and **Block <name>**; a join request card has ⋮ with
  **Report** (their profile) and **Block**. Messages of people I blocked
  don't show.
- Tapping a person anywhere opens their whole profile in a sheet, with ⋮
  (not on mine): **Report** and **Block <name>**.
- **Report**: "Why are you reporting this?" with Spam, Harassment,
  Inappropriate content, Fake profile and Other as chips, "Anything else
  we should know? (optional)", and **Send report** (once a reason is
  picked); then "Thanks, we'll review it within 24 hours." **Block**:
  "Block <name>?" with what it does, then "<name> is blocked."
  ([moderation](moderation.md)).
- While something loads, a spinner; when an action fails, the server's
  message at the bottom of the screen (or the app's own, in the user's
  language, when the server couldn't say, or when the
  [filter](moderation.md#the-filter) refused the text: "Please keep it
  friendly: that has words Grigri doesn't allow.").
- Every text is in the user's [language](i18n.md); the quoted labels
  here are the English ones.

The browser tab's title is **Grigri** (**🧪 Grigri RC** on the RC site).
The look is the app's [theme](theme.md).
