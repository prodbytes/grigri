// Input validation: request bodies become typed values, or a 400 with what's
// wrong. Unknown fields are ignored (never stored).
import { badRequest } from './errors.js';
import {
  type Attachment,
  type Climber,
  type DayWindow,
  DISCIPLINES,
  type Discipline,
  GEAR,
  type Gear,
  type GradeRange,
  type Location,
  MAX_AREAS,
  type Plan,
  LEGACY_SCALES,
  SCALES,
  type Scale,
  scaleOf,
} from './model.js';

export const MAX_GEAR_PHOTOS = 6;

type Json = Record<string, unknown>;

export function asObject(body: unknown, what = 'body'): Json {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    throw badRequest(`${what} must be a JSON object`);
  }
  return body as Json;
}

/** Trims, and refuses control characters other than newlines and tabs. */
function text(value: unknown, field: string, { min = 0, max }: { min?: number; max: number }): string {
  if (value === undefined || value === null) value = '';
  if (typeof value !== 'string') throw badRequest(`${field} must be a string`);
  const trimmed = value.trim();
  // eslint-disable-next-line no-control-regex
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(trimmed)) {
    throw badRequest(`${field} has control characters`);
  }
  const length = [...trimmed].length;
  if (length < min) throw badRequest(min === 1 ? `${field} is required` : `${field} is too short`);
  if (length > max) throw badRequest(`${field} is longer than ${max} characters`);
  return trimmed;
}

function int(value: unknown, field: string, min: number, max: number): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < min || value > max) {
    throw badRequest(`${field} must be a whole number from ${min} to ${max}`);
  }
  return value;
}

export function gradeRange(value: unknown, field: string, scale: Scale): GradeRange {
  const o = asObject(value, field);
  // The old names (french, vScale) are read as the new ones.
  const given = typeof o.scale === 'string' ? (LEGACY_SCALES[o.scale] ?? o.scale) : o.scale;
  if (given !== scale) throw badRequest(`${field} must be on the ${scale} scale`);
  const top = SCALES[scale].length - 1;
  const min = int(o.min, `${field}.min`, 0, top);
  const max = int(o.max, `${field}.max`, 0, top);
  if (min > max) throw badRequest(`${field}.min is above its max`);
  return { scale, min, max };
}

function discipline(value: unknown, field = 'discipline'): Discipline {
  if (typeof value !== 'string' || !(DISCIPLINES as readonly string[]).includes(value)) {
    throw badRequest(`${field} must be one of ${DISCIPLINES.join(', ')}`);
  }
  return value as Discipline;
}

/**
 * A photo key (as issued by POST /api/photos): `<owner>/<kind>/<name>.<ext>`
 * where owner is one of `owners` (the caller's climber id or subject hash).
 */
export function photoKey(value: unknown, field: string, owners: string[]): string {
  if (typeof value !== 'string' || !PHOTO_KEY.test(value)) {
    throw badRequest(`${field} isn't a photo key from /api/photos`);
  }
  const owner = value.split('/')[0];
  if (!owner || !owners.includes(owner)) throw badRequest(`${field} isn't one of your photos`);
  return value;
}
const PHOTO_KEY = /^[A-Za-z0-9_-]{8,64}\/(profile|gear)\/[A-Za-z0-9_-]{8,64}\.(jpg|png|webp)$/;

function coordinate(value: unknown, field: string, limit: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < -limit || value > limit) {
    throw badRequest(`${field} must be a number from -${limit} to ${limit}`);
  }
  return value;
}

/** Rounds a coordinate to `places` decimals (2 is about 1 km). */
export function round(value: number, places: number): number {
  const f = 10 ** places;
  return Math.round(value * f) / f;
}

/** A named point. A climber's are rounded to ~1 km, so they never say exactly where someone lives. */
export function location(value: unknown, field: string): Location {
  const o = asObject(value, field);
  return {
    name: text(o.name, `${field}.name`, { min: 1, max: 120 }),
    lat: round(coordinate(o.lat, `${field}.lat`, 90), 2),
    lon: round(coordinate(o.lon, `${field}.lon`, 180), 2),
  };
}

