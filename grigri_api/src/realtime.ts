// Live updates (specs/live-updates.md): after a change, the API publishes a
// tiny hint ({"kind", "planId"?}, never data) to each affected climber's
// MQTT topic, grigri/<stage>/climbers/<climberId>/hint, on AWS IoT Core
// (Floci's broker locally). The app refetches what the hint names through
// the API, where all authorization stays. Publishing is best effort: a
// failure is logged and never fails the request.

/** team: a Grigri team chat changed (specs/team-chat.md): mine, or, for admins, anyone's. */
export type HintKind = 'message' | 'request' | 'notice' | 'plan' | 'match' | 'pics' | 'team';

export interface Hint {
  kind: HintKind;
  planId?: string;
}

/** A hint for one climber. */
export interface Delivery {
  to: string;
  hint: Hint;
}

export interface Outgoing {
  topic: string;
  payload: string;
}

/** Sends MQTT messages (QoS 0): IoT Core's data plane, or Floci's broker. */
export interface Publisher {
  publish(messages: Outgoing[]): Promise<void>;
}

export interface RealtimeConfig {
  stage: string;
  /**
   * Where clients connect, host[:port]: the account's IoT Data-ATS
   * endpoint in AWS, Floci's HTTPS port locally. Empty: live updates off.
   */
  endpoint: string;
  /** The IoT custom authorizer clients name; empty locally (Floci has none). */
  authorizer: string;
}

/** What GET /api/realtime answers. */
export type RealtimeInfo =
  | { url: string; authorizer: string; topic: string; clientIdPrefix: string }
  | { url: null };

const TOPIC_ROOT = 'grigri';

/** The topic the API publishes a climber's hints on. */
export function hintTopic(stage: string, climberId: string): string {
  return `${TOPIC_ROOT}/${stage}/climbers/${climberId}/hint`;
}

/** The only filter a climber may subscribe to: their own subtree. */
export function climberFilter(stage: string, climberId: string): string {
  return `${TOPIC_ROOT}/${stage}/climbers/${climberId}/#`;
}

/** Client ids must start with this (the authorizer's policy allows only that). */
export function clientIdPrefix(climberId: string): string {
  return `${climberId}-`;
}

export class Realtime {
  constructor(
    private readonly config: RealtimeConfig,
    private readonly publisher: Publisher | null,
    /** How long a request waits for its publishes, at most. */
    private readonly timeoutMs = 1500,
  ) {}

  get enabled(): boolean {
    return this.config.endpoint !== '' && this.publisher !== null;
  }

  info(climberId: string): RealtimeInfo {
    if (!this.enabled) return { url: null };
    return {
      url: `wss://${this.config.endpoint}/mqtt`,
      authorizer: this.config.authorizer,
      topic: climberFilter(this.config.stage, climberId),
      clientIdPrefix: clientIdPrefix(climberId),
    };
  }

  /**
   * Publishes each hint once per climber (duplicates dropped). Never
   * throws, and waits at most timeoutMs: the change is already saved, and
   * the app's polling catches up on a lost hint.
   */
  async notify(deliveries: Delivery[]): Promise<void> {
    if (!this.enabled || deliveries.length === 0) return;
    const seen = new Set<string>();
    const messages: Outgoing[] = [];
    for (const { to, hint } of deliveries) {
      const payload = JSON.stringify(hint.planId ? { kind: hint.kind, planId: hint.planId } : { kind: hint.kind });
      const topic = hintTopic(this.config.stage, to);
      const key = `${topic} ${payload}`;
      if (seen.has(key)) continue;
      seen.add(key);
      messages.push({ topic, payload });
    }
    let timer: NodeJS.Timeout | undefined;
    try {
      await Promise.race([
        this.publisher!.publish(messages),
        new Promise((_, reject) => {
          timer = setTimeout(() => reject(new Error('publish timed out')), this.timeoutMs);
        }),
      ]);
    } catch (e) {
      // Counts only: no climber ids or payloads in the log.
      console.error(JSON.stringify({ level: 'warn', msg: 'hint publish failed', count: messages.length, error: String(e) }));
    } finally {
      clearTimeout(timer);
    }
  }
}

/** Hints for each climber in `to`, but not the one who made the change. */
export function hintsFor(to: Iterable<string>, hint: Hint, actorId: string): Delivery[] {
  const out: Delivery[] = [];
  for (const id of new Set(to)) if (id !== actorId) out.push({ to: id, hint });
  return out;
}
