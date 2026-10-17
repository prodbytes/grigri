// The place search behind an ad's regions (specs/ads.md): OpenStreetMap's
// Nominatim (free; its usage policy asks for an identifying User-Agent, at
// most a search a second, and no search-as-you-type, so the app searches
// only when asked). Through the API, so climbers' addresses never reach a
// third party and the site's content policy stays as it is.
import type { AdRegion } from './domain/ads.js';

const SEARCH = 'https://nominatim.openstreetmap.org/search';
const USER_AGENT = 'Grigri/1.0 (https://grigri.nu01.com)';
/** Results one search answers at most. */
export const MAX_PLACES = 8;
export const MAX_PLACE_QUERY = 100;

/** A place found: an ad region (its short name and box) and its full name to tell it apart. */
export interface Place extends AdRegion {
  /** "Siurana, Cornudella de Montsant, Priorat, Tarragona, Catalunya, 43360, España". */
  label: string;
}

/** Finds places by name, in that language where it can; [] when none. */
export type PlaceSearch = (query: string, language: string) => Promise<Place[]>;

interface NominatimResult {
  name?: string;
  display_name?: string;
  addresstype?: string;
  boundingbox?: string[];
  address?: { country?: string };
}

export const nominatim =
  (fetcher: typeof fetch = fetch): PlaceSearch =>
  async (query, language) => {
    const url = new URL(SEARCH);
    url.search = new URLSearchParams({ q: query, format: 'jsonv2', addressdetails: '1', limit: String(MAX_PLACES) }).toString();
    const res = await fetcher(url, {
      headers: { 'user-agent': USER_AGENT, 'accept-language': language || 'en' },
      signal: AbortSignal.timeout(5_000),
    });
    if (!res.ok) throw new Error(`place search: ${res.status}`);
    const found = (await res.json()) as NominatimResult[];
    return (Array.isArray(found) ? found : []).flatMap((r) => {
      const [south, north, west, east] = (r.boundingbox ?? []).map(Number);
      const name = (r.name || r.display_name || '').trim();
      if (!name || ![south, north, west, east].every((n) => Number.isFinite(n))) return [];
      // "Siurana, España"; a country by its name alone.
      const country = r.address?.country;
      const short = r.addresstype === 'country' || !country || country === name ? name : `${name}, ${country}`;
      return [{ name: short.slice(0, 120), label: (r.display_name ?? short).slice(0, 300), south: south!, west: west!, north: north!, east: east! }];
    });
  };
