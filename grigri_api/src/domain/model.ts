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
}

/** A profile as other people see it: without where its climber is. */
export type PublicClimber = Omit<Climber, 'location' | 'areas'>;

export function publicClimber(c: Climber): PublicClimber {
  const { location: _location, areas: _areas, ...rest } = c;
  return rest;
}

/**
 * A plan to climb. No title (the app names it by its place) and no group
 * size: a group is as big as the people who match, so it's never full.
 */
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
  /** ISO 8601 UTC. */
  start: string;
  /** ISO 8601 UTC, after start and at most 24 hours later. */
  end: string;
  grades: GradeRange;
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
 * to join a plan I'm in; nudge: they're still waiting for my answer.
 */
export type NoticeKind = 'accepted' | 'declined' | 'request' | 'nudge';

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
