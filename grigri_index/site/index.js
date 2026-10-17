// Grigri's landing page: the page in the visitor's language, and GriGri
// Pics (specs/pics.md) from the catalog CloudFront serves at
// /pics/catalog.json, nearest first when the browser shares where it is.
// The point never leaves the device: distances are worked out here, so
// the page costs no API call, only cached CloudFront requests.
'use strict';

const STRINGS = {
  en: {
    signIn: 'Sign in',
    heroTitle: 'Join a climbing plan.',
    heroLead: 'Make a plan, or swipe right on one, and climb together.',
    signInWithGoogle: 'Sign in with Google',
    freeLine: 'Free for every climber: no card, no subscription.',
    stampJoin: 'JOIN',
    deckWhen: 'This Saturday · Sport · 6b–7a',
    deckWho: 'Mara, Jonas and 1 more',
    deckWhen2: 'Sunday · Multi-pitch · 6a–6b',
    deckWho2: 'Iker and Lea',
    deckWhen3: 'Next weekend · Bouldering · 6C–7A',
    deckWho3: 'Noor, Tomás and 2 more',
    nearAll: 'Crags on Grigri',
    nearHere: 'Crags near you',
    nearFar: 'The crags nearest you',
    nearFarNote: 'No crag photos near you yet: these are the closest.',
    nearPrivacy: 'Your location stays on your device.',
    nearDenied: 'Location is off, so here are all the crags.',
    locate: 'Show crags near me',
    locating: 'Finding you…',
    km: '{d} km away',
    photoBy: 'Photo: {author}, {license}',
    howTitle: 'How it works',
    step1Title: 'Make a plan',
    step1Body: 'Where, when and which grades: a crag, a Saturday, 6a to 7a.',
    step2Title: 'Swipe right',
    step2Body: "Like someone's plan? Swipe right. The group lets newcomers in one at a time, when everyone says yes.",
    step3Title: 'Climb together',
    step3Body: "Every match opens the plan's group chat: sort out the rope, the ride and the coffee.",
    freeTitle: 'Free. Really.',
    free1: 'Plans and swiping',
    free2: 'Matches and group chats',
    free3: 'Crag photos',
    free4: 'No card to sign up',
    freePremium: "Premium is optional: it's only for advertising on Grigri and for the route finder. Climbing with Grigri costs nothing.",
    finalTitle: 'This weekend’s climbing plan is one swipe away.',
    joinFree: 'Join free with Google',
    footPhotos: 'Crag photos are freely licensed or used with permission; each card credits its author.',
    footOsm: 'Crag locations © OpenStreetMap contributors (ODbL).',
    footPrivacy: 'Privacy policy',
    footSupport: 'Support',
  },
  es: {
    signIn: 'Entrar',
    heroTitle: 'Únete a un plan de escalada.',
    heroLead: 'Crea un plan o desliza a la derecha en uno, y a escalar juntos.',
    signInWithGoogle: 'Iniciar sesión con Google',
    freeLine: 'Gratis para todos: sin tarjeta, sin suscripción.',
    stampJoin: 'ME APUNTO',
    deckWhen: 'Este sábado · Deportiva · 6b–7a',
    deckWho: 'Mara, Jonas y 1 más',
    deckWhen2: 'Domingo · Vías largas · 6a–6b',
    deckWho2: 'Iker y Lea',
    deckWhen3: 'El próximo finde · Búlder · 6C–7A',
    deckWho3: 'Noor, Tomás y 2 más',
    nearAll: 'Escuelas en Grigri',
    nearHere: 'Escuelas cerca de ti',
    nearFar: 'Las escuelas más cercanas',
    nearFarNote: 'Aún no hay fotos de escuelas cerca de ti: estas son las más próximas.',
    nearPrivacy: 'Tu ubicación no sale de tu dispositivo.',
    nearDenied: 'La ubicación está desactivada: aquí tienes todas las escuelas.',
    locate: 'Ver escuelas cerca de mí',
    locating: 'Buscándote…',
    km: 'a {d} km',
    photoBy: 'Foto: {author}, {license}',
    howTitle: 'Cómo funciona',
    step1Title: 'Crea un plan',
    step1Body: 'Dónde, cuándo y qué grados: una escuela, un sábado, de 6a a 7a.',
    step2Title: 'Desliza a la derecha',
    step2Body: '¿Te gusta un plan? Desliza a la derecha. El grupo admite a los nuevos de uno en uno, cuando todos dicen que sí.',
    step3Title: 'Escalad juntos',
    step3Body: 'Cada match abre el chat de grupo del plan: cuerda, coche y café.',
    freeTitle: 'Gratis. De verdad.',
    free1: 'Planes y deslizar',
    free2: 'Matches y chats de grupo',
    free3: 'Fotos de escuelas',
    free4: 'Sin tarjeta para registrarte',
    freePremium: 'Premium es opcional: solo sirve para anunciarse en Grigri y para el buscador de vías. Escalar con Grigri no cuesta nada.',
    finalTitle: 'El plan de escalada de este fin de semana está a un deslizamiento.',
    joinFree: 'Únete gratis con Google',
    footPhotos: 'Las fotos de escuelas tienen licencia libre o se usan con permiso; cada tarjeta cita a su autor.',
    footOsm: 'Ubicaciones de escuelas © colaboradores de OpenStreetMap (ODbL).',
    footPrivacy: 'Política de privacidad',
    footSupport: 'Soporte',
  },
  de: {
    signIn: 'Anmelden',
    heroTitle: 'Schließ dich einem Kletterplan an.',
    heroLead: 'Mach einen Plan oder wisch bei einem nach rechts, und klettert zusammen.',
    signInWithGoogle: 'Mit Google anmelden',
    freeLine: 'Kostenlos für alle: keine Karte, kein Abo.',
    stampJoin: 'DABEI',
    deckWhen: 'Diesen Samstag · Sport · 6b–7a',
    deckWho: 'Mara, Jonas und 1 weitere Person',
    deckWhen2: 'Sonntag · Mehrseillänge · 6a–6b',
    deckWho2: 'Iker und Lea',
    deckWhen3: 'Nächstes Wochenende · Bouldern · 6C–7A',
    deckWho3: 'Noor, Tomás und 2 weitere',
    nearAll: 'Klettergebiete auf Grigri',
    nearHere: 'Klettergebiete in deiner Nähe',
    nearFar: 'Die nächsten Klettergebiete',
    nearFarNote: 'In deiner Nähe gibt es noch keine Fotos: das sind die nächsten.',
    nearPrivacy: 'Dein Standort bleibt auf deinem Gerät.',
    nearDenied: 'Der Standort ist aus, deshalb siehst du alle Gebiete.',
    locate: 'Gebiete in meiner Nähe',
    locating: 'Suche dich…',
    km: '{d} km entfernt',
    photoBy: 'Foto: {author}, {license}',
    howTitle: 'So funktioniert’s',
    step1Title: 'Mach einen Plan',
    step1Body: 'Wo, wann und welche Grade: ein Gebiet, ein Samstag, 6a bis 7a.',
    step2Title: 'Wisch nach rechts',
    step2Body: 'Dir gefällt ein Plan? Wisch nach rechts. Die Gruppe nimmt Neue einzeln auf, wenn alle Ja sagen.',
    step3Title: 'Klettert zusammen',
    step3Body: 'Jedes Match öffnet den Gruppenchat des Plans: Seil, Mitfahrt und Kaffee klären.',
    freeTitle: 'Kostenlos. Wirklich.',
    free1: 'Pläne und Wischen',
    free2: 'Matches und Gruppenchats',
    free3: 'Fotos der Gebiete',
    free4: 'Keine Karte zur Anmeldung',
    freePremium: 'Premium ist freiwillig: nur zum Werben auf Grigri und für den Routenfinder. Klettern mit Grigri kostet nichts.',
    finalTitle: 'Der Kletterplan fürs Wochenende ist nur einen Wisch entfernt.',
    joinFree: 'Kostenlos mit Google beitreten',
    footPhotos: 'Die Fotos der Gebiete sind frei lizenziert oder mit Erlaubnis verwendet; jede Karte nennt ihre Urheber.',
    footOsm: 'Standorte der Gebiete © OpenStreetMap-Mitwirkende (ODbL).',
    footPrivacy: 'Datenschutzerklärung',
    footSupport: 'Support',
  },
  fr: {
    signIn: 'Connexion',
    heroTitle: 'Rejoins un plan de grimpe.',
    heroLead: 'Crée un plan ou swipe à droite sur un plan, et grimpez ensemble.',
    signInWithGoogle: 'Se connecter avec Google',
    freeLine: 'Gratuit pour tous les grimpeurs : sans carte, sans abonnement.',
    stampJoin: 'JE VIENS',
    deckWhen: 'Ce samedi · Couenne · 6b–7a',
    deckWho: 'Mara, Jonas et 1 autre',
    deckWhen2: 'Dimanche · Grande voie · 6a–6b',
    deckWho2: 'Iker et Lea',
    deckWhen3: 'Le week-end prochain · Bloc · 6C–7A',
    deckWho3: 'Noor, Tomás et 2 autres',
    nearAll: 'Les sites sur Grigri',
    nearHere: 'Des sites près de toi',
    nearFar: 'Les sites les plus proches',
    nearFarNote: 'Pas encore de photos près de toi : voici les plus proches.',
    nearPrivacy: 'Ta position reste sur ton appareil.',
    nearDenied: 'La localisation est désactivée : voici tous les sites.',
    locate: 'Voir les sites près de moi',
    locating: 'On te cherche…',
    km: 'à {d} km',
    photoBy: 'Photo : {author}, {license}',
    howTitle: 'Comment ça marche',
    step1Title: 'Crée un plan',
    step1Body: 'Où, quand et quelles cotations : un site, un samedi, du 6a au 7a.',
    step2Title: 'Swipe à droite',
    step2Body: "Un plan te plaît ? Swipe à droite. Le groupe accueille les nouveaux un par un, quand tout le monde dit oui.",
    step3Title: 'Grimpez ensemble',
    step3Body: 'Chaque match ouvre le tchat de groupe du plan : la corde, le covoiturage et le café.',
    freeTitle: 'Gratuit. Vraiment.',
    free1: 'Plans et swipes',
    free2: 'Matchs et tchats de groupe',
    free3: 'Photos des sites',
    free4: 'Aucune carte pour t’inscrire',
    freePremium: 'Premium est facultatif : il ne sert qu’à faire de la publicité sur Grigri et au détecteur de voies. Grimper avec Grigri ne coûte rien.',
    finalTitle: 'Le plan de grimpe de ce week-end n’est qu’à un swipe.',
    joinFree: 'Rejoindre gratuitement avec Google',
    footPhotos: 'Les photos des sites sont sous licence libre ou utilisées avec autorisation ; chaque carte crédite son auteur.',
    footOsm: 'Emplacements des sites © contributeurs d’OpenStreetMap (ODbL).',
    footPrivacy: 'Politique de confidentialité',
    footSupport: 'Assistance',
  },
  pt: {
    signIn: 'Entrar',
    heroTitle: 'Entre em um plano de escalada.',
    heroLead: 'Crie um plano ou deslize para a direita em um, e escalem juntos.',
    signInWithGoogle: 'Entrar com o Google',
    freeLine: 'Grátis para todos: sem cartão, sem assinatura.',
    stampJoin: 'EU VOU',
    deckWhen: 'Este sábado · Esportiva · 6b–7a',
    deckWho: 'Mara, Jonas e mais 1',
    deckWhen2: 'Domingo · Via longa · 6a–6b',
    deckWho2: 'Iker e Lea',
    deckWhen3: 'No próximo fim de semana · Boulder · 6C–7A',
    deckWho3: 'Noor, Tomás e mais 2',
    nearAll: 'Picos no Grigri',
    nearHere: 'Picos perto de você',
    nearFar: 'Os picos mais próximos',
    nearFarNote: 'Ainda não há fotos perto de você: estes são os mais próximos.',
    nearPrivacy: 'Sua localização fica no seu dispositivo.',
    nearDenied: 'A localização está desligada: aqui estão todos os picos.',
    locate: 'Ver picos perto de mim',
    locating: 'Procurando você…',
    km: 'a {d} km',
    photoBy: 'Foto: {author}, {license}',
    howTitle: 'Como funciona',
    step1Title: 'Crie um plano',
    step1Body: 'Onde, quando e quais graus: um pico, um sábado, de 6a a 7a.',
    step2Title: 'Deslize para a direita',
    step2Body: 'Gostou de um plano? Deslize para a direita. O grupo aceita novatos um de cada vez, quando todos dizem sim.',
    step3Title: 'Escalem juntos',
    step3Body: 'Cada match abre o chat em grupo do plano: corda, carona e café.',
    freeTitle: 'Grátis. De verdade.',
    free1: 'Planos e deslizar',
    free2: 'Matches e chats em grupo',
    free3: 'Fotos dos picos',
    free4: 'Sem cartão para se cadastrar',
    freePremium: 'O Premium é opcional: serve só para anunciar no Grigri e para o localizador de vias. Escalar com o Grigri não custa nada.',
    finalTitle: 'O plano de escalada deste fim de semana está a um deslize.',
    joinFree: 'Entre grátis com o Google',
    footPhotos: 'As fotos dos picos têm licença livre ou são usadas com permissão; cada cartão credita o autor.',
    footOsm: 'Localização dos picos © colaboradores do OpenStreetMap (ODbL).',
    footPrivacy: 'Política de privacidade',
    footSupport: 'Suporte',
  },
  ca: {
    signIn: 'Entra',
    heroTitle: 'Uneix-te a un pla d’escalada.',
    heroLead: 'Fes un pla o llisca a la dreta en un, i escaleu junts.',
    signInWithGoogle: 'Inicia la sessió amb Google',
    freeLine: 'Gratuït per a tothom: sense targeta, sense subscripció.',
    stampJoin: 'M’HI APUNTO',
    deckWhen: 'Aquest dissabte · Esportiva · 6b–7a',
    deckWho: 'Mara, Jonas i 1 més',
    deckWhen2: 'Diumenge · Via llarga · 6a–6b',
    deckWho2: 'Iker i Lea',
    deckWhen3: 'El cap de setmana que ve · Bloc · 6C–7A',
    deckWho3: 'Noor, Tomás i 2 més',
    nearAll: 'Escoles a Grigri',
    nearHere: 'Escoles a prop teu',
    nearFar: 'Les escoles més properes',
    nearFarNote: 'Encara no hi ha fotos a prop teu: aquestes són les més properes.',
    nearPrivacy: 'La teva ubicació no surt del teu dispositiu.',
    nearDenied: 'La ubicació està desactivada: aquí tens totes les escoles.',
    locate: 'Mostra escoles a prop meu',
    locating: 'Et busquem…',
    km: 'a {d} km',
    photoBy: 'Foto: {author}, {license}',
    howTitle: 'Com funciona',
    step1Title: 'Fes un pla',
    step1Body: 'On, quan i quins graus: una escola, un dissabte, de 6a a 7a.',
    step2Title: 'Llisca a la dreta',
    step2Body: 'T’agrada un pla? Llisca a la dreta. El grup admet els nous d’un en un, quan tothom diu que sí.',
    step3Title: 'Escaleu junts',
    step3Body: 'Cada match obre el xat de grup del pla: la corda, el cotxe i el cafè.',
    freeTitle: 'Gratuït. De debò.',
    free1: 'Plans i lliscar',
    free2: 'Matches i xats de grup',
    free3: 'Fotos de les escoles',
    free4: 'Sense targeta per registrar-te',
    freePremium: 'Premium és opcional: només serveix per anunciar-se a Grigri i per al cercador de vies. Escalar amb Grigri no costa res.',
    finalTitle: 'El pla d’escalada d’aquest cap de setmana és a un lliscament.',
    joinFree: 'Uneix-te gratis amb Google',
    footPhotos: 'Les fotos de les escoles tenen llicència lliure o s’usen amb permís; cada targeta en cita l’autor.',
    footOsm: 'Ubicacions de les escoles © col·laboradors d’OpenStreetMap (ODbL).',
    footPrivacy: 'Política de privadesa',
    footSupport: 'Suport',
  },
};

