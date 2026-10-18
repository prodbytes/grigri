// GriGri Pics' smaller copies (specs/pics.md, Sizes): each photo wider
// than a size gets a copy that wide, next to it, so screens that show it
// small download less. Used by load.mjs; the app and the landing page pick
// the smallest copy that covers what they show, else the photo itself.
import sharp from 'sharp';

/**
 * The widths made, in pixels. 640 covers the plan screen's thumbnails
 * (170 x 120, up to 3.5 device pixels per point) and the landing page's
 * cards at 1x; 1080 and 1440 the larger cards (the deck's, the landing
 * page's) at 2x or 3x, depending on the photo's shape.
 */
export const VARIANT_WIDTHS = [640, 1080, 1440];

/** A copy's key: `crags/x/<hash>.jpg` → `crags/x/<hash>-w640.jpg`. */
export const variantKey = (key, width) => key.replace(/(\.[A-Za-z0-9]+)$/, `-w${width}$1`);

/** Whether an object or key is a copy (photos' own keys are `<hash>.<ext>`). */
export const isVariantKey = (key) => /-w\d+\.[A-Za-z0-9]+$/.test(key);

/** The photo a copy was made from: `…/<hash>-w640.jpg` → `…/<hash>.jpg`. */
export const originalOf = (key) => key.replace(/-w\d+(\.[A-Za-z0-9]+)$/, '$1');

/**
 * The copies an annotation already records, when they're all in the
 * bucket (`objects`: its keys, `pics/…`): reused, so a second run makes
 * nothing. Undefined when there are none yet, or one is missing.
 */
export function recordedVariants(annotation, objects) {
  if (!annotation) return undefined;
  let variants;
  try {
    variants = JSON.parse(annotation).variants;
  } catch {
    return undefined;
  }
  if (!Array.isArray(variants)) return undefined;
  const ok = variants.every(
    (v) => v && typeof v.key === 'string' && Number.isInteger(v.width) && Number.isInteger(v.height) && objects.has(`pics/${v.key}`),
  );
  return ok ? variants : undefined;
}

/**
 * The copies of a photo (its stored bytes, `jpg` or `png`), narrowest
 * first: one for each of `widths` it's wider than, upright (EXIF
 * orientation applied) and in sRGB, as browsers show the photo itself.
 * A copy no smaller in bytes than the photo isn't worth it, so it's left
 * out. Each is `{ width, height, bytes }`.
 */
export async function makeVariants(bytes, ext, widths = VARIANT_WIDTHS) {
  const meta = await sharp(bytes).metadata();
  // Orientations 5 to 8 turn the photo a quarter: its width is its height.
  const width = (meta.orientation ?? 1) >= 5 ? meta.height : meta.width;
  const out = [];
  for (const w of [...widths].sort((a, b) => a - b)) {
    if (!width || w >= width) continue;
    let image = sharp(bytes).rotate().resize({ width: w, withoutEnlargement: true });
    image = ext === 'png' ? image.png({ compressionLevel: 9 }) : image.jpeg({ quality: 82, mozjpeg: true });
    const { data, info } = await image.toBuffer({ resolveWithObject: true });
    if (data.length >= bytes.length) continue;
    out.push({ width: info.width, height: info.height, bytes: data });
  }
  return out;
}
