// The Grigri team chat (specs/team-chat.md): every climber has one, to
// write to Grigri itself; every admin reads them all and answers as
// "Grigri team". Its first message, thanking the climber and asking for
// feedback, is the app's own (in the climber's language): nothing is
// stored until the climber writes.

/** How many team chats an admin's list shows at most, the latest first. */
export const MAX_TEAM_CHATS = 100;

/** How much of the last message the admins' list keeps. */
export const TEAM_PREVIEW = 160;

/** The notice (one per climber, replaced each time) that a team chat has news: a badge on Chats. */
export const TEAM_NOTICE_ID = 'team';

export interface TeamMessage {
  id: string;
  /** Whose team chat it is. */
  climberId: string;
  /** Written by an admin for the Grigri team; false: by the climber. */
  fromTeam: boolean;
  text: string;
  time: string;
  /** The admin who wrote it: for the admins only, never sent to the climber. */
  adminId?: string;
}

/** A team chat in the admins' list: whose, and its last message. */
export interface TeamChat {
  climberId: string;
  lastTime: string;
  lastText: string;
  lastFromTeam: boolean;
}

/** A team message as the climber sees it: never which admin wrote it. */
export function forClimber(m: TeamMessage): TeamMessage {
  const { adminId: _adminId, ...rest } = m;
  return rest;
}
