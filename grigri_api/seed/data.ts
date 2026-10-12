// The made-up test data for RC and local (never prod): climbers who are
// nobody real, their plans and a few open requests between them, so the
// deck, Requests and the admin view have something. Ported from the app's
// former on-device demo (lib/data/seed.dart), without its answer
// "policies": nobody answers automatically; real testers or an admin do.
// Ids start with `seed-`; dates are relative to `now`, so plans are always
// upcoming.
import { type Climber, type GradeRange, type JoinRequest, type Message, type Plan, SCALES, requestId } from '../src/domain/model.js';

export interface SeedData {
  climbers: Climber[];
  plans: Plan[];
  requests: JoinRequest[];
  messages: Message[];
}

/** A routes range, by French grades. */
function routes(min: string, max: string): GradeRange {
  const grades: readonly string[] = SCALES.routes;
  return { scale: 'routes', min: grades.indexOf(min), max: grades.indexOf(max) };
}

/** A boulders range, by V grades (the same indices as Font). */
const V = ['VB', 'V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8', 'V9', 'V10', 'V11', 'V12', 'V13'];
function boulders(min: string, max: string): GradeRange {
  return { scale: 'boulders', min: V.indexOf(min), max: V.indexOf(max) };
}

const climber = (c: Omit<Climber, 'gearPhotos' | 'gear'> & { gear?: Climber['gear'] }): Climber => ({
  gear: [],
  gearPhotos: [],
  ...c,
});

