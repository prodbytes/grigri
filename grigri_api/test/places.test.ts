import { describe, expect, it } from 'vitest';
import { nominatim } from '../src/places.js';

describe('nominatim', () => {
  it('asks with its user agent and language, and answers short names with boxes', async () => {
    let asked: { url: string; headers: Record<string, string> } | undefined;
    const fetcher = (async (url: URL, init: RequestInit) => {
      asked = { url: url.toString(), headers: init.headers as Record<string, string> };
      return Response.json([
        { name: 'Siurana', addresstype: 'hamlet', display_name: 'Siurana, Cornudella de Montsant, Priorat, Tarragona, Catalunya, 43360, España', boundingbox: ['41.2383112', '41.2783112', '0.9125259', '0.9525259'], address: { country: 'España' } },
        { name: 'España', addresstype: 'country', display_name: 'España', boundingbox: ['27.43', '43.99', '-18.39', '4.59'], address: { country: 'España' } },
        { name: 'Broken', boundingbox: ['x'] },
      ]);
    }) as unknown as typeof fetch;
    const places = await nominatim(fetcher)('Siurana', 'es');
    expect(asked!.url).toContain('q=Siurana');
    expect(asked!.headers['user-agent']).toMatch(/^Grigri\//);
    expect(asked!.headers['accept-language']).toBe('es');
    expect(places).toEqual([
      { name: 'Siurana, España', label: 'Siurana, Cornudella de Montsant, Priorat, Tarragona, Catalunya, 43360, España', south: 41.2383112, west: 0.9125259, north: 41.2783112, east: 0.9525259 },
      { name: 'España', label: 'España', south: 27.43, west: -18.39, north: 43.99, east: 4.59 },
    ]);
  });

  it('throws when the search fails', async () => {
    const fetcher = (async () => new Response('busy', { status: 429 })) as unknown as typeof fetch;
    await expect(nominatim(fetcher)('Siurana', 'en')).rejects.toThrow(/429/);
  });
});
