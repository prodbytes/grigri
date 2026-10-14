// The demo showcase, on every stage (production too): a few fictional
// climbers, each organizing a plan at a well-known crag, so the app has
// something to show while there are few real plans. Their names nod to
// late climbing legends without being them: nobody real is portrayed,
// and their bios are made up. All marked demo (the app says so); joining
// one matches at once (specs/matching.md). Ids start with `seed-`; dates
// are relative to `now`, and the API refreshes them (seed/seed.ts).
import type { Climber, Plan } from '../src/domain/model.js';
import { boulders, climber, routes } from './data.js';

export interface ShowcaseData {
  climbers: Climber[];
  plans: Plan[];
}

export function showcaseData(now: Date): ShowcaseData {
  const day = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  /** `days` ahead at `hour` UTC, for `hours`. */
  const at = (days: number, hour: number, hours: number) => ({
    start: new Date(day + days * 86_400_000 + hour * 3_600_000).toISOString(),
    end: new Date(day + days * 86_400_000 + (hour + hours) * 3_600_000).toISOString(),
  });

  const climbers: Climber[] = [
    climber({
      id: 'seed-wolf',
      name: 'Wolf Gullick',
      age: 31,
      bio: 'Pockets, small edges and early starts. A fingerboard in the garage.',
      levels: { sport: routes('7a', '8a'), gym: routes('7a', '8a') },
      gear: ['rope', 'quickdraws', 'car'],
    }),
    climber({
      id: 'seed-patrice',
      name: 'Patrice Edlin',
      age: 29,
      bio: 'Grey limestone and flowing moves. Rest days by the river.',
      levels: { sport: routes('6c', '7c') },
      gear: ['rope', 'quickdraws'],
    }),
    climber({
      id: 'seed-kurt',
      name: 'Kurt Alberts',
      age: 35,
      bio: 'A red dot at the base means I am going for it.',
      levels: { sport: routes('6b', '7b'), trad: routes('6a', '6c') },
      gear: ['rope', 'quickdraws', 'rack'],
    }),
    climber({
      id: 'seed-roy',
      name: 'Roy Robbin',
      age: 40,
      bio: 'Clean cracks, long days, no hammer. Spring in the big valleys.',
      levels: { trad: routes('5c', '6c') },
      gear: ['rope', 'rack', 'car'],
    }),
    climber({
      id: 'seed-uli',
      name: 'Uli Stack',
      age: 33,
      bio: 'Fast and light: jog to the crag, then multipitch till sunset.',
      levels: { trad: routes('6a', '6c'), sport: routes('6b', '7a') },
      gear: ['rope', 'rack'],
    }),
    climber({
      id: 'seed-dean',
      name: 'Dean Potts',
      age: 37,
      bio: 'Sandstone, highballs and a very patient dog.',
      levels: { bouldering: boulders('V3', 'V7') },
      gear: ['crashPad', 'car'],
    }),
  ];

  const plan = (p: Omit<Plan, 'notes' | 'start' | 'end'> & { notes?: string; when: { start: string; end: string } }): Plan => {
    const { when, ...rest } = p;
    return { notes: '', ...rest, ...when };
  };
  const plans: Plan[] = [
    plan({
      id: 'seed-frankenjura-pockets',
      organizerId: 'seed-wolf',
      discipline: 'sport',
      place: 'Waldkopf',
      area: 'Frankenjura, Germany',
      lat: 49.7,
      lon: 11.33,
      when: at(2, 8, 9),
      grades: routes('6c', '7c'),
      memberIds: ['seed-wolf'],
      notes: 'Short approach, steep pockets. Lunch at the beer garden after.',
    }),
    plan({
      id: 'seed-buoux-limestone',
      organizerId: 'seed-patrice',
      discipline: 'sport',
      place: 'Buoux',
      area: 'Provence, France',
      lat: 43.83,
      lon: 5.37,
      when: at(3, 8, 8),
      grades: routes('6b', '7b'),
      memberIds: ['seed-patrice'],
      notes: 'Early start to beat the sun on the south faces.',
    }),
    plan({
      id: 'seed-kalymnos-grotto',
      organizerId: 'seed-kurt',
      discipline: 'sport',
      place: 'Grande Grotta',
      area: 'Kalymnos, Greece',
      lat: 36.98,
      lon: 26.96,
      when: at(4, 7, 8),
      grades: routes('6a', '7b'),
      memberIds: ['seed-kurt', 'seed-uli'],
      notes: 'Tufas all day. Scooters to the crag; one seat free.',
    }),
    plan({
      id: 'seed-yosemite-cracks',
      organizerId: 'seed-roy',
      discipline: 'trad',
      place: 'Swan Slab',
      area: 'Yosemite Valley, USA',
      lat: 37.742,
      lon: -119.6,
      when: at(5, 15, 6),
      grades: routes('5b', '6b'),
      memberIds: ['seed-roy'],
      notes: 'Crack technique session, happy to share gear and tips.',
    }),
    plan({
      id: 'seed-rio-multipitch',
      organizerId: 'seed-uli',
      discipline: 'trad',
      place: 'Pão de Açúcar',
      area: 'Rio de Janeiro, Brazil',
      lat: -22.949,
      lon: -43.156,
      when: at(6, 11, 7),
      grades: routes('5c', '6b'),
      memberIds: ['seed-uli'],
      notes: 'Classic multipitch to the top, cable car down at sunset.',
    }),
    plan({
      id: 'seed-font-highballs',
      organizerId: 'seed-dean',
      discipline: 'bouldering',
      place: 'Bas Cuvier',
      area: 'Fontainebleau, France',
      lat: 48.447,
      lon: 2.637,
      when: at(2, 9, 7),
      grades: boulders('V2', 'V6'),
      memberIds: ['seed-dean', 'seed-wolf'],
      notes: 'Bring pads and a towel for the sandy feet.',
    }),
  ];
  return { climbers, plans };
}
