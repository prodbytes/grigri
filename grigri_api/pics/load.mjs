#!/usr/bin/env node
// Loads GriGri Pics (specs/pics.md) into a stage's pics bucket:
//   1. each photo of pics/crags.json (freely licensed, mostly from
//      Wikimedia Commons; or a guide's, used with permission, whose file
//      is in pics/guide/) not in the bucket yet is downloaded (cached in
//      pics/.cache) or read and put at pics/crags/<crag>/<hash>.<ext>,
//      immutable;
//   2. each photo carries its metadata as an S3 annotation named "grigri"
//      (the crag, its point, the caption, the author and the license):
//      the source of truth, kept on the object itself;
//   3. photos no longer in crags.json are deleted;
//   4. pics/catalog.json is rebuilt from the annotations: the one object
//      the API reads (once per warm function) to look photos up.
// Idempotent: a second run downloads and uploads nothing.
//
// Settings, from the environment:
//   PICS_BUCKET        the bucket (required): <site stack>-pics-<account>,
//                      or grigri-local-pics in Floci
//   AWS_ENDPOINT_URL   Floci's (local), else AWS
//   PICS_CACHE         where downloads are kept (default pics/.cache)
//
// Run by scripts/deploy.sh after the site stack, and locally by
// process-compose (scripts/pics-local.sh) whenever Floci has no catalog.
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  DeleteObjectCommand,
  GetObjectAnnotationCommand,
  ListObjectsV2Command,
  PutObjectAnnotationCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

const here = dirname(fileURLToPath(import.meta.url));
const bucket = process.env.PICS_BUCKET ?? '';
if (!/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(bucket)) {
  console.error('error: PICS_BUCKET must name the pics bucket');
  process.exit(2);
}
const cache = process.env.PICS_CACHE || join(here, '.cache');
const local = Boolean(process.env.AWS_ENDPOINT_URL);
const s3 = new S3Client({ forcePathStyle: local, region: process.env.AWS_REGION || 'us-east-1' });
// Wikimedia asks every client to say who it is.
const USER_AGENT = 'grigri-pics/1.0 (https://grigri.nu01.com)';
const ANNOTATION = 'grigri';
const PREFIX = 'pics/crags/';

const dataset = JSON.parse(await readFile(join(here, 'crags.json'), 'utf8'));

/** A crag id as a key segment: "osm:n123" → "osm-n123". */
const slug = (id) => id.replace(/[^A-Za-z0-9_-]+/g, '-');
/**
 * What a photo is, for its key: its file (a guide's photos share a page as
 * their source), else its source.
 */
const idOf = (photo) => photo.file ?? photo.source;
/** A photo's key under pics/: stable for its source, so it's never re-uploaded. */
const keyOf = (crag, photo, ext) =>
  `crags/${slug(crag.id)}/${createHash('sha1').update(idOf(photo)).digest('hex').slice(0, 12)}.${ext}`;
const extOf = (photo) => (/\.png($|\?)/i.test(photo.url ?? photo.file) ? 'png' : 'jpg');

async function listKeys() {
  const keys = [];
  let token;
  do {
    const page = await s3.send(new ListObjectsV2Command({ Bucket: bucket, Prefix: PREFIX, ContinuationToken: token }));
    for (const o of page.Contents ?? []) keys.push(o.Key);
    token = page.IsTruncated ? page.NextContinuationToken : undefined;
  } while (token);
  return keys;
}

/**
 * The photo's bytes: its file in pics/ (a guide's photos), else from the
 * cache or downloaded (politely: one at a time, retried on 429).
 */
async function fetchPhoto(photo, file) {
  if (photo.file) return readFile(join(here, photo.file));
  try {
    return await readFile(file);
  } catch {}
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(photo.url, { headers: { 'User-Agent': USER_AGENT } });
    if (res.ok) {
      const bytes = Buffer.from(await res.arrayBuffer());
      await mkdir(dirname(file), { recursive: true });
      await writeFile(file, bytes);
      return bytes;
    }
    if ((res.status === 429 || res.status >= 500) && attempt < 5) {
      await new Promise((r) => setTimeout(r, 2000 * attempt));
      continue;
    }
    throw new Error(`${photo.url}: HTTP ${res.status}`);
  }
}

