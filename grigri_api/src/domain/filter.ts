// The objectionable-words filter (specs/moderation.md#the-filter): text
// people post (profile name and bio, plan notes and a place typed by hand,
// chat messages, ad text) is refused with a 400 when it has a slur or an
// explicit sexual term. Whole words only, ignoring case and accents, and
// seeing through simple obfuscation: repeated letters ("fuuuck"),
// common leetspeak ("f4ck", "$lut"), and letters
// spaced or dotted out ("f u c k", "f.u.c.k"). Photos aren't machine
// filtered: reports and admins' removal cover them.
//
// Keeping the list: add a word in its plain, accent-free, lowercase
// spelling to its language below. Leave out words that are innocent in
// another of Grigri's languages (Catalan "negre" is "black", Portuguese
// "pede" is "asks", Catalan "polla" is a young hen, "bite" is English,
// French "retard" is a delay, Spanish "Kike" a name, "chink" and "spic"
// English phrases), and mild swearing: the filter is for slurs and
// explicit sexual terms.
import { badRequest } from './errors.js';

/** Objectionable words, per language (lowercase, without accents). */
export const BLOCKED_WORDS: Record<'en' | 'es' | 'de' | 'fr' | 'pt' | 'ca', readonly string[]> = {
  en: [
    'fuck', 'fucking', 'fucker', 'motherfucker', 'cunt', 'cocksucker', 'blowjob', 'handjob', 'rimjob',
    'cumshot', 'dildo', 'jizz', 'slut', 'whore', 'porn', 'porno', 'nigger', 'nigga', 'faggot', 'tranny',
    'wetback', 'gook',
  ],
  es: ['puta', 'puto', 'putas', 'maricon', 'marica', 'sudaca', 'mamada', 'chupapollas', 'pajillero', 'negrata', 'follame'],
  de: ['ficken', 'fotze', 'schlampe', 'hure', 'wichser', 'schwuchtel', 'neger', 'kanake', 'spast'],
  fr: ['salope', 'pute', 'encule', 'enculer', 'bougnoule', 'youpin', 'niquer', 'tafiole'],
  pt: ['caralho', 'buceta', 'boceta', 'punheta', 'piroca', 'xoxota', 'viado', 'fodase', 'foder'],
  ca: ['marico', 'putes'],
};

/** Leetspeak and look-alikes, read as the letters they stand for. */
const LEET: Record<string, string> = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b', '9': 'g',
  '@': 'a', '$': 's', '!': 'i', '|': 'i', '€': 'e', '+': 't',
};

/**
 * Lowercase, without accents, and (with `leet`) leetspeak read as letters;
 * anything else not a letter becomes a space.
 */
export function normalize(text: string, leet = true): string {
  const plain = text.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '').replace(/ß/g, 'ss');
  let out = '';
  for (const ch of plain) {
    const mapped = leet ? (LEET[ch] ?? ch) : ch;
    out += /\p{L}/u.test(mapped) ? mapped : ' ';
  }
  return out;
}

/**
 * One pattern for every word: each letter may repeat ("fuuuck"), a plural
 * "s" may follow, and a word must be the whole token ("class" and
 * "Scunthorpe" pass).
 */
const PATTERN = new RegExp(
  `^(?:${[...new Set(Object.values(BLOCKED_WORDS).flat())]
    .map((w) => `${[...w].map((c) => `${c}+`).join('')}s*`)
    .join('|')})$`,
  'u',
);

/** Whether text has an objectionable word. */
export function isObjectionable(text: string): boolean {
  if (!text) return false;
  // Read with leetspeak ("$lut") and without ("Schlampe!": "!" is
  // punctuation there, not an "i").
  return hasWord(normalize(text, true)) || hasWord(normalize(text, false));
}

function hasWord(normalized: string): boolean {
  const tokens = normalized.split(/\s+/).filter(Boolean);
  if (tokens.some((t) => PATTERN.test(t))) return true;
  // Spelled out letter by letter ("f u c k", "f.u.c.k"): runs of single
  // letters, read together.
  let run = '';
  for (const t of [...tokens, '']) {
    if ([...t].length === 1) {
      run += t;
      continue;
    }
    if (run.length > 2 && PATTERN.test(run)) return true;
    run = '';
  }
  return false;
}

/** The 400 for text the filter refuses (the app shows its own words for it). */
export const OBJECTIONABLE = 'objectionable';

/**
 * Refuses (400) when any field has an objectionable word. The message
 * starts with "objectionable:" so the app can show its own translation,
 * then names the field.
 */
export function assertClean(fields: Record<string, string | undefined>): void {
  for (const [field, value] of Object.entries(fields)) {
    if (value && isObjectionable(value)) {
      throw badRequest(`${OBJECTIONABLE}: ${field} has words Grigri doesn't allow; please keep it friendly`);
    }
  }
}
