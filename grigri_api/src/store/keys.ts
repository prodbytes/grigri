// The single table's keys (see grigri_api/README.md, "Data model"). Every
// item has pk and sk; three sparse global secondary indexes:
//   gsi1: plans by start (PLANS), open requests (OPENREQ, the admin's),
//         every profile (CLIMBERS, the match scores' run), and ads by
//         status (ADS#<status>)
//   gsi2: a climber's own requests (ASKED#<climberId>) and ads
//         (ADSBY#<ownerId>)
//   gsi3 (keys only): an account's sessions (SESSIONS#<subject>)

export const key = {
  subject: (subject: string) => ({ pk: `SUB#${subject}`, sk: 'SUB' }),
  session: (sessionId: string) => ({ pk: `SESSION#${sessionId}`, sk: 'SESSION' }),
  climber: (climberId: string) => ({ pk: `CLIMBER#${climberId}`, sk: 'PROFILE' }),
  plan: (planId: string) => ({ pk: `PLAN#${planId}`, sk: 'PLAN' }),
  member: (climberId: string, planId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `MEMBER#${planId}` }),
  pass: (climberId: string, planId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `PASS#${planId}` }),
  notice: (climberId: string, noticeId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `NOTICE#${noticeId}` }),
  request: (planId: string, climberId: string) => ({ pk: `PLAN#${planId}`, sk: `REQ#${climberId}` }),
  message: (planId: string, time: string, messageId: string) => ({ pk: `PLAN#${planId}`, sk: `MSG#${time}#${messageId}` }),
  /** A photo in the plan's "Your Pics". */
  pic: (planId: string, picId: string) => ({ pk: `PLAN#${planId}`, sk: `PIC#${picId}` }),
  /** A wall of the route finder, its views and routes in one item. */
  wall: (wallId: string) => ({ pk: `WALL#${wallId}`, sk: 'WALL' }),
  /**
   * A climber's verified email, private (never returned): how Grigri asks
   * rbacr, whose roles are by email, about someone else (an ad's owner).
   */
  email: (climberId: string) => ({ pk: `CLIMBER#${climberId}`, sk: 'EMAIL' }),
  /** A climber's Premium subscription, as last read from Stripe or signed by Apple (src/premium.ts). */
  premium: (climberId: string) => ({ pk: `CLIMBER#${climberId}`, sk: 'PREMIUM' }),
  /** Whose an App Store subscription is, by its original transaction id (src/apple.ts): one subscription, one climber. */
  apple: (originalTransactionId: string) => ({ pk: `APPLE#${originalTransactionId}`, sk: 'APPLE' }),
  /** An ad (src/domain/ads.ts). */
  ad: (adId: string) => ({ pk: `AD#${adId}`, sk: 'AD' }),
  /** How often the deck shows ads (the admins' setting). */
  adSettings: () => ({ pk: 'META#ADS', sk: 'META' }),
  /** When the demo showcase was last written (seed/seed.ts). */
  showcase: () => ({ pk: 'META#SHOWCASE', sk: 'META' }),
};

export const prefix = {
  climber: (climberId: string) => `CLIMBER#${climberId}`,
  plan: (planId: string) => `PLAN#${planId}`,
  member: 'MEMBER#',
  pass: 'PASS#',
  notice: 'NOTICE#',
  request: 'REQ#',
  message: 'MSG#',
  pic: 'PIC#',
};

export const index = {
  byStart: { name: 'gsi1', pk: 'PLANS' },
  openRequests: { name: 'gsi1', pk: 'OPENREQ' },
  climbers: { name: 'gsi1', pk: 'CLIMBERS' },
  walls: { name: 'gsi1', pk: 'WALLS' },
  adsByStatus: { name: 'gsi1', pk: (status: string) => `ADS#${status}` },
  asked: { name: 'gsi2', pk: (climberId: string) => `ASKED#${climberId}` },
  adsBy: { name: 'gsi2', pk: (ownerId: string) => `ADSBY#${ownerId}` },
  sessions: { name: 'gsi3', pk: (subject: string) => `SESSIONS#${subject}` },
};
