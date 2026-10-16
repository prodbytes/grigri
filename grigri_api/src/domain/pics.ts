// GriGri Pics: which of Grigri's own crag photos go with a place
// (specs/pics.md). Pure functions over the catalog.
import type { GrigriPic, PicCatalog, PicCrag } from './model.js';
import { haversineKm } from './rules.js';

/** A crag this close to the place is the place (sector points are approximate). */
export const SAME_CRAG_KM = 1;
/** An area's photos go with places this close to its center. */
export const AREA_KM = 8;
/** The most photos one lookup gives. */
export const MAX_PICS = 12;

/** Where to find photos for: a plan's sector, point and name, or a point alone. */
export interface Where {
  sectorId?: string;
  lat?: number;
  lon?: number;
  place?: string;
  area?: string;
}

/** A photo with the crag it shows. */
export interface PicWithCrag extends GrigriPic {
  cragId: string;
  crag: string;
}

/**
 * The photos for a place, best first: its own crag's (by sector id, then
 * the crags within SAME_CRAG_KM, nearest first, then a crag of the same
 * name), then its climbing area's (within AREA_KM, or named in the plan's
 * place or area). At most MAX_PICS.
 */
export function picsFor(catalog: PicCatalog, where: Where): PicWithCrag[] {
  const crags = catalog.crags.filter((c) => !isArea(c));
  const areas = catalog.crags.filter(isArea);
  const point = typeof where.lat === 'number' && typeof where.lon === 'number' ? { lat: where.lat, lon: where.lon } : undefined;
  const picked: PicCrag[] = [];
  const add = (c: PicCrag | undefined) => {
    if (c && !picked.includes(c)) picked.push(c);
  };

  if (where.sectorId) add(crags.find((c) => c.id === where.sectorId));
  if (point) {
    crags
      .map((c) => ({ c, km: haversineKm(point, c) }))
      .filter((x) => x.km <= SAME_CRAG_KM)
      .sort((a, b) => a.km - b.km)
      .forEach((x) => add(x.c));
  }
  const place = fold(where.place ?? '');
  if (place) crags.filter((c) => fold(c.name) === place).forEach(add);

  const words = ` ${fold(`${where.place ?? ''} ${where.area ?? ''}`)} `;
  for (const a of areas) {
    const near = point !== undefined && haversineKm(point, a) <= AREA_KM;
    const named = words.includes(` ${fold(a.name)} `);
    if (near || named) add(a);
  }

  return picked
    .flatMap((c) => c.photos.map((p) => ({ ...p, cragId: c.id, crag: c.name })))
    .slice(0, MAX_PICS);
}

function isArea(c: PicCrag): boolean {
  return c.id.startsWith('area:');
}

/** Lowercase, without accents or punctuation, single-spaced: "L'Olla" → "l olla". */
export function fold(s: string): string {
  return s
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim();
}
