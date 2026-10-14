// An in-memory stand-in for Store with the same behavior the routes rely
// on (version checks included), so the API's authorization and flows can be
// tested without DynamoDB. The real Store is exercised against Floci.
import type { SessionRecord } from '../src/auth.js';
import type { Effects, Delivery } from '../src/domain/rules.js';
import { type Climber, type JoinRequest, type Message, type Notice, isOpen } from '../src/domain/model.js';
import { Conflict, type LoadedPlan, type Store, type VersionedPlan } from '../src/store/store.js';

export class FakeStore {
  subjects = new Map<string, string>();
  climbers = new Map<string, Climber>();
  plans = new Map<string, VersionedPlan>();
  requests = new Map<string, JoinRequest>();
  passes = new Set<string>();
  noticeMap = new Map<string, Map<string, Notice>>();
  msgs: Message[] = [];
  sessions = new Map<string, SessionRecord>();
  /** Session writes (puts and slides), to check there's at most one a day. */
  sessionWrites = 0;

  asStore(): Store {
    return this as unknown as Store;
  }

  async putSession(s: SessionRecord) {
    if (this.sessions.has(s.id)) throw new Conflict('exists');
    this.sessions.set(s.id, { ...s });
    this.sessionWrites++;
  }
  async getSession(id: string) {
    const s = this.sessions.get(id);
    return s ? { ...s } : undefined;
  }
  async touchSession(id: string, previous: string, lastUsedAt: string, ttl: number) {
    const s = this.sessions.get(id);
    if (!s || s.lastUsedAt !== previous) return;
    this.sessions.set(id, { ...s, lastUsedAt, ttl });
    this.sessionWrites++;
  }
  async deleteSession(id: string) { this.sessions.delete(id); }
  async deleteSessions(subject: string) {
    for (const [id, s] of this.sessions) if (s.subject === subject) this.sessions.delete(id);
  }

  async climberIdFor(subject: string) { return this.subjects.get(subject); }
  async getClimber(id: string) { return this.climbers.get(id); }
  async getClimbers(ids: Iterable<string>) {
    return Object.fromEntries([...ids].flatMap((id) => (this.climbers.has(id) ? [[id, this.climbers.get(id)!]] : [])));
  }
  async createProfile(subject: string, c: Climber) {
    if (this.subjects.has(subject)) throw new Conflict('exists');
    this.subjects.set(subject, c.id);
    this.climbers.set(c.id, c);
  }
  async saveProfile(c: Climber) { this.climbers.set(c.id, c); }
  async getPlan(id: string) { return this.plans.get(id); }
  async getPlans(ids: Iterable<string>) { return [...new Set(ids)].flatMap((id) => (this.plans.has(id) ? [this.plans.get(id)!.plan] : [])); }
  async loadPlan(id: string): Promise<LoadedPlan | undefined> {
    const p = this.plans.get(id);
    return p ? { ...p, requests: [...this.requests.values()].filter((r) => r.planId === id) } : undefined;
  }
  async planRequests(id: string) { return [...this.requests.values()].filter((r) => r.planId === id); }
  async getRequest(planId: string, climberId: string) { return this.requests.get(`${planId}/${climberId}`); }
  async upcomingPlans(after: string) { return [...this.plans.values()].map((p) => p.plan).filter((p) => p.start > after); }
  async memberPlanIds(cid: string) { return [...this.plans.values()].filter((p) => p.plan.memberIds.includes(cid)).map((p) => p.plan.id); }
  async passedPlanIds(cid: string) { return [...this.passes].filter((k) => k.startsWith(`${cid}|`)).map((k) => k.split('|')[1]!); }
  async addPass(cid: string, planId: string) { this.passes.add(`${cid}|${planId}`); }
  async deletePasses(cid: string, planIds: string[]) { for (const p of planIds) this.passes.delete(`${cid}|${p}`); }
  async askedRequests(cid: string) { return [...this.requests.values()].filter((r) => r.climberId === cid); }
  async openRequests() { return [...this.requests.values()].filter(isOpen); }
  async saveDismissed(r: JoinRequest) {
    if (!this.requests.get(r.id)?.rejected) throw new Conflict('changed');
    this.requests.set(r.id, r);
  }
  async apply(previous: VersionedPlan | null, e: Effects) {
    const id = previous?.plan.id ?? e.plan!.id;
    const current = this.plans.get(id);
    if (previous ? current?.version !== previous.version : current) throw new Conflict('changed');
    if (!e.plan) {
      this.plans.delete(id);
      for (const [k, r] of this.requests) if (r.planId === id) this.requests.delete(k);
      this.msgs = this.msgs.filter((m) => m.planId !== id);
    } else {
      this.plans.set(id, { plan: e.plan, version: (previous?.version ?? 0) + 1 });
      for (const r of e.requests) this.requests.set(r.id, r);
      this.msgs.push(...e.messages);
    }
    await this.deliver(e.notices);
  }
  async ask(previous: VersionedPlan, e: Effects) {
    if (this.plans.get(previous.plan.id)?.version !== previous.version) throw new Conflict('changed');
    const r = e.requests[0]!;
    if (this.requests.has(r.id)) throw new Conflict('exists');
    this.requests.set(r.id, r);
    this.msgs.push(...e.messages);
    await this.deliver(e.notices);
  }
  async deliver(ds: Delivery[]) {
    for (const d of ds) {
      if (!this.noticeMap.has(d.to)) this.noticeMap.set(d.to, new Map());
      this.noticeMap.get(d.to)!.set(d.notice.id, d.notice);
    }
  }
  async notices(cid: string) {
    return [...(this.noticeMap.get(cid)?.values() ?? [])].sort((a, b) => (a.time > b.time ? -1 : 1));
  }
  async markNoticesRead(cid: string) {
    for (const [k, n] of this.noticeMap.get(cid) ?? []) this.noticeMap.get(cid)!.set(k, { ...n, read: true });
  }
  async messages(planId: string, after?: string) {
    return this.msgs.filter((m) => m.planId === planId && (!after || m.time > after));
  }
  async putMessage(m: Message) { this.msgs.push(m); }
}
