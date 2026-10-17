// Ads (specs/ads.md): Premium climbers' ads, shown between plans on the
// Discover deck once an admin approves them. An ad is a link, with text
// over a photo or video (or text alone). Accepting it on the deck opens
// the link in the browser. An ad can be limited to regions (a country, a
// town...): it shows to climbers whose location or areas fall in one, give
// or take a margin.
import { badRequest } from './errors.js';
import { asObject } from './validate.js';

export type AdStatus = 'pending' | 'approved' | 'rejected';
export const AD_STATUSES: readonly AdStatus[] = ['pending', 'approved', 'rejected'];

export interface AdMedia {
  kind: 'image' | 'video';
  /** photos/<key> in the photos bucket: `ads/<ownerId>/<id>.<ext>`. */
  key: string;
}

/**
 * Where an ad shows: a place's name and its bounding box (from the place
 * search, GET /api/places), in degrees. `west` > `east` when it crosses
 * the antimeridian.
 */
export interface AdRegion {
  name: string;
  south: number;
  west: number;
  north: number;
  east: number;
}

export interface Ad {
  id: string;
  ownerId: string;
  /** Shown over the photo or video (or alone); may be empty with media. */
  text: string;
  /** Where accepting the ad takes people: an http(s) URL. */
  link: string;
  media?: AdMedia;
  /** Where it shows; none (or empty): everywhere. */
  regions?: AdRegion[];
  status: AdStatus;
  createdAt: string;
  /** When an admin last approved or rejected it. */
  reviewedAt?: string;
}

export const MAX_AD_TEXT = 200;
export const MAX_AD_LINK = 500;
/** Regions one ad shows in at most. */
export const MAX_AD_REGIONS = 10;
export const MAX_REGION_NAME = 120;
/** How far past its box a region reaches: at least this far... */
export const REGION_MARGIN_KM = 50;
/** ...or this share of the box's size, when that's further. */
export const REGION_MARGIN_SHARE = 0.1;
/** Ads one climber keeps at a time (every status). */
export const MAX_ADS_PER_OWNER = 20;
/** Approved ads one deck carries at most. */
export const DECK_ADS = 20;

/** How often the deck shows an ad: one after every `every` plans; 0: never. */
export interface AdSettings {
  every: number;
}
export const DEFAULT_AD_SETTINGS: AdSettings = { every: 10 };
export const MAX_AD_EVERY = 50;

const MEDIA_EXT: Record<string, AdMedia['kind']> = {
  jpg: 'image', png: 'image', webp: 'image', mp4: 'video', mov: 'video',
};

/** A new ad's text, link and media, checked (the media key must be one issued to me). */
export function adInput(body: unknown, ownerId: string): Pick<Ad, 'text' | 'link' | 'media' | 'regions'> {
  const o = asObject(body);
  const text = typeof o.text === 'string' ? o.text.trim() : '';
  if (text.length > MAX_AD_TEXT) throw badRequest(`text is at most ${MAX_AD_TEXT} characters`);
  const link = adLink(o.link);
  let media: AdMedia | undefined;
  if (o.media !== undefined && o.media !== null) {
    const m = asObject(o.media, 'media');
    const key = typeof m.key === 'string' ? m.key : '';
    const match = new RegExp(`^ads/${escape(ownerId)}/[A-Za-z0-9_-]{16}\\.(jpg|png|webp|mp4|mov)$`).exec(key);
    if (!match) throw badRequest('media.key must be an upload from POST /api/ads/media');
    media = { kind: MEDIA_EXT[match[1]!]!, key };
  }
  if (!text && !media) throw badRequest('an ad needs text, a photo or a video');
  const regions = adRegions(o.regions);
  return { text, link, ...(media ? { media } : {}), ...(regions.length ? { regions } : {}) };
}

