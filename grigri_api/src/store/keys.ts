// The single table's keys (see grigri_api/README.md, "Data model"). Every
// item has pk and sk; three sparse global secondary indexes:
//   gsi1: plans by start (PLANS), open requests (OPENREQ, the admin's),
//         every profile (CLIMBERS, the match scores' run), ads by
//         status (ADS#<status>), open reports (REPORTS#open) and team
//         chats by their last message (TEAMCHATS, the admins' list)
//   gsi2: a climber's own requests (ASKED#<climberId>) and ads
//         (ADSBY#<ownerId>)
//   gsi3 (keys only): an account's sessions (SESSIONS#<subject>)

export const key = {
  subject: (subject: string) => ({ pk: `SUB#${subject}`, sk: 'SUB' }),
  /**
   * An Apple account's refresh token (src/apple.ts), private (never
   * returned or logged): to revoke it when the account is deleted.
   */
  appleToken: (subject: string) => ({ pk: `SUB#${subject}`, sk: 'APPLE' }),
  session: (sessionId: string) => ({ pk: `SESSION#${sessionId}`, sk: 'SESSION' }),
  climber: (climberId: string) => ({ pk: `CLIMBER#${climberId}`, sk: 'PROFILE' }),
  plan: (planId: string) => ({ pk: `PLAN#${planId}`, sk: 'PLAN' }),
  member: (climberId: string, planId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `MEMBER#${planId}` }),
  pass: (climberId: string, planId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `PASS#${planId}` }),
  /** An ad I skipped on the deck: it never shows to me again. */
  adSkip: (climberId: string, adId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `ADSKIP#${adId}` }),
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
  /** A report of something objectionable (src/domain/moderation.ts). */
  report: (reportId: string) => ({ pk: `REPORT#${reportId}`, sk: 'REPORT' }),
  /** I blocked them (specs/moderation.md#blocking-someone). */
  block: (blockerId: string, blockedId: string) => ({ pk: `CLIMBER#${blockerId}`, sk: `BLOCK#${blockedId}` }),
  /** Its mirror on the blocked one's side, never returned: so their deck and joins see it in the same query. */
  blockedBy: (blockedId: string, blockerId: string) => ({ pk: `CLIMBER#${blockedId}`, sk: `BLOCKEDBY#${blockerId}` }),
  /** A message in a climber's Grigri team chat (specs/team-chat.md). */
  teamMessage: (climberId: string, time: string, messageId: string) => ({ pk: `TEAM#${climberId}`, sk: `MSG#${time}#${messageId}` }),
  /** A team chat's last message, for the admins' list (gsi1 TEAMCHATS). */
  teamChat: (climberId: string) => ({ pk: `TEAM#${climberId}`, sk: 'CHAT' }),
  /** The climbers known to be admins, to tell them of new reports. */
  admins: () => ({ pk: 'META#ADMINS', sk: 'META' }),
  /** How often the deck shows ads (the admins' setting). */
  adSettings: () => ({ pk: 'META#ADS', sk: 'META' }),
  /** When the demo showcase was last written (seed/seed.ts). */
  showcase: () => ({ pk: 'META#SHOWCASE', sk: 'META' }),
  /**
   * An entry in the change log (src/deck-cache.ts): a plan, an ad, the
   * ads' setting or a profile changed. `<time>` is the writer's ISO time.
   */
  change: (time: string, kind: string, id: string, nonce: string) => ({ pk: 'CHANGES', sk: `${time}#${kind}#${id}#${nonce}` }),
};

export const prefix = {
  changes: 'CHANGES',
  climber: (climberId: string) => `CLIMBER#${climberId}`,
  plan: (planId: string) => `PLAN#${planId}`,
  team: (climberId: string) => `TEAM#${climberId}`,
  member: 'MEMBER#',
  pass: 'PASS#',
  adSkip: 'ADSKIP#',
  notice: 'NOTICE#',
  request: 'REQ#',
  message: 'MSG#',
  pic: 'PIC#',
  /** Both BLOCK# and BLOCKEDBY#: a climber's blocks either way, in one query. */
  blocks: 'BLOCK',
  block: 'BLOCK#',
  blockedBy: 'BLOCKEDBY#',
};

export const index = {
  byStart: { name: 'gsi1', pk: 'PLANS' },
  openRequests: { name: 'gsi1', pk: 'OPENREQ' },
  climbers: { name: 'gsi1', pk: 'CLIMBERS' },
  walls: { name: 'gsi1', pk: 'WALLS' },
  adsByStatus: { name: 'gsi1', pk: (status: string) => `ADS#${status}` },
  openReports: { name: 'gsi1', pk: 'REPORTS#open' },
  teamChats: { name: 'gsi1', pk: 'TEAMCHATS' },
  asked: { name: 'gsi2', pk: (climberId: string) => `ASKED#${climberId}` },
  adsBy: { name: 'gsi2', pk: (ownerId: string) => `ADSBY#${ownerId}` },
  sessions: { name: 'gsi3', pk: (subject: string) => `SESSIONS#${subject}` },
};
