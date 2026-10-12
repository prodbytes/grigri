// Bundles the Lambdas with esbuild: the API (src/handler.ts) into
// dist/index.mjs and the live updates' IoT authorizer (src/authorizer.ts)
// into dist/authorizer.mjs (one zip, two handlers). Each is an
// ES module for Node.js 22 with the AWS SDK inside it (pinned by
// package-lock.json, rather than whichever SDK the runtime ships). The
// template's Code points at dist/, which `aws cloudformation package` zips.
import { build } from 'esbuild';
import { rm } from 'node:fs/promises';

await rm('dist', { recursive: true, force: true });
await build({
  entryPoints: { index: 'src/handler.ts', authorizer: 'src/authorizer.ts' },
  outdir: 'dist',
  outExtension: { '.js': '.mjs' },
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  minify: true,
  sourcemap: false,
  legalComments: 'none',
  // Some of the SDK's dependencies are CommonJS and call require().
  banner: {
    js: "import { createRequire as __grigriRequire } from 'node:module'; const require = __grigriRequire(import.meta.url);",
  },
  logLevel: 'info',
});