// The app's languages (specs/i18n.md): the browser's first one we have.
const lang = (navigator.languages || [navigator.language || 'en'])
  .map((l) => String(l).slice(0, 2).toLowerCase())
  .find((l) => l in STRINGS) || 'en';
const S = STRINGS[lang];
const t = (key, vars = {}) => (S[key] ?? STRINGS.en[key]).replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? '');

const NEAR_KM = 150; // closer than this, the crags are "near you"
const MAX_CARDS = 12;
const PER_CRAG = 3;

const $ = (id) => document.getElementById(id);
let catalog = null;
let here = null;

function translate() {
  document.documentElement.lang = lang;
  for (const el of document.querySelectorAll('[data-i18n]')) el.textContent = t(el.dataset.i18n);
}

// Great-circle distance in km.
function km(a, b) {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 12742 * Math.asin(Math.sqrt(h));
}

function formatKm(d) {
  return new Intl.NumberFormat(lang, { maximumFractionDigits: d < 10 ? 1 : 0 }).format(d);
}

// Only links to the photos' own pages, never anything else from the data.
function safeUrl(url) {
  try {
    const u = new URL(url);
    return u.protocol === 'https:' ? u.href : null;
  } catch (e) {
    return null;
  }
}

const picUrl = (photo) => '/pics/' + String(photo.key).replace(/^\/+/, '');

