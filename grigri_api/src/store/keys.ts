// The single table's keys (see grigri_api/README.md, "Data model"). Every
// item has pk and sk; two sparse global secondary indexes:
//   gsi1: plans by start (PLANS), and open requests (OPENREQ, the admin's)
//   gsi2: a climber's own requests (ASKED#<climberId>)

export const key = {
  subject: (subject: string) => ({ pk: `SUB#${subject}`, sk: 'SUB' }),
  climber: (climberId: string) => ({ pk: `CLIMBER#${climberId}`, sk: 'PROFILE' }),
  plan: (planId: string) => ({ pk: `PLAN#${planId}`, sk: 'PLAN' }),
  member: (climberId: string, planId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `MEMBER#${planId}` }),
  pass: (climberId: string, planId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `PASS#${planId}` }),
  notice: (climberId: string, noticeId: string) => ({ pk: `CLIMBER#${climberId}`, sk: `NOTICE#${noticeId}` }),
  request: (planId: string, climberId: string) => ({ pk: `PLAN#${planId}`, sk: `REQ#${climberId}` }),
  message: (planId: string, time: string, messageId: string) => ({ pk: `PLAN#${planId}`, sk: `MSG#${time}#${messageId}` }),
};

export const prefix = {
  climber: (climberId: string) => `CLIMBER#${climberId}`,
  plan: (planId: string) => `PLAN#${planId}`,
  member: 'MEMBER#',
  pass: 'PASS#',
  notice: 'NOTICE#',
  request: 'REQ#',
  message: 'MSG#',
};

export const index = {
  byStart: { name: 'gsi1', pk: 'PLANS' },
  openRequests: { name: 'gsi1', pk: 'OPENREQ' },
  asked: { name: 'gsi2', pk: (climberId: string) => `ASKED#${climberId}` },
};
