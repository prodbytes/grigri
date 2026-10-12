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
  declined), matches, notifications and group chats; the demo data and
  on-device storage, for now.
- [Screens](screens.md): the five tabs, the plan and profile editors, the
  match screen and the chat.
- [Theme](theme.md): dark, in mountain colors.
- [Platforms](platforms.md): Android, iOS and the web; app IDs and iOS
  signing.

**Development and operations**

- [Development environment](dev-environment.md): devbox, the dev
  container, `devbox services up` and the health monitor, the run scripts.
- [Release builds](release.md): versions, tags and the Release workflow.
- [Deploy](deploy.md): the web app at https://grigri.nu01.com and the
  release candidate at https://rc.grigri.nu01.com.
