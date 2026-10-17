@AGENTS.md

## Wording: plans, not partners

People in Grigri match with a **plan**, not with a partner. In anything
users read (the app's text in every language, the site, store listings,
seeds and demo data, the match model's reasons):

- Grigri's line is **"Join a climbing plan"**, never "find a partner".
- When partners are worth mentioning, always in the plural:
  **"partners"** (a plan's group), never "a partner".

## Cost comes first

In this project, cost is the most important perspective in design:

- Build on serverless services that cost nothing when idle and little
  when used (pay per request, generous free tiers), never on servers or
  clusters that bill by the hour, unless no serverless option meets the
  requirements.
- When choosing between services or libraries, take the least costly one
  that meets the requirements. Count running costs (requests, storage,
  data transfer, minimum charges) as well as licenses.
- When a change adds or changes a cloud resource, say what it will cost
  and why it's the cheapest option that works.

## Keep the specification up to date

After every user request, update the [specs/](specs/) folder in the same
change:

- Add a dated entry to [specs/requests.md](specs/requests.md) that says what
  was asked and what changed.
- Revise the feature specs the request touches, one file per feature (the
  index is [specs/README.md](specs/README.md)), so they describe the
  software as it is now. Add a feature file, and list it in the index, when a
  request adds a feature. Rewrite or delete statements the request made
  obsolete; don't just append.

## One pull request per change

Every new feature or bug fix starts on a **new branch from `main`**, with its
own pull request:

- Never commit or push directly to `main`.
- Don't bundle unrelated requests into one PR.
- Start from an up-to-date `main` (`git checkout main && git pull`). Stack on
  an unmerged branch only when the new work truly depends on it, and then
  target that branch.
- Always merge: once a PR is ready (tests pass, code reviewed), merge it into
  `main` without asking. If it conflicts, merge `origin/main` into its branch
  in your own worktree, resolve, rerun the tests, push, then merge.
- Include the matching `specs/` update in the same PR as the change.

## Do a barrel roll

"Do a barrel roll" (also written "barrell roll") means: run a complete
cycle, in this order, stopping to report if any step fails:

1. **Commit** the pending changes (each on its own branch and PR, as above,
   with their `specs/` updates).
2. **Rebuild** the app and **run the tests** (`flutter analyze` and
   `flutter test` in `grigri_app/`).
3. **Merge** the open PRs into `main`.
4. **Cut the RC and GA releases**: signed tags on the merge commit at the
   tip of `main` (see [specs/release.md](specs/release.md)), pushed so the
   Release and Deploy workflows run.
5. **Check the live version**: wait for the Deploy and Deploy RC runs to
   finish, then confirm https://grigri.nu01.com/app/version.json and
   https://rc.grigri.nu01.com/app/version.json report the new tags'
   version. Report it updated live, or report the failure (the failing
   run, or the version still live).
6. **Deploy locally**: start the dev servers (`devbox services up`) and
   check they come up healthy.
7. **Redeploy and restart on the Android phone** connected by USB, as a
   release build (`bash scripts/android-install.sh`, or
   `devbox run android-release`): it builds, installs over the app and
   starts it, then checks it runs.
