# Grigri team chat

Every climber has one chat with **Grigri itself**, to tell us what works,
what doesn't and what they'd like next. Every admin reads them all and
answers as the **Grigri team**.

## The climber's side

- **Always there**: the Grigri team chat is the first row of the Chats
  tab, for everyone signed in, even with no plans (the plans' "No chats
  yet" and **Find a plan** stay below it). Its title is **Grigri team**
  (Equipo Grigri, Grigri-Team, Équipe Grigri, Equipe Grigri, Equip
  Grigri), its avatar the Grigri logo, its preview the last message (or
  the welcome).
- **It opens with a welcome** from the Grigri team, in my language and
  the app's informal voice: "Thanks for climbing with Grigri! We'd love
  to hear what you think: what works, what doesn't, what you'd like next.
  Write to us here anytime." The welcome is the app's own words, never
  stored: a climber who never writes costs nothing.
- **Text only**, with the plan chat's rules: 1–2000 characters, through
  the [filter](moderation.md#the-filter) on objectionable words. No
  photos or videos (the plan chat's uploads are tied to a plan's folder
  and members; the team chat doesn't need them).
- **The team's answers** show as **Grigri team**, with the logo: never
  which admin wrote them.
- **A badge**: an answer badges the Chats tab (counted with the requests
  waiting for my answer) and shows a dot on the team chat's row, until I
  open it. It isn't in Notifications.
- No report or block in it: it's Grigri itself. Admins can still block
  a climber from Admin → Users ([admin](admin.md#blocking)).

## The admins' side

- Admins have their own team chat on top too, and under it, after the
  plans' chats, a **Team chats** section: one row per climber who has
  written, the latest first (at most 100), with the climber's name,
  avatar and last message, and **To answer** while the climber wrote
  last.
- Opening one shows the climber's messages and the team's answers (and
  the welcome the climber saw first). Any admin can answer; the answer
  goes as the Grigri team. For the admins only, each answer says who wrote
  it: "<first name> for the team" ("You for the team" for mine).
- A climber's message badges every admin's Chats tab (the `team`
  notice), and a hint refreshes their list and open chats.

## Who sees what (the API)

- `GET` / `POST /api/team/messages` and `POST /api/team/read` are mine:
  the route takes no id, the chat is the session's climber's. The
  climber's answers never carry `adminId`.
- `GET /api/admin/team`, `GET` / `POST /api/admin/team/{id}/messages` are
  admin only (403 "admins only" otherwise, as every admin route): nobody
  else can list or read anyone's team chat.
- Blocked climbers can't use it (like every profile route).
- Routes and shapes: [api.md](api.md).

## Refreshing and live updates

- Like a plan's chat ([matching](matching.md#refreshing)): an open team
  chat polls every 3 seconds (every minute while the live connection is
  up), asking only for messages after the last one it has (`after=`);
  opening Chats fetches it, and, for admins, the list of team chats.
- A climber's message: the `team` notice (replaced, unread again) and a
  `team` hint to every admin Grigri knows (the `META#ADMINS` list, one
  read: no scan, and no rbacr call per admin, since neither says whose
  chat). An admin's answer: the `team` notice and hint to the climber, a
  hint to the other admins ([live updates](live-updates.md)).
- Opening a team chat marks the `team` notice read
  (`POST /api/team/read`); reading Notifications leaves it alone.

## Data

In the API's one table ([backend](backend.md)):

| Item | pk | sk | Index keys | Holds |
|---|---|---|---|---|
| Team message | `TEAM#<climberId>` | `MSG#<time>#<id>` | | the TeamMessage (`adminId` on the team's answers) |
| Team chat | `TEAM#<climberId>` | `CHAT` | gsi1: `TEAMCHATS`, `<lastTime>#<climberId>` | the last message (its time, first 160 characters, whose): the admins' list |

- A chat is one partition: reading it is one query (`after` as a key
  range); deleting it one query and a batch delete.
- The admins' list is one page of gsi1 `TEAMCHATS`, newest first,
  `Limit` 100: bounded, never a scan. Only climbers who wrote have an
  item there (a sparse key).
- Nothing exists until the climber's first message.
- [Deleting my account](sign-in.md#deleting-my-account) deletes my whole
  team chat, the team's answers too. An admin's deletion leaves their
  answers in others' chats (they show as the Grigri team; the name is
  gone with the profile).

## Cost

Nothing at all for a climber who never writes (the welcome isn't
stored). Each message is one API request and a batch write of two small
items (the message and the chat's last message, plus its gsi1 copy):
about 3 write units, $0.000004 on demand; each admin's notice is one more
write. A chat's polling reads only what's new, in one query. No new
resource: the same table, index, Lambda and IoT Core as plan chats.
