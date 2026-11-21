// Generates game art from free-for-commercial-use sources:
//  - Alter portraits: DiceBear avatar styles (licenses listed in CREDITS.md)
//  - Full-body art: Open Peeps (CC0, Pablo Stanley) via react-peeps,
//                   Humaaans (CC BY 4.0, Pablo Stanley) via react-humaaans
//  - Icons: game-icons.net (CC BY 3.0) via @iconify-json/game-icons
// Usage: (in a dir with deps installed)
//   npm i --legacy-peer-deps react@17 react-dom@17 react-peeps react-humaaans @dicebear/core@9 @dicebear/collection@9 @resvg/resvg-js @iconify-json/game-icons @fontsource/nunito
//   node gen_art.js <path-to-game-dir>
const fs = require('fs');
const path = require('path');
const { createAvatar } = require('@dicebear/core');
const collection = require('@dicebear/collection');
const { Resvg } = require('@resvg/resvg-js');
const icons = require('@iconify-json/game-icons/icons.json');

const game = path.resolve(process.argv[2]);
const out = (p) => path.join(game, 'assets', p);
const png = (svg, w) => new Resvg(svg, { fitTo: { mode: 'width', value: w } }).render().asPng();

// ---- portraits ----
const alters = JSON.parse(fs.readFileSync(path.join(game, 'data/alters.json')));
const usedStyles = new Set();
for (const a of alters) {
  const style = collection[a.art.style];
  if (!style) throw new Error('unknown style ' + a.art.style);
  usedStyles.add(a.art.style);
  const svg = createAvatar(style, { seed: a.art.seed, size: 256, backgroundColor: [a.art.bg] }).toString();
  fs.writeFileSync(out(`portraits/${a.id}.png`), png(svg, 256));
}
// Alternate portraits for cosmetic customization
const altStyles = ['adventurer','avataaars','bigEars','bigSmile','bottts','croodles','dylan','funEmoji','lorelei','micah','miniavs','notionists','openPeeps','personas','pixelArt','thumbs','toonHead'];
const bgs = ['c8d6f0','ffe3a3','d9f2d0','e4dcf5','ffd6c9','fff1c1','cfeee8','ffd1e1','dcd6ec','d5ecf0'];
const alts = [];
let n = 0;
for (const s of altStyles) {
  for (let i = 0; i < 4; i++) {
    const id = `alt_${s}_${i}`;
    const svg = createAvatar(collection[s], { seed: `${s}-alt-${i}-osdd`, size: 256, backgroundColor: [bgs[n++ % bgs.length]] }).toString();
    fs.writeFileSync(out(`portraits/${id}.png`), png(svg, 256));
    alts.push({ id, style: s });
    usedStyles.add(s);
  }
}
fs.writeFileSync(path.join(game, 'data/alt_portraits.json'), JSON.stringify(alts));

// ---- full bodies ----
global.window = global; // react-humaaans UMD bundle expects a window
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const Peep = require('react-peeps').default;
const Humaaans = require('react-humaaans');
const NS = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ';
fs.mkdirSync(out('bodies'), { recursive: true });
for (const a of alters) {
  const b = a.body;
  let svg;
  if (b.lib === 'peeps') {
    svg = renderToStaticMarkup(React.createElement(Peep, {
      body: b.pose, face: b.face, hair: b.hair, accessory: b.acc, facialHair: b.facial,
      strokeColor: '#2b2233', backgroundColor: '#' + b.fill,
      viewBox: { x: '-700', y: '-100', width: '2400', height: '3400' }, style: { width: 720, height: 1020 } }));
    svg = svg.match(/<svg[\s\S]*<\/svg>/)[0].replace(/<svg /, NS + 'width="720" height="1020" ');
  } else {
    const C = Humaaans[b.pose];
    if (!C) throw new Error('unknown humaaans pose ' + b.pose);
    svg = renderToStaticMarkup(React.createElement(C, { height: 900,
      skinColor: '#' + b.skin, hairColor: '#' + b.hair, coatColor: '#' + b.coat, shirtColor: '#' + b.shirt,
      pantColor: '#' + b.pant, shoeColor: '#' + b.shoe, hatColor: '#' + b.hat, objectColor: '#9aa3ad', wheelchairColor: '#55606e' }));
    svg = svg.match(/<svg[\s\S]*<\/svg>/)[0].replace(/<svg /, NS);
  }
  fs.writeFileSync(out(`bodies/${a.id}_raw.png`), new Resvg(svg).render().asPng());
}

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
for (const s of [...usedStyles].sort()) {
  const m = collection[s].meta || {};
  lines.push({ style: m.title || s, creator: m.creator || '', license: (m.license && m.license.name) || '', source: m.source || '', licenseUrl: (m.license && m.license.url) || '' });
}
lines.push({ style: 'Open Peeps (full-body art)', creator: 'Pablo Stanley', license: 'CC0 1.0', source: 'https://www.openpeeps.com', licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/' });
lines.push({ style: 'Humaaans (full-body art)', creator: 'Pablo Stanley', license: 'CC BY 4.0', source: 'https://www.humaaans.com', licenseUrl: 'https://creativecommons.org/licenses/by/4.0/' });
lines.push({ style: 'Game-icons.net (icons)', creator: 'Lorc, Delapouite & contributors', license: 'CC BY 3.0', source: 'https://game-icons.net', licenseUrl: 'https://creativecommons.org/licenses/by/3.0/' });
lines.push({ style: 'Nunito (font)', creator: 'Vernon Adams, Cyreal, Jacques Le Bailly', license: 'SIL OFL 1.1', source: 'https://fonts.google.com/specimen/Nunito', licenseUrl: 'https://openfontlicense.org' });
fs.writeFileSync(path.join(game, 'data/credits_art.json'), JSON.stringify(lines, null, 1));
console.log('portraits', alters.length + alts.length, 'icons', iconNames.size, 'styles', usedStyles.size);
