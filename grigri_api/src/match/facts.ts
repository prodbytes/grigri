// The facts the match model (model.json) takes for one climber and one
// plan, pure: the API knows them all, so aityx runs the model on them
// directly (System One, no AI). The geometry stays here: the model gets the
// distance, not the points.
import type { Climber, Plan } from '../domain/model.js';
import { distanceKm } from '../domain/rules.js';

/** The match model's state (its inputs, by name). */
export interface MatchFacts {
  discipline_climbed: boolean;
  grades_short: number;
  grades_over: number;
  distance_known: boolean;
  distance_km: number;
  group_size: number;
  open_requests: number;
  days_until_start: number;
}

const DAY_MS = 24 * 60 * 60 * 1000;
/** An undated plan's days until start: time enough for every member to answer. */
const UNDATED_DAYS = 30;
/** The model's grade inputs go up to 30; no scale is that long. */
const MAX_GRADES = 30;

/**
 * One climber against one plan. [openRequests]: the requests waiting on the
 * plan, the climber's own left out.
 */
export function matchFacts(
  climber: Pick<Climber, 'levels' | 'location' | 'areas'>,
  plan: Plan,
  openRequests: number,
  now: Date,
): MatchFacts {
  const level = climber.levels[plan.discipline];
  const climbed = level !== undefined && level.scale === plan.grades.scale;
  const km = distanceKm(climber, plan);
  const clamp = (n: number) => Math.min(MAX_GRADES, Math.max(0, n));
  return {
    discipline_climbed: climbed,
    grades_short: climbed ? clamp(plan.grades.min - level.max) : 0,
    grades_over: climbed ? clamp(level.min - plan.grades.max) : 0,
    distance_known: km !== undefined,
    distance_km: km === undefined ? 0 : Math.round(km * 10) / 10,
    group_size: Math.max(1, plan.memberIds.length),
    open_requests: Math.max(0, openRequests),
    days_until_start: plan.start === undefined ? UNDATED_DAYS : Math.max(0, Math.round(((Date.parse(plan.start) - now.getTime()) / DAY_MS) * 100) / 100),
  };
}