// Crags with photos, nearest first when we know where the visitor is.
function picks() {
  const crags = (catalog?.crags ?? [])
    .filter((c) => Array.isArray(c.photos) && c.photos.length && Number.isFinite(c.lat) && Number.isFinite(c.lon))
    .map((c) => ({ ...c, dist: here ? km(here, c) : null }));
  if (here) crags.sort((a, b) => a.dist - b.dist);
  const cards = [];
  for (const crag of crags) {
    for (const photo of crag.photos.slice(0, PER_CRAG)) cards.push({ crag, photo });
  }
  return { nearest: crags[0]?.dist ?? null, cards: cards.slice(0, MAX_CARDS) };
}

function showImage(img, photo) {
  if (!img || !photo) return;
  img.src = picUrl(photo);
  img.hidden = false;
}

function card({ crag, photo }) {
  const li = document.createElement('li');
  li.className = 'crag';

  const frame = document.createElement('div');
  frame.className = 'crag-photo';
  const img = document.createElement('img');
  img.loading = 'lazy';
  img.decoding = 'async';
  img.src = picUrl(photo);
  img.alt = photo.caption || crag.name;
  if (photo.width && photo.height) {
    img.width = photo.width;
    img.height = photo.height;
  }
  frame.append(img);
  if (crag.dist != null) {
    const dist = document.createElement('span');
    dist.className = 'crag-dist';
    dist.textContent = t('km', { d: formatKm(crag.dist) });
    frame.append(dist);
  }

  const name = document.createElement('span');
  name.className = 'crag-name';
  name.textContent = crag.name;
  li.append(frame, name);

  if (crag.area && crag.area !== crag.name) {
    const area = document.createElement('span');
    area.className = 'crag-area';
    area.textContent = crag.area;
    li.append(area);
  }

  // The credit the licenses ask for, linked to the photo's source.
  const credit = document.createElement('span');
  credit.className = 'crag-credit';
  const text = t('photoBy', { author: photo.author || '?', license: photo.license || '' });
  const source = safeUrl(photo.source);
  if (source) {
    const a = document.createElement('a');
    a.href = source;
    a.rel = 'noopener noreferrer';
    a.target = '_blank';
    a.textContent = text;
    credit.append(a);
  } else {
    credit.textContent = text;
  }
  li.append(credit);
  return li;
}

