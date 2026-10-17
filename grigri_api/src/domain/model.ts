// The API's JSON shapes (specs/api.md) and the climbing vocabulary they use,
// shared by the domain rules, the store and the seed.

export const DISCIPLINES = ['sport', 'trad', 'bouldering', 'gym'] as const;
export type Discipline = (typeof DISCIPLINES)[number];

export const GEAR = ['rope', 'quickdraws', 'rack', 'crashPad', 'car'] as const;
export type Gear = (typeof GEAR)[number];

/**
 * Grade scales, easiest first: grades are indices into these lists (shown
 * here in European notation; the app may write them in American, a display
 * choice that never changes the index).
 */
export const SCALES = {
  /** Routes: French 4a..9a (YDS 5.5..5.14d). */
  routes: [
    '4a', '4b', '4c', '5a', '5b', '5c',
    '6a', '6a+', '6b', '6b+', '6c', '6c+',
    '7a', '7a+', '7b', '7b+', '7c', '7c+',
    '8a', '8a+', '8b', '8b+', '8c', '8c+', '9a',
  ],
  /** Boulders: Font 3..8B (V VB..V13). */
  boulders: ['3', '4', '5', '5+', '6A', '6B', '6C', '7A', '7A+', '7B', '7C', '7C+', '8A', '8A+', '8B'],
} as const;
export type Scale = keyof typeof SCALES;

/** Older names of the scales, still accepted on input. */
export const LEGACY_SCALES: Record<string, Scale> = { french: 'routes', vScale: 'boulders' };

/** The scale a discipline is graded on: bouldering boulders, the rest routes. */
export function scaleOf(discipline: Discipline): Scale {
  return discipline === 'bouldering' ? 'boulders' : 'routes';
}

export interface GradeRange {
  scale: Scale;
  min: number;
  max: number;
}

/** Whether two ranges share a grade (never across scales). */
export function overlaps(a: GradeRange, b: GradeRange): boolean {
  return a.scale === b.scale && a.min <= b.max && b.min <= a.max;
}

/** A point on the map with a name to show, e.g. a crag, a gym or a town. */
export interface Location {
  name: string;
  lat: number;
  lon: number;
}

/** The most areas of interest a profile keeps, besides its location. */
export const MAX_AREAS = 5;

/**
 * A climber's profile. `location` and `areas` are private: only the
 * climber's own profile (GET/PUT /api/me) carries them; see publicClimber.
 */
export interface Climber {
  id: string;
  name: string;
  age?: number;
  bio: string;
  photo?: string;
  levels: Partial<Record<Discipline, GradeRange>>;
  gear: Gear[];
  gearPhotos: string[];
  /** Where I am (rounded to ~1 km). Private. */
  location?: Location;
  /** Other places I'd climb near (rounded to ~1 km). Private. */
  areas?: Location[];
  /** Made-up, to show how Grigri works (the seed's, on RC and local); the app says so. Never set through the API. */
  demo?: true;
  /**
   * Blocked by an admin (rbacr's `blocked` role, never stored here): can't
   * use Grigri, and their plans leave the deck. Only on the admin's list.
   */
  blocked?: true;
}

/** A profile as other people see it: without where its climber is, or whether they're blocked. */
export type PublicClimber = Omit<Climber, 'location' | 'areas' | 'blocked'>;

export function publicClimber(c: Climber): PublicClimber {
  const { location: _location, areas: _areas, blocked: _blocked, ...rest } = c;
  return rest;
}

/**
 * Who lets people into a plan (specs/matching.md#plan-types):
 * - private: every member says yes (the default, and what a plan without
 *   a type is);
 * - open: nobody; a swipe right joins at once;
 * - guided: the organizer, a guide, alone; it carries a price.
 */
export const PLAN_TYPES = ['private', 'open', 'guided'] as const;
export type PlanType = (typeof PLAN_TYPES)[number];

/** The currencies a guided plan's price may be in. */
export const CURRENCIES = ['EUR', 'USD', 'GBP', 'CHF', 'BRL'] as const;
export type Currency = (typeof CURRENCIES)[number];

/** What a guided plan costs each climber, paid to the guide (not through Grigri). */
export interface Price {
  /** In the currency's units, at most two decimals. */
  amount: number;
  currency: Currency;
}

/** A plan's type: absent (plans made before types) is private. */
export function planType(plan: Pick<Plan, 'type'>): PlanType {
  return plan.type ?? 'private';
}

/**
 * Whose yes a request needs: every member (private), the organizer
 * (guided) or nobody (open).
 */
export function deciders(plan: Plan): string[] {
  switch (planType(plan)) {
    case 'open':
      return [];
    case 'guided':
      return [plan.organizerId];
    default:
      return plan.memberIds;
  }
}

/**
 * A plan to climb. No title (the app names it by its place) and no group
 * size: a group is as big as the people who match, so it's never full.
 */
/** One day's time window: ISO 8601 UTC, end after start and at most 24 hours later. */
export interface DayWindow {
  start: string;
  end: string;
}

