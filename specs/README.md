# Grigri — software specification

The current specification of the product, one file per feature. Update the
feature files a request changes, and add a file when a request adds a
feature. [requests.md](requests.md) holds the history of requests that shaped
it.

## Product

Grigri is a matchmaking app for sports, climbing first, like Tinder or
Happn: swipe right or left. People match on **plans** (an outing: what,
where, when, which grades), which are separate from their profiles, and
a plan's group grows one newcomer at a time, when every member says yes.
Each match opens the plan's group chat.

## Features

**App**

- [Matching](matching.md): profiles and plans, the Discover deck,
  join requests answered in the group chat, the group's unanimous yes, my requests' status (pending, accepted,
  declined), matches, notifications and group chats; the data, all from
  the backend API (GA has real data plus the demo showcase), and refreshing it.
- [Live updates](live-updates.md): push over MQTT (AWS IoT Core) while the
  app is open: the API's hints, the custom authorizer that keeps each
  climber to their own topic, reconnecting, and polling as a slow safety
  net.
- [Sign-in](sign-in.md): Google only, per platform; the profile made
  from the Google account at the first sign-in; admins.
- [Admin](admin.md): the Admin tab, for admins, with a sub-navigation:
  Users, everyone, to block (they can't use Grigri, and their plans
  leave the deck) or unblock; and Ads, to approve or reject ads.
- [Screens](screens.md): sign-in, the five tabs (and Admin), the plan and
  profile editors, the match screen, the chat and the empty states.
- [Plan photos](pics.md): a plan's **Your Pics** (what members add,
  and every photo sent in its chat) and **GriGri Pics** (Grigri's own
  credited photos of the plan's crag, in their own S3 bucket with their
  metadata as S3 annotations); the loader and its data.
- [Sectors](sectors.md): the searchable index of climbing sectors, crags
  and gyms that a plan's "where" picks from, built from OpenStreetMap.
- [Roles](roles.md): my roles in Grigri, from rbacr, at the end of the
  profile.
- [Match scores](match-scores.md): how likely a climber and a plan end
  in a match, from a decision model run by aityx: on admins' decks, and
  for every profile and plan in the scores table.
- [Languages](i18n.md): English, Spanish, German, French, Portuguese and
  Catalan; the language picker in the profile, kept on the device; the
  translation bundles and the test that keeps them complete.
- [Route finder](route-finder.md) (Premium): routes on the rock through
  the camera, recognized on the phone; recording routes bolt by bolt, and
  learning walls from confirmed views.
- [Premium](premium.md): $20 a month or $200 a year, for advertising
  only; paid through Stripe Checkout, managed in Stripe's billing
  portal, kept in step by Stripe's webhook.
- [Ads](ads.md): Premium climbers' ads (a link, with text over a photo
  or video) in their own Ads tab; approved by admins (Admin → Ads, which
  also sets how often they show); between plans on Discover, where ✓
  opens the link in the browser.
- [Theme](theme.md): dark, in mountain colors.
- [Logging](logging.md): the app's developer log on every platform
  (browser console, device log, a file on phones), scrubbed of account
  data; never shown to users.
- [Platforms](platforms.md): Android, iOS and the web; app IDs and iOS
  signing.

**Backend**

- [Backend](backend.md): the API, its DynamoDB table and photos bucket;
  production real plus the demo showcase, RC and local also seeded with made-up test data;
  sign-in sessions (365 days without use); admins; local dev mode; live
  updates' IoT Core pieces; costs.
- [API](api.md): the routes and JSON shapes the app uses, and sessions.
- [Origin check](origin-check.md): the API answers only through the
  site's CloudFront (a secret header only CloudFront sends), never at its
  own host.

**Development and operations**

- [Development environment](dev-environment.md): devbox, the dev
  container, `devbox services up` and the health monitor, the run scripts.
- [Release builds](release.md): versions, tags and the Release workflow.
- [API](api.md): the backend's contract, which the app codes against.
- [Deploy](deploy.md): the web app at https://grigri.nu01.com and the
  release candidate at https://rc.grigri.nu01.com.