export function seedData(now: Date): SeedData {
  const day = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  /** The next weekday (0 = Sunday … 6 = Saturday) at least `after` days ahead, at `hour` UTC. */
  const next = (weekday: number, hour: number, after = 1): string => {
    let offset = after;
    while (new Date(day + offset * 86_400_000).getUTCDay() !== weekday) offset++;
    return new Date(day + offset * 86_400_000 + hour * 3_600_000).toISOString();
  };
  const ago = (hours: number): string => new Date(now.getTime() - hours * 3_600_000).toISOString();

  const climbers: Climber[] = [
    climber({
      id: 'seed-sam',
      name: 'Sam Okoro',
      age: 30,
      bio: 'Weekend sport climber, weeknight boulderer. Always up for a road trip.',
      levels: { sport: routes('6a', '6c+'), trad: routes('5c', '6a'), bouldering: boulders('V2', 'V5'), gym: routes('6a', '7a') },
      gear: ['rope', 'quickdraws'],
    }),
    climber({
      id: 'seed-marta',
      name: 'Marta Soler',
      age: 29,
      bio: 'Limestone lover. I like long days, early starts and a good bocata.',
      levels: { sport: routes('6b', '7a+') },
      gear: ['rope', 'quickdraws', 'car'],
    }),
    climber({
      id: 'seed-tomas',
      name: 'Tomás Ibarra',
      age: 34,
      bio: 'Multipitch and conglomerate. Happy to lead the trad pitches.',
      levels: { trad: routes('5c', '6c'), sport: routes('6a', '6c') },
      gear: ['rope', 'rack', 'car'],
    }),
    climber({
      id: 'seed-ravi',
      name: 'Ravi Nair',
      age: 38,
      bio: 'Slow and steady. Belays with snacks.',
      levels: { trad: routes('5b', '6b') },
      gear: ['rack'],
    }),
    climber({
      id: 'seed-kofi',
      name: 'Kofi Mensah',
      age: 31,
      bio: 'Projecting season. Looking for patient belayers.',
      levels: { sport: routes('7a', '7c+') },
      gear: ['rope', 'quickdraws', 'car'],
    }),
    climber({
      id: 'seed-lena',
      name: 'Lena Vogel',
      age: 26,
      bio: 'Boulder gym rat on weeknights, Fontainebleau dreamer.',
      levels: { bouldering: boulders('V3', 'V6'), gym: routes('6b', '7a') },
      gear: ['crashPad'],
    }),
    climber({
      id: 'seed-noa',
      name: 'Noa Levi',
      age: 24,
      bio: 'New to outdoor bouldering, keen to learn.',
      levels: { bouldering: boulders('V1', 'V4') },
    }),
    climber({
      id: 'seed-ines',
      name: 'Inés Prado',
      age: 27,
      bio: 'Coming back after a finger injury, so moderate routes please.',
      levels: { sport: routes('5c', '6b'), gym: routes('5c', '6b+') },
      gear: ['quickdraws'],
    }),
    climber({
      id: 'seed-bruno',
      name: 'Bruno Costa',
      bio: 'After-work leads and weekend sport trips.',
      levels: { sport: routes('6a+', '6c+'), gym: routes('6a+', '7a') },
      gear: ['rope', 'car'],
    }),
  ];

  const plan = (p: Omit<Plan, 'area' | 'notes'> & { area?: string; notes?: string }): Plan => ({ area: '', notes: '', ...p });
  const plans: Plan[] = [
    plan({
      id: 'seed-siurana-saturday',
      organizerId: 'seed-marta',
      discipline: 'sport',
      place: 'El Pati',
      area: 'Siurana, Spain',
      sectorId: 'demo:el-pati',
      start: next(6, 8),
      end: next(6, 17),
      grades: routes('6a', '7a'),
      memberIds: ['seed-marta'],
      notes: 'Car from Barcelona at 6:30, two seats free.',
    }),
    plan({
      id: 'seed-montserrat-multipitch',
      organizerId: 'seed-tomas',
      discipline: 'trad',
      place: 'Montserrat',
      area: 'Catalonia',
      start: next(0, 7),
      end: next(0, 15),
      grades: routes('5c', '6b'),
      memberIds: ['seed-tomas', 'seed-ravi'],
      notes: 'Two ropes of two. Approach is 1 h; bring a headlamp.',
    }),
    plan({
      id: 'seed-margalef-project',
      organizerId: 'seed-kofi',
      discipline: 'sport',
      place: 'Margalef',
      area: 'Catalonia',
      start: next(5, 9),
      end: next(5, 17),
      grades: routes('7a', '7c'),
      memberIds: ['seed-kofi'],
      notes: 'Mostly belaying and trying hard. Campsite Friday night.',
    }),
    plan({
      id: 'seed-tuesday-bouldering',
      organizerId: 'seed-lena',
      discipline: 'bouldering',
      place: 'Boulder gym',
      area: 'Barcelona',
      start: next(2, 19),
      end: next(2, 22),
      grades: boulders('V2', 'V5'),
      memberIds: ['seed-lena', 'seed-noa'],
    }),
    plan({
      id: 'seed-after-work-leads',
      organizerId: 'seed-bruno',
      discipline: 'gym',
      place: 'Climbing gym',
      area: 'Barcelona',
      start: next(3, 19),
      end: next(3, 21),
      grades: routes('6a', '6c+'),
      memberIds: ['seed-bruno'],
    }),
    // Two people want to join.
    plan({
      id: 'seed-sunday-siurana',
      organizerId: 'seed-sam',
      discipline: 'sport',
      place: 'Siurana',
      area: 'Catalonia',
      start: next(0, 9, 7),
      end: next(0, 17, 7),
      grades: routes('6a', '6c'),
      memberIds: ['seed-sam'],
      notes: 'Relaxed day of 6s. I have a rope and draws.',
    }),
    // One more wants to join; one member already said yes.
    plan({
      id: 'seed-thursday-bouldering',
      organizerId: 'seed-lena',
      discipline: 'bouldering',
      place: 'Boulder gym',
      area: 'Barcelona',
      start: next(4, 19),
      end: next(4, 22),
      grades: boulders('V2', 'V6'),
      memberIds: ['seed-lena', 'seed-sam'],
    }),
  ];

  const request = (planId: string, climberId: string, hoursAgo: number, acceptedBy: string[] = []): JoinRequest => ({
    id: requestId(planId, climberId),
    planId,
    climberId,
    acceptedBy,
    rejected: false,
    time: ago(hoursAgo),
  });
  const requests: JoinRequest[] = [
    request('seed-sunday-siurana', 'seed-ines', 20),
    request('seed-sunday-siurana', 'seed-bruno', 3),
    request('seed-thursday-bouldering', 'seed-noa', 6, ['seed-lena']),
  ];

  const name = (id: string) => climbers.find((c) => c.id === id)!.name;
  const thursday = new Date(plans.find((p) => p.id === 'seed-thursday-bouldering')!.start);
  const message = (id: string, planId: string, authorId: string | null, text: string, time: string, req?: string): Message => ({
    id: `seed-${id}`,
    planId,
    authorId,
    text,
    time,
    ...(req ? { requestId: req } : {}),
  });
  const messages: Message[] = [
    message('thu-joined', 'seed-thursday-bouldering', null, 'Sam Okoro joined the plan 🎉', ago(48)),
    message('thu-welcome', 'seed-thursday-bouldering', 'seed-lena', 'Welcome! New set on the overhang wall, so bring skin 😄', ago(47)),
    message(
      'thu-meet',
      'seed-thursday-bouldering',
      'seed-lena',
      `Meet at the entrance at ${thursday.getUTCHours()}:00 UTC? Noa asked to join too, say yes if you're in.`,
      ago(5),
    ),
    message('sun-created', 'seed-sunday-siurana', null, 'Sam Okoro created the plan. People who match will show up here.', ago(24)),
    ...requests.map((r) =>
      message(`req-${r.climberId}-${r.planId}`, r.planId, null, `${name(r.climberId)} asked to join`, r.time, r.id),
    ),
  ];

  return { climbers, plans, requests, messages };
}
