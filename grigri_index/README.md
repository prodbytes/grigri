# grigri_index

The site root: the [landing page](../specs/landing.md) that gets visitors to
sign in. Signed-in climbers (and links with a query string) go straight on
to the app at `/app/`.

| File | Holds |
|------|-------|
| [site/index.html](site/index.html) | The page, static and in English, working without JavaScript |
| [site/redirect.js](site/redirect.js) | Runs first: sends signed-in climbers to `/app/` |
| [site/index.js](site/index.js) | The page's six languages, and GriGri Pics of crags near the visitor, from `/pics/catalog.json` |
| [site/index.css](site/index.css) | The look, in the app's mountain colors |
| [site/favicon.png](site/favicon.png) | A copy of the app's icon (`grigri_app/web/favicon.png`); copy it again when the icon changes |

The CSP for `/` ([grigri_infra/site.yaml](../grigri_infra/site.yaml),
`IndexHeadersPolicy`) allows only `'self'` and no inline code, so scripts
and styles go in their own files.

Only [site/](site) is served, so this README isn't.

## Running it

`devbox services up` serves it as `5-index`, on http://localhost:2113/
(`INDEX_PORT`), with Python's `http.server` bound to 127.0.0.1. Its crag
photos come from `/pics/`, which only the CDN serves, so open it through
Floci: http://grigri.localhost:2114/. In production it's the CloudFront
distribution's default origin.

Edits to `site/` show up on the next request; nothing needs restarting.
