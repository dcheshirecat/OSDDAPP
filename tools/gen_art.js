// Generates game art from free-for-commercial-use sources:
//  - Full-body art: Open Peeps (CC0, Pablo Stanley) via react-peeps,
//                   Humaaans (CC BY 4.0, Pablo Stanley) via react-humaaans
//    Headshots are cropped from the full-body art by tools/crop_bodies.py so they always match.
//  - Icons: game-icons.net (CC BY 3.0) via @iconify-json/game-icons
// Usage: (in a dir with deps installed)
//   npm i --legacy-peer-deps react@17 react-dom@17 react-peeps react-humaaans @resvg/resvg-js @iconify-json/game-icons @fontsource/nunito
//   node gen_art.js <path-to-game-dir> && python3 crop_bodies.py <path-to-game-dir>
const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');
const icons = require('@iconify-json/game-icons/icons.json');

const game = path.resolve(process.argv[2]);
const out = (p) => path.join(game, 'assets', p);
const png = (svg, w) => new Resvg(svg, { fitTo: { mode: 'width', value: w } }).render().asPng();

const alters = JSON.parse(fs.readFileSync(path.join(game, 'data/alters.json')));

// ---- full bodies ----
global.window = global; // react-humaaans UMD bundle expects a window
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const Peep = require('react-peeps').default;
const Humaaans = require('react-humaaans');
const NS = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ';
fs.mkdirSync(out('bodies'), { recursive: true });
fs.mkdirSync(out('portraits'), { recursive: true });
function renderBody(b) {
  let svg;
  if (b.lib === 'peeps') {
    svg = renderToStaticMarkup(React.createElement(Peep, {
      body: b.pose, face: b.face, hair: b.hair, accessory: b.acc, facialHair: b.facial,
      strokeColor: '#2b2233', backgroundColor: '#' + b.fill,
      viewBox: { x: '-700', y: '-100', width: '2400', height: '3400' }, style: { width: 1440, height: 2040 } }));
    svg = svg.match(/<svg[\s\S]*<\/svg>/)[0].replace(/<svg /, NS + 'width="1440" height="2040" ');
  } else {
    const C = Humaaans[b.pose];
    if (!C) throw new Error('unknown humaaans pose ' + b.pose);
    svg = renderToStaticMarkup(React.createElement(C, { height: 1800,
      skinColor: '#' + b.skin, hairColor: '#' + b.hair, coatColor: '#' + b.coat, shirtColor: '#' + b.shirt,
      pantColor: '#' + b.pant, shoeColor: '#' + b.shoe, hatColor: '#' + b.hat, objectColor: '#9aa3ad', wheelchairColor: '#55606e' }));
    svg = svg.match(/<svg[\s\S]*<\/svg>/)[0].replace(/<svg /, NS);
  }
  return new Resvg(svg).render().asPng();
}
for (const a of alters) fs.writeFileSync(out(`bodies/${a.id}_raw.png`), renderBody(a.body));