/** A profile from PUT /api/me (a Climber without its id). */
export function profileInput(body: unknown, photoOwners: string[]): Omit<Climber, 'id'> {
  const o = asObject(body);
  const name = text(o.name, 'name', { min: 1, max: 60 });
  let age: number | undefined;
  if (o.age !== undefined && o.age !== null) age = int(o.age, 'age', 16, 99);
  const bio = text(o.bio, 'bio', { max: 1000 });
  let photo: string | undefined;
  if (o.photo !== undefined && o.photo !== null && o.photo !== '') photo = photoKey(o.photo, 'photo', photoOwners);

  const levels: Partial<Record<Discipline, GradeRange>> = {};
  if (o.levels !== undefined && o.levels !== null) {
    for (const [key, value] of Object.entries(asObject(o.levels, 'levels'))) {
      const d = discipline(key, 'levels key');
      levels[d] = gradeRange(value, `levels.${d}`, scaleOf(d));
    }
  }

  const gear: Gear[] = [];
  if (o.gear !== undefined && o.gear !== null) {
    if (!Array.isArray(o.gear)) throw badRequest('gear must be a list');
    for (const g of o.gear) {
      if (typeof g !== 'string' || !(GEAR as readonly string[]).includes(g)) {
        throw badRequest(`gear must be from ${GEAR.join(', ')}`);
      }
      if (!gear.includes(g as Gear)) gear.push(g as Gear);
    }
  }

  const gearPhotos: string[] = [];
  if (o.gearPhotos !== undefined && o.gearPhotos !== null) {
    if (!Array.isArray(o.gearPhotos)) throw badRequest('gearPhotos must be a list');
    if (o.gearPhotos.length > MAX_GEAR_PHOTOS) throw badRequest(`at most ${MAX_GEAR_PHOTOS} gearPhotos`);
    for (const [i, p] of o.gearPhotos.entries()) gearPhotos.push(photoKey(p, `gearPhotos[${i}]`, photoOwners));
  }

  let home: Location | undefined;
  if (o.location !== undefined && o.location !== null) home = location(o.location, 'location');
  const areas: Location[] = [];
  if (o.areas !== undefined && o.areas !== null) {
    if (!Array.isArray(o.areas)) throw badRequest('areas must be a list');
    if (o.areas.length > MAX_AREAS) throw badRequest(`at most ${MAX_AREAS} areas`);
    for (const [i, a] of o.areas.entries()) areas.push(location(a, `areas[${i}]`));
  }

  return {
    name,
    ...(age === undefined ? {} : { age }),
    bio,
    ...(photo ? { photo } : {}),
    levels,
    gear,
    gearPhotos,
    ...(home ? { location: home } : {}),
    areas,
  };
}

export type PlanInput = Omit<Plan, 'id' | 'organizerId' | 'memberIds'>;

const HOUR = 3600 * 1000;

/** A plan from POST or PUT /api/plans (a Plan without id, organizerId, memberIds). */
export function planInput(body: unknown, now: Date): PlanInput {
  const o = asObject(body);
  const d = discipline(o.discipline);
  const place = text(o.place, 'place', { min: 1, max: 80 });
  const area = text(o.area, 'area', { max: 120 });
  const sectorId = text(o.sectorId, 'sectorId', { max: 64 });
  // The first day: both or neither (an undated plan, its day still open).
  const dated = (o.start !== undefined && o.start !== null) || (o.end !== undefined && o.end !== null);
  const first = dated ? dayWindow(o, '', now) : undefined;
  const moreDays: DayWindow[] = [];
  if (o.moreDays !== undefined && o.moreDays !== null) {
    if (!Array.isArray(o.moreDays)) throw badRequest('moreDays must be a list');
    if (o.moreDays.length > 0 && !first) throw badRequest('moreDays needs a start');
    if (o.moreDays.length > MAX_MORE_DAYS) throw badRequest(`at most ${MAX_MORE_DAYS} more days`);
    let previousEnd = first ? Date.parse(first.end) : 0;
    for (const [i, w] of o.moreDays.entries()) {
      const day = dayWindow(asObject(w, `moreDays[${i}]`), `moreDays[${i}].`, now);
      if (Date.parse(day.start) < previousEnd) throw badRequest(`moreDays[${i}] must start after the day before ends`);
      previousEnd = Date.parse(day.end);
      moreDays.push(day);
    }
  }
  const grades = gradeRange(o.grades, 'grades', scaleOf(d));
  const notes = text(o.notes, 'notes', { max: 1000 });
  // Both or neither: a crag's point (public, so kept to ~10 m).
  let point: { lat: number; lon: number } | undefined;
  if ((o.lat !== undefined && o.lat !== null) || (o.lon !== undefined && o.lon !== null)) {
    point = { lat: round(coordinate(o.lat, 'lat', 90), 4), lon: round(coordinate(o.lon, 'lon', 180), 4) };
  }
  return {
    discipline: d,
    place,
    area,
    ...(sectorId ? { sectorId } : {}),
    ...point,
    ...first,
    ...(moreDays.length ? { moreDays } : {}),
    grades,
    notes,
  };
}

