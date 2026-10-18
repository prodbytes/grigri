# Live updates

The app hears about changes as they happen (a chat message, a join
request, an answer, a plan edit) instead of asking every few seconds. It
keeps one **MQTT over WebSocket** connection to **AWS IoT Core** while
it's in the foreground; the API publishes a tiny **hint** to each affected
climber's topic after a change, and the app refetches what the hint names
through the API. Polling stays as a slow safety net. Costs, keep-alive
pings included: [backend.md](backend.md#live-updates-cost).

## Hints, not data

A hint says *what kind of thing changed*, never the thing itself:

```json
{"kind": "message", "planId": "Hx3…"}
```

| Kind | Sent to | When | The app refetches |
|---|---|---|---|
| `message` | the plan's members | a chat message | that chat's new messages (if it's one of my plans) |
| `request` | the plan's members | someone asks to join; a member says yes but not everyone has; a member says no (the members) | requests to review, notifications; the plan's chat and open requests if loaded |
| `notice` | the requester; the members who haven't answered a nudge; every admin | their request was declined; the requester nudged them; someone reported something ([moderation](moderation.md#answering-reports-admins)) | notifications, my plans |
| `match` | the newcomer | everyone said yes | my plans, requests, notifications (the match screen opens as before) |
| `plan` | the plan's members | someone joined or left; the organizer edited the plan | my plans, requests; the plan's chat and open requests if loaded |

- The one who made the change gets no hint (their own app already shows
  it).
- Everything the app then sees comes from the API, which checks who may
  see what, as always. A hint can't leak data: it carries only a kind and
  a plan id, on a topic only its climber can read.
- Hints are best effort (QoS 0): a lost one is caught by the slow polling.
  Publishing never fails or slows a request by more than 1.5 s.

## Topics and connecting

- Each climber has one topic subtree, `grigri/<stage>/climbers/<climberId>/`;
  the API publishes on `…/hint`. Stages are `prod`, `rc` and `local`.
- `GET /api/realtime` ([api.md](api.md#routes)) says where to connect:
  `{"url": "wss://<IoT Data-ATS endpoint>/mqtt", "authorizer":
  "<prefix>-api-realtime", "topic": "grigri/<stage>/climbers/<me>/#",
  "clientIdPrefix": "<me>-"}`, or `{"url": null}` when live updates are
  off. The app never hardcodes the endpoint.
- The app opens `<url>?x-amz-customauthorizer-name=<authorizer>&token=<session token>`
  (MQTT 3.1.1, subprotocol `mqtt`, clean session, keep-alive 60 s) as
  client `<clientIdPrefix><10 random characters>`, and subscribes to
  `topic` at QoS 0. The token is the API's own session token
  ([sign-in.md](sign-in.md)); browsers can't set headers on a WebSocket,
  hence the query string. It's never logged (mqtt_client's logging is off,
  and connection errors are dropped unprinted).

## The authorizer

An IoT Core **custom authorizer** (`<prefix>-api-realtime`, unsigned:
the session token is the secret) runs a small Lambda,
`<prefix>-api-realtime-auth` (Node.js 22, arm64, 128 MB), on every
connection:

- It takes the token from the URL's query (or the MQTT password), looks
  up the session by its hash exactly as the API does (an unknown, expired
  or signed-out session is refused; a use slides it, as any request
  does), then the climber id of its account.
- It answers a policy that allows **only**: `iot:Connect` as a client id
  starting with `<climberId>-`; `iot:Subscribe` to topic filters under
  `grigri/<stage>/climbers/<climberId>/`; `iot:Receive` from topics under
  the same. No `iot:Publish`, no other climber's topics. Climber ids are
  16 URL-safe characters, so no id is a prefix of another and none holds
  a policy or MQTT wildcard.
- It refuses (fails closed) without a token, for an unknown session,
  without a profile, for someone else's client id prefix, and on any
  error.
- `refreshAfterInSeconds` **3600**: IoT Core asks again every hour, so a
  signed-out session's connection ends within the hour;
  `disconnectAfterInSeconds` **86400** (IoT Core's maximum): every
  connection reconnects, and is checked afresh, within a day.

## The app

- One connection, only while the tabs are on screen and the app is in
  the foreground (HomeShell): it opens after sign-in and on resume, and
  closes in the background, on sign-out and when the tabs go.
- Reconnects after a drop with backoff: 1 s, 2 s, 4 s … up to a minute,
  each times a random 0.5–1 (so clients that dropped together spread
  out); back to 1 s once connected. After a reconnect it refetches my
  plans, requests, notifications and loaded chats, for hints missed
  meanwhile. A 401 from `GET /api/realtime` is a sign-out, as anywhere.
- **Polling as a safety net** ([matching.md](matching.md#refreshing)):
  while connected, the regular refresh runs every **2 minutes** instead
  of 15 seconds, and an open chat every **minute** instead of 3 seconds;
  when the connection drops, both go back to their usual pace at once.
  With live updates off (`{"url": null}`), the app just polls as before.
- `mqtt_client` (pinned, 10.11.11) with the browser's WebSocket on the web
  and `dart:io`'s on Android and iOS.

## Local

Floci's own MQTT broker plays IoT Core: the app connects to
`wss://local.grigri.nu01.com:2543/mqtt` (Floci's HTTPS port, same
certificate), and the local function publishes hints to it over MQTT.
Floci has no custom authorizers, so the local broker is open, like dev
mode. Details and why: [dev-environment.md](dev-environment.md#live-updates).
