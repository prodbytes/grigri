// Ads (specs/ads.md): Premium climbers' ads, shown between plans on the
// Discover deck once an admin approves them. An ad is a link, with text
// over a photo or video (or text alone). Accepting it on the deck opens
// the link in the browser.
import { badRequest } from './errors.js';
import { asObject } from './validate.js';

export type AdStatus = 'pending' | 'approved' | 'rejected';
export const AD_STATUSES: readonly AdStatus[] = ['pending', 'approved', 'rejected'];

export interface AdMedia {
  kind: 'image' | 'video';
  /** photos/<key> in the photos bucket: `ads/<ownerId>/<id>.<ext>`. */
  key: string;
}

export interface Ad {
  id: string;
  ownerId: string;
  /** Shown over the photo or video (or alone); may be empty with media. */
  text: string;
  /** Where accepting the ad takes people: an http(s) URL. */
  link: string;
  media?: AdMedia;
  status: AdStatus;
  createdAt: string;
  /** When an admin last approved or rejected it. */
  reviewedAt?: string;
}

export const MAX_AD_TEXT = 200;
export const MAX_AD_LINK = 500;
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
export function adInput(body: unknown, ownerId: string): Pick<Ad, 'text' | 'link' | 'media'> {
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
  return { text, link, ...(media ? { media } : {}) };
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
 * not mine, not one I skipped; newest approved first, at most DECK_ADS.
 */
export function deckAds(
  approved: Ad[],
  meId: string,
  ownerOk: (ownerId: string) => boolean,
  skipped: ReadonlySet<string> = new Set(),
): Ad[] {
  return approved
    .filter((a) => a.status === 'approved' && a.ownerId !== meId && !skipped.has(a.id) && ownerOk(a.ownerId))
    .sort((a, b) => (b.reviewedAt ?? b.createdAt).localeCompare(a.reviewedAt ?? a.createdAt))
    .slice(0, DECK_ADS);
}

function escape(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
