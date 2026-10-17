// Reports (specs/moderation.md): any signed-in climber reports a profile,
// a plan, a chat message, a plan photo or an ad; admins review them in
// Admin → Reports (dismiss, remove the content, or block its climber).
import { createHash } from 'node:crypto';
import { badRequest } from './errors.js';
import { asObject, id } from './validate.js';

export const REPORT_KINDS = ['profile', 'plan', 'message', 'pic', 'ad'] as const;
export type ReportKind = (typeof REPORT_KINDS)[number];

export const REPORT_REASONS = ['spam', 'harassment', 'inappropriate', 'fake', 'other'] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

/** open: waiting for an admin; then dismissed, removed (the content) or blocked (its climber). */
export type ReportStatus = 'open' | 'dismissed' | 'removed' | 'blocked';

export const MAX_REPORT_TEXT = 500;

/** What was reported, as it was when reported (so the admin sees it even if it changes). */
export interface ReportContent {
  /** A profile's name, a plan's place, … */
  title?: string;
  /** A profile's bio, a plan's notes, a message's or an ad's text. */
  text?: string;
  /** Photos (keys served at /photos/<key>): a profile's photo and gear photos, a message's attachment, a plan photo, an ad's media. */
  media?: { key: string; kind: 'image' | 'video' }[];
  /** An ad's link. */
  link?: string;
}

export interface Report {
  id: string;
  kind: ReportKind;
  /** The profile's climber id, or the plan's, message's, photo's or ad's id. */
  targetId: string;
  /** A message's or plan photo's plan. */
  planId?: string;
  /** Whose content it is: the profile's climber, the plan's organizer, the message's author, who added the photo, the ad's owner. */
  subjectId: string;
  /** Who reported it (only admins ever see this). */
  reporterId: string;
  reason: ReportReason;
  /** The reporter's own words (optional). */
  text: string;
  content: ReportContent;
  status: ReportStatus;
  time: string;
  /** When an admin handled it, and who. */
  resolvedAt?: string;
  resolvedBy?: string;
}

export interface ReportInput {
  kind: ReportKind;
  targetId: string;
  planId?: string;
  reason: ReportReason;
  text: string;
}

/** POST /api/reports's body: {kind, targetId, planId? (a message's or photo's), reason, text?}. */
export function reportInput(body: unknown): ReportInput {
  const o = asObject(body);
  const kind = o.kind;
  if (typeof kind !== 'string' || !(REPORT_KINDS as readonly string[]).includes(kind)) {
    throw badRequest(`kind must be one of ${REPORT_KINDS.join(', ')}`);
  }
  const reason = o.reason;
  if (typeof reason !== 'string' || !(REPORT_REASONS as readonly string[]).includes(reason)) {
    throw badRequest(`reason must be one of ${REPORT_REASONS.join(', ')}`);
  }
  const targetId = id(typeof o.targetId === 'string' ? o.targetId : undefined, 'targetId');
  const needsPlan = kind === 'message' || kind === 'pic';
  const planId = needsPlan ? id(typeof o.planId === 'string' ? o.planId : undefined, 'planId') : undefined;
  if (o.text !== undefined && o.text !== null && typeof o.text !== 'string') throw badRequest('text must be a string');
  const text = typeof o.text === 'string' ? o.text.trim() : '';
  // eslint-disable-next-line no-control-regex
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)) throw badRequest('text has control characters');
  if ([...text].length > MAX_REPORT_TEXT) throw badRequest(`text is longer than ${MAX_REPORT_TEXT} characters`);
  return { kind: kind as ReportKind, targetId, ...(planId ? { planId } : {}), reason: reason as ReportReason, text };
}

/**
 * A report's id: the same for the same reporter and content, so reporting
 * it again replaces the report (no flood of copies).
 */
export function reportId(reporterId: string, kind: ReportKind, targetId: string): string {
  return createHash('sha256').update(`${reporterId}|${kind}|${targetId}`).digest('base64url').slice(0, 16);
}
