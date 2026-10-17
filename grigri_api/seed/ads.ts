// Sample ads for RC and local (never prod): a made-up advertiser account,
// "Climbing Siurana", with a few approved ads for the school's courses,
// camps and guided days (from https://www.climbingsiurana.com/en/), so
// the deck shows ads between plans. Each ad's photo is the school's own,
// copied into the photos bucket by the seed (seed.ts).
import type { Ad } from '../src/domain/ads.js';
import { climber } from './data.js';

export const SEED_ADVERTISER = 'seed-climbing-siurana';

export interface SeedAd {
  ad: Ad;
  /** Where the seed copies the ad's photo from (the ad's media key is where it goes). */
  photoSource?: string;
}

const SITE = 'https://www.climbingsiurana.com';
const UPLOADS = `${SITE}/wp-content/uploads`;

export const seedAdvertiser = climber({
  id: SEED_ADVERTISER,
  name: 'Climbing Siurana',
  bio: 'Courses, camps and guided days in Siurana, Margalef and Montserrat.',
  levels: {},
});

export function seedAds(now: Date): SeedAd[] {
  const at = now.toISOString();
  const ad = (id: string, text: string, path: string, photo: string, ext: 'jpg' | 'webp'): SeedAd => ({
    ad: {
      id: `seed-ad-${id}`,
      ownerId: SEED_ADVERTISER,
      text,
      link: `${SITE}/en/portfolio/${path}/`,
      media: { kind: 'image', key: `ads/${SEED_ADVERTISER}/${id}.${ext}` },
      status: 'approved',
      createdAt: at,
      reviewedAt: at,
    },
    photoSource: `${UPLOADS}/${photo}`,
  });
  return [
    ad('climbing-day', 'A guided climbing day in Siurana: six hours in the sun with local, certified guides. From 65€.',
      'climbing-day-in-siurana', '2020/01/IMG_0981-3.jpg', 'jpg'),
    ad('gym-to-rock', 'From the gym to the rock: five days in Siurana to learn to climb outside, safely. From 450€.',
      'from-the-gym-to-the-rock', '2017/03/PB092225.jpg', 'jpg'),
    ad('margalef-camp', 'Sport climbing camp in Margalef, with coaching to push your grade. From 490€.',
      'sportclimbing-coaching-climbingcamp-margalef', '2023/09/IMG_1400-1024x683.webp', 'webp'),
    ad('via-ferrata', 'Via ferrata at La Morera de Montsant, with a guide and views over the Priorat. From 45€.',
      'via-ferrata-la-morera-de-montsant', '2020/09/IMG_20201017_122558-2-scaled-e1602964572864.jpg', 'jpg'),
  ];
}