// Alternate "looks" for cosmetic customization (deterministic pseudo-random)
let seed = 1234;
const rnd = (arr) => { seed = (seed * 16807) % 2147483647; return arr[seed % arr.length]; };
const P = require('react-peeps');
const peepPoses = ['BlazerPantsWB','BlazerWB','CrossedArmsBW','EasingWB','PointingFingerWB','PolkaDots','RestingWB','ShirtPantsWB','ShirtWB','WalkingWB','HandsBackWB','MediumWB','OneLegUpWB','WheelChair','ClosedLegWB','RoboDanceWB'];
const peepFaces = ['Smile','Calm','Cute','SmileBig','Cheeky','EyesClosed','SmileLol','Driven','Solemn'];
const peepHair = Object.keys(P.Hair).filter(h => !h.startsWith('Doc'));
const peepAcc = ['None','None','None','GlassRound','GlassRoundThick','SunglassWayfarer','GlassButterfly'];
const fills = ['c8d6f0','ffe3a3','d9f2d0','e4dcf5','ffd6c9','fff1c1','cfeee8','ffd1e1','dcd6ec','d5ecf0','f6d6d6','d2efd6'];
const humPoses = Object.keys(Humaaans);
const skins = ['f6d5c0','f1c3a0','e0b090','c98d6b','a0664a','8a5a3c','6b4433'];
const hairs = ['1a1a1a','3a2a1a','6b4a2a','e0702a','f0c43a','e85a8a','7a5fd6','c0c0c0'];
const clothes = ['e07a9a','6d9bc3','5fae9c','e6b54a','8b7cc8','e0875a','2a9d8f','ff7ac0','4f6db0','62b6cb','2b2b2b','b06ad6'];
const looks = [];
for (let i = 0; i < 30; i++) {
  const bg = fills[i % fills.length];
  let body;
  if (i % 2 === 0) body = { lib: 'peeps', pose: rnd(peepPoses), face: rnd(peepFaces), hair: rnd(peepHair), acc: rnd(peepAcc), facial: 'None', fill: bg };
  else body = { lib: 'humaaans', pose: rnd(humPoses), skin: rnd(skins), hair: rnd(hairs), coat: rnd(clothes), shirt: 'ffffff', pant: rnd(clothes), shoe: '2b2b2b', hat: rnd(clothes) };
  const id = `look_${i}`;
  looks.push({ id, bg, body });
  fs.writeFileSync(out(`bodies/${id}_raw.png`), renderBody(body));
}
fs.writeFileSync(path.join(game, 'data/looks.json'), JSON.stringify(looks));

// ---- icons ----
const iconNames = new Set([
  // skills
  'conversation','notebook','muscle-up','meditation','magnifying-glass','palette',
  // currencies / resources
  'sparkles','two-coins','crystal-cluster','spoon','lightning-trio','hearts','spiral-bloom',
  // nav
  'house','three-friends','chest','alarm-clock','scroll-unfurled','sofa','cog','person','open-book','star-formation','sun','padlock','check-mark',
  // areas
  'vacuum-cleaner','briefcase','shopping-cart','party-popper','heart-plus',
]);
const roles = JSON.parse(fs.readFileSync(path.join(game, 'data/roles.json')));
Object.values(roles).forEach(r => iconNames.add(r.icon));
const items = JSON.parse(fs.readFileSync(path.join(game, 'data/items.json')));
items.comfort.forEach(i => iconNames.add(i.icon));
items.decor.forEach(i => iconNames.add(i.icon));
for (const name of iconNames) {
  const ic = icons.icons[name];
  if (!ic) throw new Error('missing icon ' + name);
  const w = ic.width || icons.width || 512, h = ic.height || icons.height || 512;
  const body = ic.body.replace(/currentColor/g, '#ffffff');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}">${body}</svg>`;
  fs.writeFileSync(out(`icons/${name}.png`), png(svg, 128));
}

// ---- fonts ----
for (const wgt of ['400', '800']) {
  fs.copyFileSync(require.resolve(`@fontsource/nunito/files/nunito-latin-${wgt}-normal.woff2`), out(`fonts/nunito-${wgt}.woff2`));
}

// ---- credits ----
const lines = [];
lines.push({ style: 'Open Peeps (full-body art)', creator: 'Pablo Stanley', license: 'CC0 1.0', source: 'https://www.openpeeps.com', licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/' });
lines.push({ style: 'Humaaans (full-body art)', creator: 'Pablo Stanley', license: 'CC BY 4.0', source: 'https://www.humaaans.com', licenseUrl: 'https://creativecommons.org/licenses/by/4.0/' });
lines.push({ style: 'Game-icons.net (icons)', creator: 'Lorc, Delapouite & contributors', license: 'CC BY 3.0', source: 'https://game-icons.net', licenseUrl: 'https://creativecommons.org/licenses/by/3.0/' });
lines.push({ style: 'Nunito (font)', creator: 'Vernon Adams, Cyreal, Jacques Le Bailly', license: 'SIL OFL 1.1', source: 'https://fonts.google.com/specimen/Nunito', licenseUrl: 'https://openfontlicense.org' });
fs.writeFileSync(path.join(game, 'data/credits_art.json'), JSON.stringify(lines, null, 1));
console.log('bodies', alters.length + looks.length, 'icons', iconNames.size);
