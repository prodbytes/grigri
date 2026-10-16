// The route finder's data (specs/route-finder.md): walls, each a rock face
// known by its reference photos ("views"), and the routes climbers drew on
// it, bolt by bolt. The app recognizes a wall in its camera on the device
// (by matching the views), then draws the routes; the server only keeps
// and serves them.
import { badRequest } from './errors.js';
import { type Scale, SCALES } from './model.js';
import { haversineKm } from './rules.js';
import { asObject, round } from './validate.js';

/** Most routes one wall keeps. */
export const MAX_ROUTES = 80;
/** Most bolts (and anchor) one route has. */
export const MAX_BOLTS = 40;
/** Most views a wall keeps: its first, and the latest learned ones. */
export const MAX_VIEWS = 12;
/** Walls this close to a point are "here". */
export const NEAR_KM = 3;
/** Most walls one lookup gives. */
export const MAX_NEAR = 20;

/**
 * A reference photo of a wall: where it is (served at /photos/<key>), its
 * size, and the 3×3 transform (row-major) from its pixels to the first
 * view's, so routes drawn on the first view show on it. The first view's
 * is the identity.
 */
export interface WallView {
  key: string;
  width: number;
  height: number;
  h: number[];
  addedBy: string;
  time: string;
}

/** A route on a wall: its bolts, in order from the ground, in the first view (0..1 of its width and height). */
export interface Route {
  id: string;
  name: string;
  grade: { scale: Scale; grade: number };
  bolts: [number, number][];
  addedBy: string;
  time: string;
}

export interface Wall {
  id: string;
  name: string;
  /** The crag it's at (GriGri Pics' or the sector index's id), when known. */
  cragId?: string;
  lat: number;
  lon: number;
  views: WallView[];
  routes: Route[];
  createdBy: string;
  createdAt: string;
}

export interface ViewInput {
  key: string;
  width: number;
  height: number;
}

const WALL_KEY = /^walls\/([A-Za-z0-9_-]{8,64})\/[A-Za-z0-9_-]{8,64}\.(jpg|png|webp)$/;

/** A wall photo's key (as POST /api/walls/photo issued it): `walls/<owner>/<name>.<ext>`, one of [owners]'. */
export function wallPhotoKey(value: unknown, owners: string[]): string {
  const m = typeof value === 'string' ? WALL_KEY.exec(value) : null;
  if (!m) throw badRequest("key isn't one from /api/walls/photo");
  if (!owners.includes(m[1]!)) throw badRequest("key isn't yours");
  return value as string;
}

function name(value: unknown, field: string): string {
  if (typeof value !== 'string') throw badRequest(`${field} is required`);
  const s = value.trim().replace(/\s+/g, ' ');
  if (s.length < 1 || s.length > 60) throw badRequest(`${field} must be 1–60 characters`);
  if (/[\u0000-\u001f\u007f]/.test(s)) throw badRequest(`${field} has control characters`);
  return s;
}

function size(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 64 || value > 8192) {
    throw badRequest(`${field} must be a whole number of pixels, 64–8192`);
  }
  return value;
}

export function viewInput(value: unknown, owners: string[]): ViewInput {
  const o = asObject(value, 'view');
  return { key: wallPhotoKey(o.key, owners), width: size(o.width, 'width'), height: size(o.height, 'height') };
}

/** A learned view's transform to the first view: 9 finite numbers, scaled so the last is 1. */
export function homography(value: unknown): number[] {
  if (!Array.isArray(value) || value.length !== 9 || !value.every((v) => typeof v === 'number' && Number.isFinite(v))) {
    throw badRequest('h must be 9 numbers (a 3×3 transform, row by row)');
  }
  const last = value[8] as number;
  if (Math.abs(last) < 1e-9) throw badRequest("h's last entry can't be 0");
  return value.map((v) => Number(((v as number) / last).toPrecision(10)));
}

export function wallInput(body: unknown, owners: string[]): { name: string; cragId?: string; lat: number; lon: number; view: ViewInput } {
  const o = asObject(body);
  const lat = o.lat, lon = o.lon;
  if (typeof lat !== 'number' || typeof lon !== 'number' || Math.abs(lat) > 90 || Math.abs(lon) > 180) {
    throw badRequest('lat and lon are required');
  }
  let cragId: string | undefined;
  if (o.cragId !== undefined && o.cragId !== null && o.cragId !== '') {
    if (typeof o.cragId !== 'string' || !/^[A-Za-z0-9:_-]{1,64}$/.test(o.cragId)) throw badRequest("cragId isn't valid");
    cragId = o.cragId;
  }
  return {
    name: name(o.name, 'name'),
    ...(cragId ? { cragId } : {}),
    // Walls are public: ~10 m is plenty to find them.
    lat: round(lat, 4),
    lon: round(lon, 4),
    view: viewInput(o.view, owners),
  };
}

export function routeInput(body: unknown): Pick<Route, 'name' | 'grade' | 'bolts'> {
  const o = asObject(body);
  const g = asObject(o.grade, 'grade');
  const scale = g.scale;
  if (typeof scale !== 'string' || !Object.hasOwn(SCALES, scale)) throw badRequest('grade.scale must be routes or boulders');
  const max = SCALES[scale as Scale].length;
  if (typeof g.grade !== 'number' || !Number.isInteger(g.grade) || g.grade < 0 || g.grade >= max) {
    throw badRequest(`grade.grade must be 0–${max - 1}`);
  }
  if (!Array.isArray(o.bolts) || o.bolts.length < 2 || o.bolts.length > MAX_BOLTS) {
    throw badRequest(`bolts: 2–${MAX_BOLTS} points, from the ground up`);
  }
  const bolts = o.bolts.map((p): [number, number] => {
    if (!Array.isArray(p) || p.length !== 2 || !p.every((v) => typeof v === 'number' && v >= 0 && v <= 1)) {
      throw badRequest('each bolt is [x, y], 0–1 of the photo');
    }
    return [round(p[0] as number, 4), round(p[1] as number, 4)];
  });
  return { name: name(o.name, 'name'), grade: { scale: scale as Scale, grade: g.grade }, bolts };
}

export const IDENTITY = [1, 0, 0, 0, 1, 0, 0, 0, 1];

/**
 * A learned view joins the wall; past MAX_VIEWS the oldest learned one
 * goes (never the first, which routes are drawn on). → the wall, and the
 * view that went, if any.
 */
export function addView(wall: Wall, view: WallView): { wall: Wall; dropped?: WallView } {
  const views = [...wall.views, view];
  if (views.length <= MAX_VIEWS) return { wall: { ...wall, views } };
  const [dropped] = views.splice(1, 1);
  return { wall: { ...wall, views }, dropped };
}

/** The walls near a point, nearest first. */
export function wallsNear(walls: Wall[], point: { lat: number; lon: number }): Wall[] {
  return walls
    .map((w) => ({ w, km: haversineKm(point, w) }))
    .filter((x) => x.km <= NEAR_KM)
    .sort((a, b) => a.km - b.km)
    .slice(0, MAX_NEAR)
    .map((x) => x.w);
}