/** An ad's regions: at most MAX_AD_REGIONS boxes with a name; none: everywhere. */
export function adRegions(value: unknown): AdRegion[] {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw badRequest('regions must be a list');
  if (value.length > MAX_AD_REGIONS) throw badRequest(`an ad shows in at most ${MAX_AD_REGIONS} regions`);
  return value.map((v) => {
    const r = asObject(v, 'region');
    const name = typeof r.name === 'string' ? r.name.trim() : '';
    if (!name || name.length > MAX_REGION_NAME) throw badRequest(`a region needs a name of at most ${MAX_REGION_NAME} characters`);
    const deg = (k: string, max: number) => {
      const n = r[k];
      if (typeof n !== 'number' || !Number.isFinite(n) || Math.abs(n) > max) throw badRequest(`region ${k} must be a number from -${max} to ${max}`);
      return n;
    };
    const region = { name, south: deg('south', 90), west: deg('west', 180), north: deg('north', 90), east: deg('east', 180) };
    if (region.south > region.north) throw badRequest('a region\'s south must not be north of its north');
    return region;
  });
}

const KM_PER_DEGREE = 111.32;

/**
 * Whether a point is in a region, or near it: its box widened on every
 * side by REGION_MARGIN_KM or a tenth of its size, whichever is more
 * (so a town reaches the crags and towns around it, and a country a bit
 * over its borders).
 */
export function regionCovers(r: AdRegion, p: { lat: number; lon: number }): boolean {
  const spanLat = r.north - r.south;
  const marginLat = Math.max(REGION_MARGIN_KM / KM_PER_DEGREE, spanLat * REGION_MARGIN_SHARE);
  if (p.lat < r.south - marginLat || p.lat > r.north + marginLat) return false;
  // A degree of longitude shrinks away from the equator: measured at the
  // box's edge nearest a pole (the widest margin in degrees), never under
  // a sliver so the poles don't divide by zero.
  const edge = Math.min(89, Math.max(Math.abs(r.south), Math.abs(r.north)));
  const spanLon = r.west <= r.east ? r.east - r.west : r.east + 360 - r.west;
  const marginLon = Math.max(REGION_MARGIN_KM / (KM_PER_DEGREE * Math.cos((edge * Math.PI) / 180)), spanLon * REGION_MARGIN_SHARE);
  if (spanLon + 2 * marginLon >= 360) return true;
  // How far east of the box's west edge the point is, in [0, 360).
  const east = (((p.lon - (r.west - marginLon)) % 360) + 360) % 360;
  return east <= spanLon + 2 * marginLon;
}

/** Whether an ad shows to someone at any of these points: everywhere when it has no regions, never with no points. */
export function adReaches(ad: Pick<Ad, 'regions'>, points: { lat: number; lon: number }[]): boolean {
  if (!ad.regions?.length) return true;
  return points.some((p) => ad.regions!.some((r) => regionCovers(r, p)));
}

/** An ad's link: an absolute http(s) URL with a host, no credentials. */
export function adLink(value: unknown): string {
  const raw = typeof value === 'string' ? value.trim() : '';
  if (!raw) throw badRequest('link is required');
  if (raw.length > MAX_AD_LINK) throw badRequest(`link is at most ${MAX_AD_LINK} characters`);
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw badRequest('link must be a web address (https://…)');
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') throw badRequest('link must start with https:// or http://');
  if (!url.hostname.includes('.') || url.username || url.password) throw badRequest('link must be a web address (https://…)');
  return url.toString();
}

export function adSettingsInput(body: unknown): AdSettings {
  const every = asObject(body).every;
  if (typeof every !== 'number' || !Number.isInteger(every) || every < 0 || every > MAX_AD_EVERY) {
    throw badRequest(`every must be a whole number from 0 (no ads) to ${MAX_AD_EVERY}`);
  }
  return { every };
}

/**
 * The ads a deck shows: approved, their owner Premium and not blocked,
 * not mine, not one I skipped, reaching where I am or climb (my location
 * and areas); newest approved first, at most DECK_ADS.
 */
export function deckAds(
  approved: Ad[],
  meId: string,
  ownerOk: (ownerId: string) => boolean,
  skipped: ReadonlySet<string> = new Set(),
  points: { lat: number; lon: number }[] = [],
): Ad[] {
  return approved
    .filter((a) => a.status === 'approved' && a.ownerId !== meId && !skipped.has(a.id) && ownerOk(a.ownerId) && adReaches(a, points))
    .sort((a, b) => (b.reviewedAt ?? b.createdAt).localeCompare(a.reviewedAt ?? a.createdAt))
    .slice(0, DECK_ADS);
}

function escape(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