const existing = new Set(await listKeys());
const wanted = new Set();
let uploaded = 0;
let failed = 0;
for (const crag of dataset.crags) {
  for (const photo of crag.photos) {
    const ext = extOf(photo);
    const key = keyOf(crag, photo, ext);
    const object = `pics/${key}`;
    wanted.add(object);
    const annotation = JSON.stringify({
      crag: { id: crag.id, name: crag.name, area: crag.area, lat: crag.lat, lon: crag.lon },
      key,
      width: photo.width,
      height: photo.height,
      caption: photo.caption,
      author: photo.author,
      license: photo.license,
      licenseUrl: photo.licenseUrl,
      source: photo.source,
    });
    try {
      if (!existing.has(object)) {
        const bytes = await fetchPhoto(photo, join(cache, key));
        await s3.send(new PutObjectCommand({
          Bucket: bucket,
          Key: object,
          Body: bytes,
          ContentType: ext === 'png' ? 'image/png' : 'image/jpeg',
          // Keys follow the source, so a photo never changes under one.
          CacheControl: 'public, max-age=31536000, immutable',
        }));
        uploaded++;
      }
      // The metadata, replaced when crags.json changed it.
      const current = await getAnnotation(object);
      if (current !== annotation) {
        await s3.send(new PutObjectAnnotationCommand({
          Bucket: bucket,
          Key: object,
          AnnotationName: ANNOTATION,
          AnnotationPayload: Buffer.from(annotation),
        }));
      }
    } catch (e) {
      // One photo failing (the source moved, a network blip) skips it.
      failed++;
      wanted.delete(object);
      console.error(`warning: ${crag.name}: ${photo.source}: ${e.message ?? e}`);
    }
  }
}

// Photos taken out of crags.json go (a failed one stays, as it was).
let deleted = 0;
for (const object of existing) {
  if (wanted.has(object)) continue;
  if (dataset.crags.some((c) => c.photos.some((p) => `pics/${keyOf(c, p, extOf(p))}` === object))) continue;
  await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: object }));
  deleted++;
}

// The catalog, from the annotations (what's in the bucket, not the file).
const crags = new Map();
for (const object of await listKeys()) {
  const raw = await getAnnotation(object);
  if (!raw) continue;
  const a = JSON.parse(raw);
  if (!crags.has(a.crag.id)) crags.set(a.crag.id, { ...a.crag, photos: [] });
  const { crag: _crag, ...photo } = a;
  crags.get(a.crag.id).photos.push(photo);
}
// crags.json's order: areas first, then each crag's photos as listed.
const order = new Map(dataset.crags.map((c, i) => [c.id, i]));
const places = new Map(dataset.crags.flatMap((c) => c.photos.map((p, i) => [keyOf(c, p, extOf(p)), i])));
const catalog = {
  generatedAt: new Date().toISOString(),
  crags: [...crags.values()]
    .sort((a, b) => (order.get(a.id) ?? 1e9) - (order.get(b.id) ?? 1e9))
    .map((c) => ({ ...c, photos: c.photos.sort((a, b) => (places.get(a.key) ?? 0) - (places.get(b.key) ?? 0)) })),
};
await s3.send(new PutObjectCommand({
  Bucket: bucket,
  Key: 'pics/catalog.json',
  Body: JSON.stringify(catalog),
  ContentType: 'application/json',
  // The index page reads it through CloudFront too; deploys invalidate it.
  CacheControl: 'public, max-age=3600',
}));
const photos = catalog.crags.reduce((n, c) => n + c.photos.length, 0);
console.log(`pics: ${catalog.crags.length} crags, ${photos} photos in ${bucket} (${uploaded} uploaded, ${deleted} deleted, ${failed} failed)`);

async function getAnnotation(object) {
  try {
    const out = await s3.send(new GetObjectAnnotationCommand({ Bucket: bucket, Key: object, AnnotationName: ANNOTATION }));
    return await out.AnnotationPayload.transformToString();
  } catch (e) {
    if (e.name === 'NoSuchAnnotation' || e.$metadata?.httpStatusCode === 404) return undefined;
    throw e;
  }
}
