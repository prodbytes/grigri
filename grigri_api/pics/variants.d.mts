// Types for variants.mjs (the loader is plain JavaScript, run by node).

/** A smaller copy of a photo, as the catalog records it. */
export interface PicVariant {
  key: string;
  width: number;
  height: number;
}

export const VARIANT_WIDTHS: number[];
export function variantKey(key: string, width: number): string;
export function isVariantKey(key: string): boolean;
export function originalOf(key: string): string;
export function recordedVariants(annotation: string | undefined, objects: Set<string>): PicVariant[] | undefined;
export function makeVariants(
  bytes: Buffer,
  ext: string,
  widths?: number[],
): Promise<{ width: number; height: number; bytes: Buffer }[]>;