function render(note) {
  const { nearest, cards } = picks();
  const title = $('near-title');
  const noteEl = $('near-note');
  if (nearest == null) {
    title.textContent = t('nearAll');
  } else if (nearest <= NEAR_KM) {
    title.textContent = t('nearHere');
  } else {
    title.textContent = t('nearFar');
    note = note || t('nearFarNote');
  }
  noteEl.textContent = note || t('nearPrivacy');

  $('strip').replaceChildren(...cards.map(card));
  // The nearest crag behind the pitch, and on the demo card.
  showImage($('hero-bg'), cards[0]?.photo);
  // The demo card's plans: up to three other crags (the hero's last).
  const crags = [];
  for (const c of cards) {
    if (!crags.some((d) => d.crag.name === c.crag.name)) crags.push(c);
  }
  demo = [...crags.slice(1), ...crags.slice(0, 1)].slice(0, DEMO.length);
  showDemo();
}

// The demo card's plans: when they are and who's going, at the crags in
// `demo` (made-up names, as the card says when there's no catalog).
const DEMO = [
  { crag: 'Siurana', when: 'deckWhen', who: 'deckWho' },
  { crag: 'Margalef', when: 'deckWhen2', who: 'deckWho2' },
  { crag: 'Montserrat', when: 'deckWhen3', who: 'deckWho3' },
];
let demo = [];
let demoAt = 0;

