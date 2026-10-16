# Match scores

How likely a climber and a plan end in a **match**: the climber asks to
join and every member of the group says yes. Only [admins](sign-in.md#admins)
see the scores, to judge the model before anyone else does. The deck's
order stays the [fit + 2 × nearness ranking](api.md#the-decks-ranking).

A walkthrough of the code, with references to its key sections:
[docs/match-scores.md](../docs/match-scores.md).

The scores come from **[aityx](https://aityx.ai)**, a decision API: the
API sends a decision model ([grigri_api/src/match/model.json](../grigri_api/src/match/model.json))
and one climber's and one plan's facts to `POST <AityxUrl>/v1/systemone`,
which runs the model on them as given, deterministically and without AI
(System One), and answers with typed answers. aityx keeps nothing: the
model travels with every call.

## The facts

The API works them out ([facts.ts](../grigri_api/src/match/facts.ts));
the model never sees a profile, a plan or a place:

| Fact | What |
|---|---|
| `discipline_climbed` | whether the climber has grades for the plan's discipline, on its scale |
| `grades_short` | how many grades the plan's easiest grade is above the climber's hardest (0 when within reach) |
| `grades_over` | how many grades the climber's easiest grade is above the plan's hardest |
| `distance_known`, `distance_km` | the distance from the climber's nearest location or area to the plan's point, when both are known (0 otherwise) |
| `group_size` | the people in the group, the organizer included: each one must say yes |
| `open_requests` | the other requests waiting on the plan (the climber's own left out) |
| `days_until_start` | days until the plan starts |

No names, ages, photos, bios or coordinates leave the API.

## The model

Each decision is a formula or a first-match table whose every row says
why (`# why`):

- **grade_fit**, 0 to 1: 1 in the climber's grades; one, two, three
  grades short 0.6, 0.35, 0.15, and 0 from four; one, two, three grades
  above 0.85, 0.7, 0.5, and 0.3 beyond (being below the plan's grades
  costs more than being above them); 0 for a discipline the climber
  doesn't climb.
- **nearness**: e^(−km / 50), as the deck's; 0.25 when unknown.
- **crowding**: 0.5 with 20 or more others waiting, 0.75 with 10 or more,
  else 1.
- **timing**: 0.4 within 12 hours, 0.8 within two days, 1 within a
  month, 0.85 beyond.
- **group_odds**: 0.9 for each member besides the organizer (one more
  yes needed), times crowding.
- **match_likelihood** = grade_fit × (0.2 + 0.8 × nearness) × group_odds
  × timing, to two decimals: distance weighs strongly (a plan 100 km
  away keeps about 30% of its odds; one of unknown distance 40%).
- **match_level**: great from 0.7, good from 0.45, possible from 0.2,
  else long shot.
- **match_reason**, the first that applies: doesn't climb the discipline;
  two or more grades short (too hard); three or more above (too easy);
  starts within 12 hours; more than 100 km away; five or more in the
  group; ten or more waiting; in grades and within 25 km; in grades;
  else within a grade or two.

Model v1 (nearness weighed 0.5 + 0.5 ×) was checked live against aityx
production on 2026-10-16: five sample cases gave the scores, levels and
reasons worked out by hand. v2 (0.2 + 0.8 ×, the same day) changes only
that formula; worked by hand, in grades, 12 km away, a group of two,
three days out is 1 × (0.2 + 0.8 × 0.79) × 0.9 × 1 = 0.75, great, in
grades and nearby.

Changing a weight is an edit to the model file, not to the code. To
check a change, run the same facts through the old and the new model
(aityx's console replays them) before deploying it.

## On an admin's deck

`GET /api/discover` from an admin also carries `scores`, `{planId:
{"score", "level", "reason"}}`, for the deck's best 30 plans, scored live
(10 calls to aityx at once, 3 s each at most, none started after 4 s, so the deck answers within about 7 s). Best effort: a plan aityx
didn't score has none, and the deck never fails for it. Nobody else's
deck is scored.

The card shows it under the plan: **"Match 72% · good"** in the level's
color (great olive, good sky, possible granite, long shot clay), and the
reason beside it ("In your grades and nearby").

## The scoring run and the scores table

A separate function, `<stack>-scorer`
([src/scorer.ts](../grigri_api/src/scorer.ts)), scores **every profile
against every upcoming plan it isn't in** and writes the scores to their
own table, `<stack>-scores`. The demo showcase's made-up climbers are
left out. A run scores at most 5,000 pairs (the soonest plans first),
8 calls at once; the rest it counts as skipped.

It runs on demand: `STAGE=prod bash scripts/score-matches.sh` (or `rc`,
`local`) invokes it with an administrator's credentials and prints the
run's summary. Nothing schedules it.

The table ([store/scores.ts](../grigri_api/src/store/scores.ts)):

| Item | pk | sk | Index keys | Holds |
|---|---|---|---|---|
| Score | `CLIMBER#<climberId>` | `PLAN#<planId>` | gsi1: `RUN#<runId>`, `<score>#<climberId>#<planId>` | `score`, `level`, `reason`, `runId`, `scoredAt`, `ttl` (a day after the plan starts) |
| Latest run | `META` | `RUN` | | `run`: when it started and finished, profiles, plans, pairs, scored, failed, skipped, aityx input tokens |

One climber's score for one plan is one read; a climber's scores, one
query; a run's scores best first, one query of its gsi1 partition. A
pair a later run no longer scores (the climber joined the plan) keeps its
old score, out of the latest run's partition, until it expires.

The run lists profiles from the app's table's gsi1 `CLIMBERS` partition,
which every profile saved joins. Profiles saved before it existed join
it with `STAGE=prod bash scripts/index-climbers.sh` (once per stage; an
administrator's credentials, since it scans the table).

## The Admin tab's preview

`GET /api/admin/scores` (admins only) → `{"run": <the latest run> | null,
"scores": [{"climberId", "planId", "score", "level", "reason",
"scoredAt"}] (its best 20), "plans": {id: Plan}, "climbers"}`.

The Admin tab opens with a **Match scores** card: when the latest run
finished, how many pairs it scored of how many, for how many people and
plans, any failed or over the cap, then its best 20: who → which plan,
the reason, and the score tag. Before the first run it says how to run
one.

## The key

The aityx API key is a secret: the `AityxApiKey` stack parameter
(`GRIGRI_AITYX_API_KEY` in `.env` or the environment for
`scripts/deploy.sh`, the repository secret of the same name in CI), in
the API's and the scoring function's environment only. It never reaches
the app and is never logged. `AityxUrl` defaults to
`https://api.aityx.ai`; a stage key needs aityx's stage
(`GRIGRI_AITYX_URL`). Without a key there are no scores: decks carry
none and the scoring function refuses to run.

## Cost

- **aityx**: System One bills $0.042 per million input tokens, output
  free. A call carries the model: about 1,600 input tokens (measured
  2026-10-16), about $0.00007 per call. An admin's deck is up to 30 calls
  (about $0.002); a full run of 5,000 pairs about $0.33.
- **The scores table**: on demand, nothing while idle; a run writes one
  item per pair (5,000 writes, about $0.006) and the run's summary; the
  preview reads about 20 items. Expired scores are deleted free (TTL).
- **The scoring function**: 256 MB arm64, invoked only by hand; a full
  run is a few minutes, well under a cent.

Why aityx rather than code: the weights are product judgements that
change; in a model they're data, each rule with its reason, and the
receipt shows which rule fired.
