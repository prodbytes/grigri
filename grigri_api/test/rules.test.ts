import { describe, expect, it } from 'vitest';
import type { Climber, JoinRequest, Plan } from '../src/domain/model.js';
import * as rules from '../src/domain/rules.js';

const now = new Date('2030-05-01T10:00:00.000Z');
let n = 0;
const ctx: rules.Context = {
  now,
  newId: () => `m${n++}`,
  name: (id) => ({ ada: 'Ada', ben: 'Ben', cy: 'Cy', dee: 'Dee', eve: 'Eve' })[id] ?? 'Someone',
};

function plan(p: Partial<Plan> = {}): Plan {
  return {
    id: 'p1',
    organizerId: 'ada',
    discipline: 'sport',
    place: 'Somewhere',
    area: '',
    start: '2030-05-10T08:00:00.000Z',
    end: '2030-05-10T14:00:00.000Z',
    grades: { scale: 'routes', min: 6, max: 10 },
    memberIds: ['ada'],
    notes: '',
    ...p,
  };
}

function request(climberId: string, r: Partial<JoinRequest> = {}): JoinRequest {
  return { id: `p1/${climberId}`, planId: 'p1', climberId, acceptedBy: [], rejected: false, time: '2030-04-30T10:00:00.000Z', ...r };
}

const me: Climber = { id: 'me', name: 'Me', bio: '', levels: { sport: { scale: 'routes', min: 8, max: 12 } }, gear: [], gearPhotos: [] };