export interface Plan {
  id: string;
  organizerId: string;
  discipline: Discipline;
  /** The sector, crag or gym. */
  place: string;
  /** Where the place is, e.g. "Siurana, Spain". */
  area: string;
  /** The app's sector-index id (e.g. "osm:n123456"); absent when typed by hand. */
  sectorId?: string;
  /** Where the place is on the map, from the sector index; absent when typed by hand. */
  lat?: number;
  lon?: number;
  /** The first day's window, ISO 8601 UTC; absent (with end) while the day is undecided. */
  start?: string;
  /** ISO 8601 UTC, after start and at most 24 hours later. */
  end?: string;
  /** More days after the first, soonest first: each a window like start–end, starting after the one before ends. Absent for a one-day (or undated) plan. */
  moreDays?: DayWindow[];
  grades: GradeRange;
  /** Who lets people in; absent is private. */
  type?: PlanType;
  /** A guided plan's price per climber; only on guided plans. */
  price?: Price;
  /** Organizer first, then in join order. */
  memberIds: string[];
  notes: string;
  /** Made-up, to show how Grigri works (the seed's, on RC and local); the app says so. Never set through the API. */
  demo?: true;
}

/** Someone asking to join a plan (a swipe right). */
export interface JoinRequest {
  /** `<planId>/<climberId>` */
  id: string;
  planId: string;
  climberId: string;
  acceptedBy: string[];
  rejected: boolean;
  time: string;
  /** When the requester last nudged the members who haven't answered (ISO 8601 UTC); absent until they do. */
  nudgedAt?: string;
  /** Internal: they joined (the request is closed). Not in the JSON. */
  joined?: boolean;
  /** Internal: the requester cleared the "no". Not in the JSON. */
  dismissed?: boolean;
}

/**
 * accepted/declined: a group answered my request; request: someone asked
 * to join a plan I'm in; nudge: they're still waiting for my answer;
 * report: (admins) there are reports to review (planId and planTitle empty).
 */
export type NoticeKind = 'accepted' | 'declined' | 'request' | 'nudge' | 'report';

export interface Notice {
  id: string;
  kind: NoticeKind;
  planId: string;
  /** The plan's place when the notice was made. */
  planTitle: string;
  climberId?: string;
  time: string;
  read: boolean;
}

export interface Message {
  id: string;
  planId: string;
  /** null: the chat's own notes (joined, left, asked to join). */
  authorId: string | null;
  text: string;
  time: string;
  /** On a request note: the request it shows as a card. */
  requestId?: string;
  /** A member's photo or video (POST /api/plans/{id}/media). */
  attachment?: Attachment;
}

/** What a chat message can carry: one photo or one video, nothing else. */
export interface Attachment {
  /** Its key (served at /photos/<key>): `chat/<planId>/<id>.<ext>`. */
  key: string;
  kind: 'image' | 'video';
}

/**
 * A photo in a plan's "Your Pics": one a member added to the plan, or a
 * photo sent in its chat (added with the message). Members only.
 */
export interface PlanPic {
  id: string;
  planId: string;
  /** Served at /photos/<key>: `plans/<planId>/<id>.<ext>`, or a chat photo's `chat/<planId>/...`. */
  key: string;
  /** Who added it (or sent it in the chat). */
  uploaderId: string;
  time: string;
  /** From the chat: deleting it from the pics leaves the chat's photo. */
  fromChat: boolean;
}

/** A photo of GriGri Pics, Grigri's own photos of crags (the pics bucket). */
export interface GrigriPic {
  /** Served at /pics/<key>: `crags/<crag>/<name>.jpg`. */
  key: string;
  width: number;
  height: number;
  caption: string;
  /** Credit, as the license asks. */
  author: string;
  license: string;
  licenseUrl: string;
  /** Where it comes from (its page, e.g. on Wikimedia Commons). */
  source: string;
}

/** A crag (or a whole climbing area: ids `area:<name>`) and its photos, in GriGri Pics' catalog. */
export interface PicCrag {
  /** The sector index's id (OpenStreetMap's, e.g. "osm:n123"), or `area:<name>`. */
  id: string;
  name: string;
  area: string;
  lat: number;
  lon: number;
  photos: GrigriPic[];
}

/** GriGri Pics' catalog (pics/catalog.json), made from the photos' S3 annotations. */
export interface PicCatalog {
  generatedAt: string;
  crags: PicCrag[];
}

export interface Match {
  plan: Plan;
  newcomerId: string;
}

export function requestId(planId: string, climberId: string): string {
  return `${planId}/${climberId}`;
}

/** Waiting for the group: not turned down, not joined. */
export function isOpen(request: JoinRequest): boolean {
  return !request.rejected && !request.joined;
}

/** The public JSON of a request (internal flags left out). */
export function requestJson(r: JoinRequest): JoinRequest {
  return {
    id: r.id,
    planId: r.planId,
    climberId: r.climberId,
    acceptedBy: [...r.acceptedBy],
    rejected: r.rejected,
    time: r.time,
    ...(r.nudgedAt ? { nudgedAt: r.nudgedAt } : {}),
  };
}
