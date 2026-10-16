# Origin check: the API answers only through the site

The API answers **only through the site's CloudFront distribution**
(`https://grigri.nu01.com/api/...`, or the RC site's), never at its own
`execute-api` host. CloudFront adds a secret header to every request it
sends the API, and the API function refuses a request without it. It's
the API's version of the site bucket's origin access control: the secret
never leaves AWS and no client holds it, so the app (web, Android, iOS)
needs nothing new. It already calls the site ([config.dart](../grigri_app/lib/config.dart)).
It's the same mechanism as presence's.

- **Stops**: calls to the API's `execute-api` host that skip CloudFront,
  and with them anything only CloudFront applies (its security headers,
  and a WAF if one is ever added).
- **Doesn't stop**: a script calling through the site's domain with a
  session token it got by signing in with Google, exactly as the app
  does. Nothing a client holds can prove a call came from the app's code;
  only attestation could (Play Integrity, App Attest, a WAF browser
  challenge), which isn't done. A key built into the app or fetched at
  start would add nothing: a script reads it the same way.

## How

- **The header**: `x-grigri-origin-verify`, set on the site distribution's
  `api` origin (`OriginCustomHeaders`,
  [site.yaml](../grigri_infra/site.yaml), parameter `OriginSecret`, no
  echo). CloudFront overwrites a viewer's header of the same name, so a
  caller can neither set nor read it.
- **The check**: the API function's first step, before the body or the
  session ([origin.ts](../grigri_api/src/origin.ts), called from
  [handler.ts](../grigri_api/src/handler.ts)). The function compares the
  value with its `ORIGIN_SECRET` (the API stack's `OriginSecret`
  parameter, no echo) in constant time. Without it: **403**
  `{"error": "use the site"}`. Every route is checked, `/api/health`
  included, since the monitor polls it through the site. An empty secret
  takes every request.
- **Not covered**: the live updates' IoT authorizer (IoT Core calls it,
  not the HTTP API, and it checks session tokens itself), and the seed
  (a direct Lambda invocation with AWS credentials).

## The secret and deploys

- **Where it comes from**: [deploy.sh](../scripts/deploy.sh) takes
  `GRIGRI_ORIGIN_SECRET` (environment or `.env`). Otherwise it derives one
  per stage from `GRIGRI_RBACR_TOKEN`: HMAC-SHA256 of
  `grigri-origin-<stage>`, keyed with the token. The derivation is one-way,
  so prod and RC differ, the token stays secret, and CI needs no new
  secret. It must be 32 or more of `A-Z a-z 0-9 _ -`, and it's never
  logged. Without either, there's no secret: the deploy warns and the API
  answers anyone.
- **Kept**: only in the two stacks' parameters, the function's
  environment and the distribution's configuration. It isn't in Secrets
  Manager or SSM, which would add a charge or a call per cold start.
- **Turning it on takes two deploys**: the site always gets the secret,
  but the API demands it only once the site stack's `OriginVerified`
  output is already `true` (from an earlier deploy). The API deploys
  before the site, so a first deploy has the site start sending the
  header, and the next one turns the check on, with no 403 in between.
- **Smoke test**: once enforced, the deploy also checks that
  `https://<api host>/api/health` answers 403.
- **Local**: the local stack (Floci) passes no secret, so its API answers
  directly, as before.

## Known limits

- **Changing the secret**, for example when the rbacr token is rotated,
  gives a few minutes of 403s between the API's deploy and CloudFront's,
  because the API takes only one secret at a time.
- Anyone in the AWS account who can read the function's or the
  distribution's configuration can read the secret.
- Requests through the site with a valid session can't be told apart
  from the app's (see **Doesn't stop**).

## Cost

Nothing. A header that CloudFront adds and a hash comparison in the
function; no new resources, calls or storage.
