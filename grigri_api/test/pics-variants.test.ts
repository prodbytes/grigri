import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import {
  VARIANT_WIDTHS,
  isVariantKey,
  makeVariants,
  originalOf,
  recordedVariants,
  variantKey,
} from '../pics/variants.mjs';

/** A photo-like JPEG (noise compresses as badly as a real photo does). */
async function jpeg(width: number, height: number, orientation?: number): Promise<Buffer> {
  const noise = Buffer.alloc(width * height * 3);
  for (let i = 0; i < noise.length; i++) noise[i] = (i * 2654435761) >>> 24;
  let image = sharp(noise, { raw: { width, height, channels: 3 } }).jpeg({ quality: 90 });
  if (orientation) image = image.withMetadata({ orientation });
  return image.toBuffer();
}

describe('GriGri Pics: smaller copies', () => {
  it('names copies next to their photo, and knows them apart', () => {
    expect(variantKey('crags/osm-n1/0123456789ab.jpg', 640)).toBe('crags/osm-n1/0123456789ab-w640.jpg');
    expect(isVariantKey('pics/crags/osm-n1/0123456789ab-w640.jpg')).toBe(true);
    expect(isVariantKey('pics/crags/osm-n1/0123456789ab.jpg')).toBe(false);
    // A crag's slug may hold "-w1": only the file name counts.
    expect(isVariantKey('pics/crags/osm-w123/0123456789ab.jpg')).toBe(false);
    expect(originalOf('pics/crags/osm-n1/0123456789ab-w1080.png')).toBe('pics/crags/osm-n1/0123456789ab.png');
  });

  it('makes one copy per width the photo is wider than, narrowest first', async () => {
    const photo = await jpeg(1920, 1280);
    const copies = await makeVariants(photo, 'jpg');
    expect(copies.map((c) => [c.width, c.height])).toEqual([[640, 427], [1080, 720], [1440, 960]]);
    for (const c of copies) {
      expect(c.bytes.length).toBeLessThan(photo.length);
      const meta = await sharp(c.bytes).metadata();
      expect([meta.format, meta.width, meta.height]).toEqual(['jpeg', c.width, c.height]);
    }
  });

  it('makes none for a photo no wider than the smallest width', async () => {
    expect(await makeVariants(await jpeg(640, 480), 'jpg')).toEqual([]);
    expect(await makeVariants(await jpeg(300, 500), 'jpg')).toEqual([]);
  });

  it('turns photos upright, by their EXIF orientation', async () => {
    // Stored 1500 x 1000, shown turned a quarter: 1000 wide.
    const copies = await makeVariants(await jpeg(1500, 1000, 6), 'jpg');
    expect(copies.map((c) => [c.width, c.height])).toEqual([[640, 960]]);
  });

  it('keeps PNGs PNGs', async () => {
    const png = await sharp(await jpeg(800, 600)).png({ compressionLevel: 0 }).toBuffer();
    const copies = await makeVariants(png, 'png');
    expect(copies).toHaveLength(1);
    expect((await sharp(copies[0]!.bytes).metadata()).format).toBe('png');
  });

  it('reuses recorded copies only while they are all in the bucket', () => {
    const variants = [{ key: 'crags/x/a-w640.jpg', width: 640, height: 427 }];
    const annotation = JSON.stringify({ key: 'crags/x/a.jpg', variants });
    expect(recordedVariants(annotation, new Set(['pics/crags/x/a.jpg', 'pics/crags/x/a-w640.jpg']))).toEqual(variants);
    expect(recordedVariants(annotation, new Set(['pics/crags/x/a.jpg']))).toBeUndefined();
    // A small photo's: none to make, recorded as such.
    expect(recordedVariants(JSON.stringify({ variants: [] }), new Set())).toEqual([]);
    // Not made yet (an annotation from before copies), or no annotation.
    expect(recordedVariants(JSON.stringify({ key: 'crags/x/a.jpg' }), new Set())).toBeUndefined();
    expect(recordedVariants(undefined, new Set())).toBeUndefined();
    expect(recordedVariants('not json', new Set())).toBeUndefined();
  });

  it('makes the widths the screens need', () => {
    expect(VARIANT_WIDTHS).toEqual([640, 1080, 1440]);
  });
});
