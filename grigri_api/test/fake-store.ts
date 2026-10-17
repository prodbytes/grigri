// An in-memory stand-in for Store with the same behavior the routes rely
// on (version checks included), so the API's authorization and flows can be
// tested without DynamoDB. The real Store is exercised against Floci.
import type { SessionRecord } from '../src/auth.js';
import type { Effects, Delivery } from '../src/domain/rules.js';
import { type Climber, type JoinRequest, type Message, type Notice, type PlanPic, isOpen } from '../src/domain/model.js';
import type { Subscription } from '../src/premium.js';
import { type Ad, type AdSettings, type AdStatus, DEFAULT_AD_SETTINGS } from '../src/domain/ads.js';
import { Conflict, type LoadedPlan, type Store, type VersionedPlan } from '../src/store/store.js';
import type { Wall } from '../src/domain/walls.js';

export class FakeStore {
  subjects = new Map<string, string>();
  climbers = new Map<string, Climber>();
  plans = new Map<string, VersionedPlan>();
  requests = new Map<string, JoinRequest>();
  passes = new Set<string>();
  noticeMap = new Map<string, Map<string, Notice>>();
  msgs: Message[] = [];
  pics: PlanPic[] = [];
  sessions = new Map<string, SessionRecord>();
  subscriptions = new Map<string, Subscription>();
  ads = new Map<string, Ad>();
  adSettings: AdSettings = DEFAULT_AD_SETTINGS;
  /** Session writes (puts and slides), to check there's at most one a day. */
  sessionWrites = 0;

  asStore(): Store {
    return this as unknown as Store;
  }

  async getSubscription(climberId: string) {
    const s = this.subscriptions.get(climberId);
    return s ? { ...s } : undefined;
  }
  async getSubscriptions(ids: Iterable<string>) {
    const out: Record<string, Subscription> = {};
    for (const id of ids) {
      const s = this.subscriptions.get(id);
      if (s) out[id] = { ...s };
    }
    return out;
  }
  async putSubscription(sub: Subscription) {
    this.subscriptions.set(sub.climberId, { ...sub });
  }

  /** App Store subscriptions' owners, by original transaction id. */
  appleOwners = new Map<string, string>();
  async claimAppleSubscription(originalTransactionId: string, climberId: string) {
    if (!this.appleOwners.has(originalTransactionId)) this.appleOwners.set(originalTransactionId, climberId);
    return this.appleOwners.get(originalTransactionId)!;
  }
  async appleOwner(originalTransactionId: string) {
    return this.appleOwners.get(originalTransactionId);
  }

  async getAd(id: string) {
    const a = this.ads.get(id);
    return a ? { ...a } : undefined;
  }
  async putAd(ad: Ad) {
    this.ads.set(ad.id, { ...ad });
  }
  async deleteAd(id: string) {
    this.ads.delete(id);
  }
  private newestFirst(ads: Ad[]) {
    return ads.map((a) => ({ ...a })).sort((a, b) => `${b.createdAt}#${b.id}`.localeCompare(`${a.createdAt}#${a.id}`));
  }
  async adsBy(ownerId: string) {
    return this.newestFirst([...this.ads.values()].filter((a) => a.ownerId === ownerId));
  }
  async adsByStatus(status: AdStatus) {
    return this.newestFirst([...this.ads.values()].filter((a) => a.status === status));
  }
  async getAdSettings() {
    return { ...this.adSettings };
  }
  async putAdSettings(settings: AdSettings) {
    this.adSettings = { ...settings };
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
  /** Sessions' emails by climber (made up: the subject's name). */
  async sessionEmail(id: string) {
    const subject = [...this.subjects].find(([, cid]) => cid === id)?.[0];
    return [...this.sessions.values()].find((x) => x.subject === subject && x.emailVerified)?.email;
  }
  async allClimbers() { return [...this.climbers.values()]; }
  async getPlan(id: string) { return this.plans.get(id); }
  async getPlans(ids: Iterable<string>) { return [...new Set(ids)].flatMap((id) => (this.plans.has(id) ? [this.plans.get(id)!.plan] : [])); }
  async loadPlan(id: string): Promise<LoadedPlan | undefined> {
    const p = this.plans.get(id);
    return p ? { ...p, requests: [...this.requests.values()].filter((r) => r.planId === id) } : undefined;
  }
  async planRequests(id: string) { return [...this.requests.values()].filter((r) => r.planId === id); }
  async getRequest(planId: string, climberId: string) { return this.requests.get(`${planId}/${climberId}`); }
  async upcomingPlans(after: string) { return [...this.plans.values()].map((p) => p.plan).filter((p) => (p.start ?? '~') > after); }
  async memberPlanIds(cid: string) { return [...this.plans.values()].filter((p) => p.plan.memberIds.includes(cid)).map((p) => p.plan.id); }
  async passedPlanIds(cid: string) { return [...this.passes].filter((k) => k.startsWith(`${cid}|`)).map((k) => k.split('|')[1]!); }
  left = new Set<string>();
  async addPass(cid: string, planId: string, _now?: Date, left = false) {
    this.passes.add(`${cid}|${planId}`);
    if (left) this.left.add(`${cid}|${planId}`);
  }
  async leftPlanIds(cid: string) { return [...this.left].filter((k) => k.startsWith(`${cid}|`)).map((k) => k.split('|')[1]!); }
  async deletePasses(cid: string, planIds: string[]) {
    for (const p of planIds) {
      this.passes.delete(`${cid}|${p}`);
      this.left.delete(`${cid}|${p}`);
    }
  }
  async askedRequests(cid: string) { return [...this.requests.values()].filter((r) => r.climberId === cid); }
  async openRequests() { return [...this.requests.values()].filter(isOpen); }
  async saveDismissed(r: JoinRequest) {
    if (!this.requests.get(r.id)?.rejected) throw new Conflict('changed');
    this.requests.set(r.id, r);
  }
  async nudge(r: JoinRequest, previous: string | undefined, ds: Delivery[]) {
    const current = this.requests.get(r.id);
    if (!current || current.rejected || current.joined || current.nudgedAt !== previous) throw new Conflict('changed');
    this.requests.set(r.id, { ...current, nudgedAt: r.nudgedAt });
    await this.deliver(ds);
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
  async planPics(planId: string) { return this.pics.filter((p) => p.planId === planId); }
  async putPlanPic(p: PlanPic) { this.pics.push(p); }
  async deletePlanPic(planId: string, picId: string) { this.pics = this.pics.filter((p) => !(p.planId === planId && p.id === picId)); }
  walls = new Map<string, { wall: Wall; version: number }>();
  async getWall(wallId: string) {
    const w = this.walls.get(wallId);
    return w ? structuredClone(w) : undefined;
  }
  async allWalls() { return [...this.walls.values()].map((w) => structuredClone(w.wall)); }
  async saveWall(wall: Wall, previous: number | null) {
    const current = this.walls.get(wall.id);
    if (previous === null ? current : current?.version !== previous) throw new Conflict('changed');
    this.walls.set(wall.id, { wall: structuredClone(wall), version: (previous ?? 0) + 1 });
  }
  emails = new Map<string, string>();
  async getEmails(ids: Iterable<string>) {
    return Object.fromEntries([...new Set(ids)].flatMap((id) => (this.emails.has(id) ? [[id, this.emails.get(id)!]] : [])));
  }
  async putEmail(climberId: string, email: string) { this.emails.set(climberId, email); }
}