function showDemo() {
  const plan = DEMO[demoAt % DEMO.length];
  const pick = demo.length ? demo[demoAt % demo.length] : null;
  const img = $('deck-photo');
  if (pick) showImage(img, pick.photo);
  else if (img) img.hidden = true;
  $('deck-crag').textContent = pick ? pick.crag.name : plan.crag;
  for (const [id, key] of [['deck-when', plan.when], ['deck-who', plan.who]]) {
    $(id).dataset.i18n = key;
    $(id).textContent = t(key);
  }
}

// Each loop ends with the card off screen: the next plan comes in then.
function cycleDemo() {
  demoAt += 1;
  showDemo();
}

function locate() {
  const button = $('locate');
  button.disabled = true;
  button.textContent = t('locating');
  navigator.geolocation.getCurrentPosition(
    (pos) => {
      here = { lat: pos.coords.latitude, lon: pos.coords.longitude };
      button.hidden = true;
      render();
    },
    () => {
      button.hidden = true;
      render(t('nearDenied'));
    },
    { enableHighAccuracy: false, maximumAge: 3600e3, timeout: 15e3 },
  );
}

async function offerLocation() {
  if (!('geolocation' in navigator)) return;
  const button = $('locate');
  button.addEventListener('click', locate);
  let state = 'prompt';
  try {
    state = (await navigator.permissions.query({ name: 'geolocation' })).state;
  } catch (e) {
    // No Permissions API (older Safari): offer the button.
  }
  if (state === 'granted') {
    locate(); // no prompt: the visitor already allowed it
  } else if (state !== 'denied') {
    button.hidden = false;
  }
}

async function loadCatalog() {
  try {
    const res = await fetch('/pics/catalog.json', { credentials: 'omit' });
    if (!res.ok) throw new Error(res.status);
    catalog = await res.json();
  } catch (e) {
    // No photos: the page still works, without the strip.
    document.querySelector('.near').hidden = true;
    return;
  }
  render();
  offerLocation();
}

document.querySelector('.card-top')?.addEventListener('animationiteration', (e) => {
  if (e.animationName === 'swipe') cycleDemo();
});
translate();
loadCatalog();