describe('discover', () => {
  it('keeps upcoming plans that I am not in and have not passed or asked (never full)', () => {
    const plans = [
      plan({ id: 'past', start: '2030-04-01T08:00:00.000Z' }),
      plan({ id: 'big', memberIds: ['ada', 'ben', 'cy', 'dee', 'eve', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm'] }),
      plan({ id: 'mine', memberIds: ['ada', 'me'] }),
      plan({ id: 'passed' }),
      plan({ id: 'asked' }),
      plan({ id: 'ok' }),
    ];
    const out = rules.discover(plans, me, new Set(['passed']), new Set(['asked']), now);
    expect(out.map((p) => p.id)).toEqual(['big', 'ok']);
  });

  it('sorts fitting grades first, then soonest', () => {
    const plans = [
      plan({ id: 'late-fit', start: '2030-06-01T08:00:00.000Z' }),
      plan({ id: 'soon-nofit', start: '2030-05-02T08:00:00.000Z', grades: { scale: 'routes', min: 18, max: 20 } }),
      plan({ id: 'soon-fit', start: '2030-05-03T08:00:00.000Z' }),
      plan({ id: 'boulder', discipline: 'bouldering', grades: { scale: 'boulders', min: 0, max: 3 }, start: '2030-05-02T09:00:00.000Z' }),
    ];
    const out = rules.discover(plans, me, new Set(), new Set(), now);
    expect(out.map((p) => p.id)).toEqual(['soon-fit', 'late-fit', 'soon-nofit', 'boulder']);
  });
});

describe('ask', () => {
  it('creates a request, notifies every member and posts a request note', () => {
    const p = plan({ memberIds: ['ada', 'ben'] });
    const e = rules.ask(p, 'cy', undefined, ctx);
    expect(e.requests).toEqual([request('cy', { time: now.toISOString() })]);
    expect(e.notices.map((d) => d.to)).toEqual(['ada', 'ben']);
    expect(e.notices[0]!.notice).toMatchObject({ kind: 'request', id: 'p1/request/cy', climberId: 'cy', planTitle: 'Somewhere' });
    expect(e.messages[0]).toMatchObject({ authorId: null, text: 'Cy asked to join', requestId: 'p1/cy' });
  });

  it('refuses members, double asks and started plans', () => {
    expect(() => rules.ask(plan(), 'ada', undefined, ctx)).toThrow(/already in/);
    expect(() => rules.ask(plan(), 'cy', request('cy'), ctx)).toThrow(/already asked/);
    expect(() => rules.ask(plan({ start: '2030-04-01T00:00:00.000Z' }), 'cy', undefined, ctx)).toThrow(/started/);
  });
});

describe('accept', () => {
  it('waits for every member (unanimous yes)', () => {
    const state = { plan: plan({ memberIds: ['ada', 'ben'] }), requests: [request('cy')] };
    const e = rules.accept(state, { id: 'ada' }, 'cy', ctx);
    expect(e.plan!.memberIds).toEqual(['ada', 'ben']);
    expect(e.requests).toEqual([request('cy', { acceptedBy: ['ada'] })]);
    expect(e.matches).toEqual([]);
    expect(e.notices).toEqual([]);
  });

  it('lets them in on the last yes: membership, a joined note and an accepted notice', () => {
    const state = { plan: plan({ memberIds: ['ada', 'ben'] }), requests: [request('cy', { acceptedBy: ['ada'] })] };
    const e = rules.accept(state, { id: 'ben' }, 'cy', ctx);
    expect(e.plan!.memberIds).toEqual(['ada', 'ben', 'cy']);
    expect(e.requests).toEqual([request('cy', { acceptedBy: ['ada', 'ben'], joined: true })]);
    expect(e.matches).toEqual([{ plan: e.plan, newcomerId: 'cy' }]);
    expect(e.messages.map((m) => m.text)).toEqual(['Cy joined the plan 🎉']);
    expect(e.notices).toEqual([{ to: 'cy', notice: expect.objectContaining({ kind: 'accepted', id: 'p1/accepted' }) }]);
  });

  it('makes the requests still open wait for the newcomer too, and tells them', () => {
    const state = {
      plan: plan(),
      requests: [request('cy'), request('dee', { acceptedBy: ['ada'] })],
    };
    const e = rules.accept(state, { id: 'ada' }, 'cy', ctx);
    expect(e.plan!.memberIds).toEqual(['ada', 'cy']);
    // dee had ada's yes, but now cy must say yes too.
    expect(e.matches.map((m) => m.newcomerId)).toEqual(['cy']);
    expect(e.notices).toContainEqual({ to: 'cy', notice: expect.objectContaining({ kind: 'request', climberId: 'dee' }) });
  });

  it('has no size limit: everyone accepted joins', () => {
    const many = ['ada', 'b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8', 'b9', 'b10', 'b11', 'b12'];
    const state = { plan: plan({ memberIds: many }), requests: [request('cy', { acceptedBy: many.slice(1) })] };
    const e = rules.accept(state, { id: 'ada' }, 'cy', ctx);
    expect(e.plan!.memberIds).toHaveLength(14);
    expect(e.matches.map((m) => m.newcomerId)).toEqual(['cy']);
  });

  it('is members only, unless an admin', () => {
    const state = { plan: plan({ memberIds: ['ada', 'ben'] }), requests: [request('cy')] };
    expect(() => rules.accept(state, { id: 'eve' }, 'cy', ctx)).toThrow(/not in this plan/);
    const e = rules.accept(state, { id: 'eve', admin: true }, 'cy', ctx);
    expect(e.plan!.memberIds).toEqual(['ada', 'ben', 'cy']);
    expect(e.matches[0]!.newcomerId).toBe('cy');
  });

  it('closed requests are refused', () => {
    const rejected = { plan: plan(), requests: [request('cy', { rejected: true })] };
    expect(() => rules.accept(rejected, { id: 'ada' }, 'cy', ctx)).toThrow(/declined/);
    expect(() => rules.accept({ plan: plan(), requests: [] }, { id: 'ada' }, 'cy', ctx)).toThrow(/no such request/);
  });
});

describe('reject', () => {
  it('one no is enough: rejected, and a declined notice for them', () => {
    const state = { plan: plan({ memberIds: ['ada', 'ben'] }), requests: [request('cy', { acceptedBy: ['ada'] })] };
    const e = rules.reject(state, { id: 'ben' }, 'cy', ctx);
    expect(e.requests[0]!.rejected).toBe(true);
    expect(e.notices).toEqual([{ to: 'cy', notice: expect.objectContaining({ kind: 'declined', id: 'p1/declined' }) }]);
    expect(() => rules.reject(state, { id: 'eve' }, 'cy', ctx)).toThrow(/not in this plan/);
    expect(rules.reject(state, { id: 'eve', admin: true }, 'cy', ctx).requests[0]!.rejected).toBe(true);
  });
});

describe('leave', () => {
  it('hands the plan to the next member when the organizer leaves', () => {
    const e = rules.leave({ plan: plan({ memberIds: ['ada', 'ben', 'cy'] }), requests: [] }, 'ada', ctx);
    expect(e.plan).toMatchObject({ organizerId: 'ben', memberIds: ['ben', 'cy'] });
    expect(e.messages.map((m) => m.text)).toEqual(['Ada left the plan']);
  });

  it('ends the plan when the last member leaves', () => {
    expect(rules.leave({ plan: plan(), requests: [request('cy')] }, 'ada', ctx).plan).toBeNull();
  });

  it('open requests stop waiting for the leaver, so someone may join', () => {
    const state = { plan: plan({ memberIds: ['ada', 'ben'] }), requests: [request('cy', { acceptedBy: ['ada'] })] };
    const e = rules.leave(state, 'ben', ctx);
    expect(e.plan!.memberIds).toEqual(['ada', 'cy']);
    expect(e.matches.map((m) => m.newcomerId)).toEqual(['cy']);
  });

  it('drops the leaver from acceptances', () => {
    const state = { plan: plan({ memberIds: ['ada', 'ben', 'cy'] }), requests: [request('dee', { acceptedBy: ['cy'] })] };
    const e = rules.leave(state, 'cy', ctx);
    expect(e.requests).toEqual([request('dee', { acceptedBy: [] })]);
  });

  it('refuses non-members', () => {
    expect(() => rules.leave({ plan: plan(), requests: [] }, 'eve', ctx)).toThrow(/not in this plan/);
  });
});

describe('plans', () => {
  it('only the organizer edits; members stay; a sectorId left out is cleared', () => {
    const p = plan({ memberIds: ['ada', 'ben'], sectorId: 'osm:n1' });
    const input = { discipline: 'sport' as const, place: 'X', area: '', start: p.start, end: p.end, grades: p.grades, notes: '' };
    expect(() => rules.updatePlan(p, 'ben', input)).toThrow(/organizer/);
    const updated = rules.updatePlan(p, 'ada', input);
    expect(updated).toMatchObject({ place: 'X', memberIds: ['ada', 'ben'], organizerId: 'ada' });
    expect(updated).not.toHaveProperty('sectorId');
    expect(rules.updatePlan(p, 'ada', { ...input, sectorId: 'osm:n2' }).sectorId).toBe('osm:n2');
  });

  it('a new plan has its organizer as its only member and a first note', () => {
    const input = { discipline: 'gym' as const, place: 'G', area: '', start: '2030-05-02T08:00:00.000Z', end: '2030-05-02T10:00:00.000Z', grades: plan().grades, notes: '' };
    const e = rules.createPlan('new', 'ada', input, ctx);
    expect(e.plan).toMatchObject({ id: 'new', organizerId: 'ada', memberIds: ['ada'] });
    expect(e.messages[0]!.text).toMatch(/^Ada created the plan/);
  });

  it('dismiss is the requester\'s, on declined requests only', () => {
    expect(() => rules.dismiss(undefined, 'cy')).toThrow(/no such/);
    expect(() => rules.dismiss(request('cy'), 'cy')).toThrow(/wasn't declined/);
    expect(() => rules.dismiss(request('cy', { rejected: true }), 'dee')).toThrow(/no such/);
    expect(rules.dismiss(request('cy', { rejected: true }), 'cy').dismissed).toBe(true);
  });

  it('chat is members only', () => {
    expect(() => rules.chatMessage(plan(), 'eve', 'hi', ctx)).toThrow(/not in this plan/);
    expect(rules.chatMessage(plan(), 'ada', 'hi', ctx)).toMatchObject({ authorId: 'ada', text: 'hi' });
  });

  it('toReview lists open requests on my plans that I have not accepted', () => {
    const states = [
      { plan: plan({ memberIds: ['ada', 'ben'] }), requests: [request('cy'), request('dee', { acceptedBy: ['ada'] }), request('eve', { rejected: true })] },
      { plan: plan({ id: 'p2', memberIds: ['ben'] }), requests: [{ ...request('cy'), id: 'p2/cy', planId: 'p2' }] },
    ];
    expect(rules.toReview(states, 'ada').map((r) => r.id)).toEqual(['p1/cy']);
  });
});
