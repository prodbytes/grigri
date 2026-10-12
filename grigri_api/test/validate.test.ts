import { describe, expect, it } from 'vitest';
import { messageText, planInput, profileInput } from '../src/domain/validate.js';

const owner = 'a'.repeat(32);
const now = new Date('2030-05-01T10:00:00.000Z');

describe('profileInput', () => {
  const valid = {
    name: '  Alex Example ',
    age: 30,
    bio: 'Hi',
    photo: `${owner}/profile/abcdefgh12345678.jpg`,
    levels: { sport: { scale: 'routes', min: 6, max: 10 }, bouldering: { scale: 'boulders', min: 0, max: 14 } },
    gear: ['rope', 'rope', 'car'],
    gearPhotos: [`${owner}/gear/abcdefgh12345678.png`],
    id: 'ignored',
    email: 'ignored@example.com',
  };

  it('accepts a valid profile, trimmed and de-duplicated, ignoring unknown fields', () => {
    const out = profileInput(valid, [owner]);
    expect(out).toEqual({
      name: 'Alex Example',
      age: 30,
      bio: 'Hi',
      photo: valid.photo,
      levels: valid.levels,
      gear: ['rope', 'car'],
      gearPhotos: valid.gearPhotos,
      areas: [],
    });
    expect(out).not.toHaveProperty('id');
    expect(out).not.toHaveProperty('email');
  });

  it('reads the old scale names as the new ones', () => {
    const out = profileInput({ ...valid, levels: { sport: { scale: 'french', min: 1, max: 2 }, bouldering: { scale: 'vScale', min: 3, max: 4 } } }, [owner]);
    expect(out.levels).toEqual({ sport: { scale: 'routes', min: 1, max: 2 }, bouldering: { scale: 'boulders', min: 3, max: 4 } });
  });

  it('takes a location and up to 5 areas, rounded to ~1 km', () => {
    const out = profileInput(
      { ...valid, location: { name: ' Home town ', lat: 41.38879, lon: 2.15899 }, areas: [{ name: 'Crag', lat: -33.123, lon: 151.987 }] },
      [owner],
    );
    expect(out.location).toEqual({ name: 'Home town', lat: 41.39, lon: 2.16 });
    expect(out.areas).toEqual([{ name: 'Crag', lat: -33.12, lon: 151.99 }]);
  });

  it('age is optional', () => {
    expect(profileInput({ ...valid, age: null }, [owner])).not.toHaveProperty('age');
  });

  it.each([
    [{ name: '' }, /name is required/],
    [{ name: 'x'.repeat(61) }, /name is longer/],
    [{ age: 15 }, /age/],
    [{ age: 100 }, /age/],
    [{ age: 30.5 }, /age/],
    [{ bio: 'x'.repeat(1001) }, /bio/],
    [{ levels: { climbing: { scale: 'routes', min: 0, max: 1 } } }, /levels key/],
    [{ levels: { sport: { scale: 'boulders', min: 0, max: 1 } } }, /routes/],
    [{ levels: { bouldering: { scale: 'routes', min: 0, max: 1 } } }, /boulders/],
    [{ levels: { bouldering: { scale: 'french', min: 0, max: 1 } } }, /boulders/],
    [{ levels: { sport: { scale: 'routes', min: 5, max: 25 } } }, /max/],
    [{ levels: { sport: { scale: 'routes', min: 9, max: 5 } } }, /above/],
    [{ gear: ['rope', 'jetpack'] }, /gear/],
    [{ location: { name: 'X', lat: 91, lon: 0 } }, /location.lat/],
    [{ location: { name: 'X', lat: 0, lon: '2' } }, /location.lon/],
    [{ location: { name: '', lat: 0, lon: 0 } }, /location.name is required/],
    [{ areas: { name: 'X', lat: 0, lon: 0 } }, /areas must be a list/],
    [{ areas: Array(6).fill({ name: 'X', lat: 0, lon: 0 }) }, /at most 5 areas/],
    [{ areas: [{ name: 'X', lat: 0, lon: -181 }] }, /areas\[0\].lon/],
    [{ gearPhotos: Array(7).fill(`${owner}/gear/abcdefgh12345678.png`) }, /at most 6/],
    [{ photo: `${'b'.repeat(32)}/profile/abcdefgh12345678.jpg` }, /isn't one of your photos/],
    [{ photo: `${owner}/profile/../../etc.jpg` }, /isn't a photo key/],
    [{ photo: 'https://evil.example.com/x.jpg' }, /isn't a photo key/],
    [{ name: 'bad\u0000name' }, /control characters/],
  ])('refuses %j', (patch, error) => {
    expect(() => profileInput({ ...valid, ...patch }, [owner])).toThrow(error);
  });

  it('refuses non-objects', () => {
    expect(() => profileInput([], [owner])).toThrow(/JSON object/);
    expect(() => profileInput(null, [owner])).toThrow(/JSON object/);
  });
});

describe('planInput', () => {
  const valid = {
    discipline: 'bouldering',
    place: 'Forest',
    area: 'Somewhere, Country',
    sectorId: 'osm:n123456',
    start: '2030-05-02T08:00:00Z',
    end: '2030-05-02T12:00:00Z',
    grades: { scale: 'boulders', min: 2, max: 5 },
    notes: '',
    memberIds: ['ignored'],
    organizerId: 'ignored',
    title: 'ignored',
    spots: 3,
  };

  it('accepts a valid plan, normalizes dates to UTC and ignores unknown fields', () => {
    expect(planInput({ ...valid, start: '2030-05-02T10:00:00+02:00', grades: { scale: 'vScale', min: 2, max: 5 } }, now)).toEqual({
      discipline: 'bouldering',
      place: 'Forest',
      area: 'Somewhere, Country',
      sectorId: 'osm:n123456',
      start: '2030-05-02T08:00:00.000Z',
      end: '2030-05-02T12:00:00.000Z',
      grades: { scale: 'boulders', min: 2, max: 5 },
      notes: '',
    });
  });

  it('sectorId is optional', () => {
    expect(planInput({ ...valid, sectorId: undefined }, now)).not.toHaveProperty('sectorId');
    const point = planInput({ ...valid, lat: 41.257712, lon: 0.931849 }, now);
    expect([point.lat, point.lon]).toEqual([41.2577, 0.9318]);
    expect(planInput(valid, now)).not.toHaveProperty('lat');
    expect(() => planInput({ ...valid, lat: 41 }, now)).toThrow(/lon/);
    expect(() => planInput({ ...valid, lat: 'x', lon: 1 }, now)).toThrow(/lat/);
    expect(planInput({ ...valid, sectorId: '' }, now)).not.toHaveProperty('sectorId');
  });

  it.each([
    [{ place: ' ' }, /place is required/],
    [{ place: 'x'.repeat(81) }, /place/],
    [{ area: 'x'.repeat(121) }, /area/],
    [{ sectorId: 'x'.repeat(65) }, /sectorId/],
    [{ discipline: 'ice' }, /discipline/],
    [{ start: '2030-04-30T08:00:00Z' }, /future/],
    [{ start: '2030-05-02' }, /ISO 8601/],
    [{ start: '2032-05-02T08:00:00Z', end: '2032-05-02T09:00:00Z' }, /a year/],
    [{ end: undefined }, /end must be/],
    [{ end: '2030-05-02T08:00:00Z' }, /after start/],
    [{ end: '2030-05-03T08:00:01Z' }, /24 hours/],
    [{ notes: 'x'.repeat(1001) }, /notes/],
    [{ grades: { scale: 'routes', min: 0, max: 1 } }, /boulders/],
  ])('refuses %j', (patch, error) => {
    expect(() => planInput({ ...valid, ...patch }, now)).toThrow(error);
  });
});

describe('messageText', () => {
  it('is 1 to 2000 characters, trimmed', () => {
    expect(messageText({ text: ' hi ' })).toBe('hi');
    expect(() => messageText({ text: '   ' })).toThrow(/required/);
    expect(() => messageText({ text: 'x'.repeat(2001) })).toThrow(/2000/);
    expect(() => messageText({ text: 5 })).toThrow(/string/);
  });
});