/** A plan's days, besides the first: two weeks in all. */
export const MAX_MORE_DAYS = 13;

/** One day's window (`<prefix>start`, `<prefix>end`): in the next year, up to 24 hours long. */
function dayWindow(o: Json, prefix: string, now: Date): DayWindow {
  if (typeof o.start !== 'string') throw badRequest(`${prefix}start must be an ISO 8601 date`);
  if (typeof o.end !== 'string') throw badRequest(`${prefix}end must be an ISO 8601 date`);
  const start = parseDate(o.start, `${prefix}start`);
  const end = parseDate(o.end, `${prefix}end`);
  if (start.getTime() <= now.getTime()) throw badRequest(`${prefix}start must be in the future`);
  if (start.getTime() > now.getTime() + 366 * 24 * HOUR) throw badRequest(`${prefix}start is more than a year away`);
  if (end.getTime() <= start.getTime()) throw badRequest(`${prefix}end must be after start`);
  if (end.getTime() > start.getTime() + 24 * HOUR) throw badRequest(`${prefix}end must be at most 24 hours after start`);
  return { start: start.toISOString(), end: end.toISOString() };
}

/**
 * A chat message (POST /api/plans/{id}/messages): text (up to 2000
 * characters), an attachment (a key from POST /api/plans/{id}/media for
 * this plan), or both; never neither.
 */
export function messageInput(body: unknown, planId: string): { text: string; attachment?: Attachment } {
  const o = asObject(body);
  const attachment =
    o.attachment === undefined || o.attachment === null || o.attachment === '' ? undefined : chatMediaKey(o.attachment, planId);
  const message = text(o.text, 'text', { min: attachment ? 0 : 1, max: 2000 });
  return { text: message, ...(attachment ? { attachment } : {}) };
}

/** Chat media's extensions: photos as profile photos take them, and MP4 or QuickTime videos. */
export const CHAT_MEDIA_KINDS: Record<string, Attachment['kind']> = {
  jpg: 'image',
  png: 'image',
  webp: 'image',
  mp4: 'video',
  mov: 'video',
};
const CHAT_KEY = /^chat\/([A-Za-z0-9_-]{1,64})\/[A-Za-z0-9_-]{8,64}\.([a-z0-9]{2,4})$/;

/** A chat media key (as issued by POST /api/plans/{id}/media): `chat/<planId>/<name>.<ext>`, for this plan. */
export function chatMediaKey(value: unknown, planId: string): Attachment {
  const match = typeof value === 'string' ? CHAT_KEY.exec(value) : null;
  const kind = match && Object.hasOwn(CHAT_MEDIA_KINDS, match[2]!) ? CHAT_MEDIA_KINDS[match[2]!] : undefined;
  if (!match || !kind) throw badRequest("attachment isn't a key from /api/plans/{id}/media");
  if (match[1] !== planId) throw badRequest("attachment isn't this plan's");
  return { key: value as string, kind };
}

const PLAN_PIC_KEY = /^plans\/([A-Za-z0-9_-]{1,64})\/[A-Za-z0-9_-]{8,64}\.(jpg|png|webp)$/;

/** A plan photo's key (as issued by POST /api/plans/{id}/pics/upload): `plans/<planId>/<name>.<jpg|png|webp>`, for this plan. */
export function planPicKey(value: unknown, planId: string): string {
  const match = typeof value === 'string' ? PLAN_PIC_KEY.exec(value) : null;
  if (!match) throw badRequest("key isn't one from /api/plans/{id}/pics/upload");
  if (match[1] !== planId) throw badRequest("key isn't this plan's");
  return value as string;
}

export function parseDate(value: string, field: string): Date {
  // ISO 8601 with a time and a zone (Z or ±hh:mm).
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}:\d{2})$/.test(value)) {
    throw badRequest(`${field} must be an ISO 8601 date with a time zone`);
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw badRequest(`${field} isn't a valid date`);
  return date;
}

/** Ids the server made (climbers, plans) or the seed's (`seed-...`). */
export function id(value: string | undefined, field: string): string {
  if (!value || !/^[A-Za-z0-9_-]{1,64}$/.test(value)) throw badRequest(`${field} isn't a valid id`);
  return value;
}
