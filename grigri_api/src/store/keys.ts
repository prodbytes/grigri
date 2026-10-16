// The single table's keys (see grigri_api/README.md, "Data model"). Every
// item has pk and sk; three sparse global secondary indexes:
//   gsi1: plans by start (PLANS), open requests (OPENREQ, the admin's),
//         and every profile (CLIMBERS, the match scores' run)
//   gsi2: a climber's own requests (ASKED#<climberId>)
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
  asked: { name: 'gsi2', pk: (climberId: string) => `ASKED#${climberId}` },
  sessions: { name: 'gsi3', pk: (subject: string) => `SESSIONS#${subject}` },
};
