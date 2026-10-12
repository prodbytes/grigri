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
  the backend API (GA starts empty), and polling.
- [Sign-in](sign-in.md): Google only, per platform; creating the profile
  after the first sign-in; the local dev sign-in; admins.
- [Screens](screens.md): sign-in, the five tabs (and Admin), the plan and
  profile editors, the match screen, the chat and the empty states.
- [Sectors](sectors.md): the searchable index of climbing sectors, crags
  and gyms that a plan's "where" picks from, built from OpenStreetMap.
- [Roles](roles.md): my roles in Grigri, from rbacr, at the end of the
  profile.
- [Theme](theme.md): dark, in mountain colors.
- [Platforms](platforms.md): Android, iOS and the web; app IDs and iOS
  signing.

**Development and operations**

- [Development environment](dev-environment.md): devbox, the dev
  container, `devbox services up` and the health monitor, the run scripts.
- [Release builds](release.md): versions, tags and the Release workflow.
- [API](api.md): the backend's contract, which the app codes against.
- [Deploy](deploy.md): the web app at https://grigri.nu01.com and the
  release candidate at https://rc.grigri.nu01.com.
