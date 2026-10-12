# grigri_index

The site root. Its only page, [site/index.html](site/index.html), sends
visitors to the app at `/app/`: a script redirect (`location.replace`,
keeping any query string), a `meta refresh` for browsers without
JavaScript, and a plain link as a last resort. Its favicon,
[site/favicon.png](site/favicon.png), is a copy of the app's
(`grigri_app/web/favicon.png`); copy it again when the icon changes.

Only [site/](site) is served, so this README isn't.

## Running it

`devbox services up` serves it as `5-index`, on http://localhost:2113/
(`INDEX_PORT`), with Python's `http.server` bound to 127.0.0.1. In
production it's the CloudFront distribution's default origin
([grigri_infra/site.yaml](../grigri_infra/site.yaml)).

Edits to `site/` show up on the next request; nothing needs restarting.
