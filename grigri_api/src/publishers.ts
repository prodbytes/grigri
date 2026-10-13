// The two ways hints leave the API (realtime.ts): IoT Core's data plane in
// AWS (iot-data:Publish over HTTPS, one call per message, QoS 0), and,
// locally, a minimal MQTT 3.1.1 client over WebSocket to Floci's broker,
// because Floci's HTTP Publish doesn't reach MQTT subscribers
// (specs/dev-environment.md, "Live updates").
import { IoTDataPlaneClient, PublishCommand } from '@aws-sdk/client-iot-data-plane';
import { randomBytes } from 'node:crypto';
import type { Outgoing, Publisher } from './realtime.js';

/** AWS: the account's IoT data endpoint (host), signed with the function's role. */
export function iotDataPublisher(endpoint: string): Publisher {
  const client = new IoTDataPlaneClient({ endpoint: `https://${endpoint}` });
  return {
    async publish(messages) {
      const results = await Promise.allSettled(
        messages.map((m) => client.send(new PublishCommand({ topic: m.topic, qos: 0, payload: Buffer.from(m.payload) }))),
      );
      const failed = results.filter((r) => r.status === 'rejected');
      if (failed.length > 0) throw new Error(`${failed.length} of ${messages.length} failed: ${String(failed[0]!.reason)}`);
    },
  };
}

// --- MQTT 3.1.1 over WebSocket (local only) ------------------------------

function remainingLength(n: number): number[] {
  const out: number[] = [];
  do {
    let byte = n % 128;
    n = Math.floor(n / 128);
    if (n > 0) byte |= 0x80;
    out.push(byte);
  } while (n > 0);
  return out;
}

function utf8(s: string): Buffer {
  const bytes = Buffer.from(s, 'utf8');
  const len = Buffer.alloc(2);
  len.writeUInt16BE(bytes.length);
  return Buffer.concat([len, bytes]);
}

function packet(type: number, body: Buffer): Buffer {
  return Buffer.concat([Buffer.from([type, ...remainingLength(body.length)]), body]);
}

/** CONNECT: clean session, 30 s keep-alive, no credentials. */
export function connectPacket(clientId: string): Buffer {
  const header = Buffer.concat([utf8('MQTT'), Buffer.from([0x04, 0x02, 0x00, 0x1e])]);
  return packet(0x10, Buffer.concat([header, utf8(clientId)]));
}

/** PUBLISH at QoS 0 (no packet id). */
export function publishPacket(topic: string, payload: string): Buffer {
  return packet(0x30, Buffer.concat([utf8(topic), Buffer.from(payload, 'utf8')]));
}

export const DISCONNECT = Buffer.from([0xe0, 0x00]);

/**
 * Local: one short MQTT session per batch (connect, publish each, disconnect)
 * to `url` (ws://<floci>/mqtt). Uses Node 22's built-in WebSocket.
 */
export function mqttWebSocketPublisher(url: string): Publisher {
  return {
    publish(messages: Outgoing[]) {
      return new Promise<void>((resolve, reject) => {
        const ws = new WebSocket(url, ['mqtt']);
        ws.binaryType = 'arraybuffer';
        let done = false;
        const finish = (error?: Error) => {
          if (done) return;
          done = true;
          try {
            ws.close();
          } catch {
            // Already closed.
          }
          if (error) reject(error);
          else resolve();
        };
        ws.addEventListener('open', () => ws.send(connectPacket(`grigri-api-${randomBytes(6).toString('hex')}`)));
        ws.addEventListener('message', (event) => {
          const data = new Uint8Array(event.data as ArrayBuffer);
          // CONNACK: 0x20, length 2, flags, return code.
          if (data[0] !== 0x20) return;
          if (data[3] !== 0) return finish(new Error(`broker refused the connection (${data[3]})`));
          for (const m of messages) ws.send(publishPacket(m.topic, m.payload));
          ws.send(DISCONNECT);
          finish();
        });
        ws.addEventListener('error', () => finish(new Error('broker unreachable')));
        ws.addEventListener('close', () => finish(new Error('broker closed the connection')));
      });
    },
  };
}
