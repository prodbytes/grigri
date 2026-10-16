import { describe, expect, it } from 'vitest';
import { MAX_PICS, fold, picsFor } from '../src/domain/pics.js';
import type { PicCatalog, PicCrag } from '../src/domain/model.js';

const photo = (n: number) => ({
  key: `crags/x/${n}.jpg`,
  width: 1600,
  height: 1200,
  caption: `photo ${n}`,
  author: 'A. Example',
  license: 'CC BY 4.0',
  licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
  source: 'https://commons.wikimedia.org/wiki/File:Example.jpg',
});
const crag = (id: string, name: string, lat: number, lon: number, photos = 1): PicCrag => ({
  id,
  name,
  area: 'Margalef',
  lat,
  lon,
  photos: Array.from({ length: photos }, (_, i) => photo(i)),
});

describe('GriGri Pics for a place', () => {
  it('folds names: case, accents and punctuation', () => {
    expect(fold("Can Piqué")).toBe('can pique');
    expect(fold("  L'Olla ")).toBe('l olla');
  });

  it('matches a crag typed by hand, ignoring accents', () => {
    const catalog: PicCatalog = { generatedAt: '', crags: [crag('osm:n1', 'Can Piqué', 41.2585, 0.9335)] };
    expect(picsFor(catalog, { place: 'can pique' }).map((p) => p.cragId)).toEqual(['osm:n1']);
    expect(picsFor(catalog, { place: 'Can' })).toEqual([]);
  });

  it('an area by distance or by its name in the plan, never by a word inside another', () => {
    const catalog: PicCatalog = { generatedAt: '', crags: [crag('area:margalef', 'Margalef', 41.2853, 0.7536)] };
    expect(picsFor(catalog, { lat: 41.30, lon: 0.76 })).toHaveLength(1);
    expect(picsFor(catalog, { lat: 41.5, lon: 1.2 })).toEqual([]);
    expect(picsFor(catalog, { place: 'Raco', area: 'Margalef, Spain' })).toHaveLength(1);
    expect(picsFor(catalog, { place: 'Margalefish' })).toEqual([]);
  });

  it(`gives at most ${MAX_PICS}`, () => {
    const catalog: PicCatalog = {
      generatedAt: '',
      crags: [crag('osm:n1', 'A', 41.28, 0.75, 8), crag('osm:n2', 'B', 41.2801, 0.7501, 8)],
    };
    expect(picsFor(catalog, { lat: 41.28, lon: 0.75 })).toHaveLength(MAX_PICS);
  });
});
