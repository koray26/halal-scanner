// Erzeugt lib/domain/rules/off_terms.g.dart aus dem Zutaten-Wörterbuch von
// Open Food Facts (ODbL). Kostenlos, ohne Schlüssel.
//
// Aufruf (Node 18+):
//   git clone --depth 1 --filter=blob:none --sparse \
//     https://github.com/openfoodfacts/openfoodfacts-server off
//   (cd off && git sparse-checkout set --no-cone /taxonomies/food/ingredients.txt /taxonomies/additives.txt)
//   node tool/off_terms/extract_off_terms.mjs off/taxonomies/food/ingredients.txt,off/taxonomies/additives.txt <commit>
//
// Grundsatz – es entstehen KEINE neuen Bewertungen:
// 1. Jeder Wörterbuch-Eintrag wird über seine ENGLISCHEN Namen mit den
//    bestehenden Wortlisten aus catalog.dart eingeordnet (gleiche Regex-
//    Technik wie Dart). Nur Einträge, deren englische Namen alle dieselben
//    Regeln auslösen, werden verwendet.
// 2. Die Namen dieses Eintrags in den Zielsprachen erben genau diese Regeln.
// 3. Ein Begriff, der in der Zielsprache auch bei einem anderen Eintrag mit
//    anderer Einordnung vorkommt (z. B. „anggur“ = Traube UND Wein), ist
//    mehrdeutig und wird verworfen.
// 4. Ausgelassen: Einträge mit Herkunftsangabe (pflanzlich, mikrobiell …),
//    Hefe (offene Fachfrage Bierhefe), Begriffe unter 3 Zeichen oder mit
//    Ziffern, Begriffe, die die bestehenden Muster schon erkennen.
import fs from 'fs';

const [taxonomyPaths, commit = 'unbekannt'] = process.argv.slice(2);
const root = new URL('../../', import.meta.url).pathname;
const catalog = fs.readFileSync(root + 'lib/domain/rules/catalog.dart', 'utf8');
const TARGET = ['ar', 'id', 'ms', 'ur', 'bn', 'hi', 'fa', 'ha'];

// Von Hand geprüft und gesperrt (Grund jeweils angegeben). Begriffe aus dem
// Wörterbuch, die in der Alltagssprache etwas anderes bedeuten oder fehlerhaft
// sind, würden falsche Treffer erzeugen.
const BLOCKED = {
  ar: {
    'جودة': 'bedeutet im Alltag „Qualität“ (im Wörterbuch: Käse Gouda)',
    'مستخلص فانيليا عي': 'abgeschnittener Eintrag',
    'ئەنزیم': 'kurdische Schrift, falsch als Arabisch eingetragen',
  },
  id: { couenne: 'französisches Wort, falsch als Indonesisch eingetragen' },
  ms: {
    couenne: 'französisches Wort, falsch als Malaiisch eingetragen',
    eenzim: 'Schreibfehler',
  },
};

// --- Dart-Muster aus catalog.dart lesen --------------------------------------
const L = '\\p{L}*';
function dartStrings(block) {
  const out = []; const re = /(r?)'((?:\\.|[^'\\])*)'/g; let m; let lastEnd = -1;
  while ((m = re.exec(block))) {
    const adjacent = lastEnd >= 0 && /^\s*$/.test(block.slice(lastEnd, m.index));
    lastEnd = re.lastIndex;
    let s = m[2];
    if (!m[1]) s = s.replace(/\\\\/g, '\u0000').replace(/\\'/g, "'").replace(/\u0000/g, '\\');
    s = s.replace(/\$\{_l\}/g, L).replace(/\$_l/g, L);
    if (adjacent) out[out.length - 1] += s; else out.push(s);
  }
  return out;
}
function listAfter(block, key, named) {
  const i = block.indexOf(key + ':'); if (i < 0) return [];
  const rest = block.slice(i + key.length + 1).trimStart();
  for (const [n, v] of Object.entries(named)) if (rest.startsWith(n)) return v;
  let depth = 0; const j = rest.indexOf('[');
  for (let k = j; k < rest.length; k++) {
    if (rest[k] === '[') depth++;
    if (rest[k] === ']') { depth--; if (!depth) return dartStrings(rest.slice(j, k + 1).replace(/\/\/[^\n]*/g, '')); }
  }
  return [];
}
const constList = name => { const s = catalog.indexOf(`const List<String> ${name} = [`); return dartStrings(catalog.slice(s, catalog.indexOf('];', s)).replace(/\/\/[^\n]*/g, '')); };
const named = { _porkCores: constList('_porkCores') };
const rulesSrc = catalog.slice(catalog.indexOf('const List<IngredientRule> ingredientRules'), catalog.indexOf('const Map<String, String> additiveTagRules'));
const rules = rulesSrc.split('IngredientRule(').slice(1).map(b => ({
  id: /id: '([^']+)'/.exec(b)[1],
  patterns: listAfter(b, 'patterns', named),
  exclusions: listAfter(b, 'exclusions', named),
  suppressedBy: (/suppressedBy: \{([^}]*)\}/.exec(b)?.[1] ?? '').match(/'([^']+)'/g)?.map(x => x.slice(1, -1)) ?? [],
}));
const qualSrc = catalog.slice(catalog.indexOf('final Map<Qualifier, List<String>> qualifierPatterns'), catalog.indexOf('const List<String> _porkCores'));
const qualifierWords = dartStrings(qualSrc.replace(/Qualifier\.porcine: _porkCores,/, '').replace(/\/\/[^\n]*/g, ''));
const word = c => '(?<![\\p{L}\\p{N}])(?:' + c + ')(?![\\p{L}\\p{N}])';
const compiled = rules.map(r => ({ ...r, re: r.patterns.map(p => new RegExp(word(p), 'iu')), ex: r.exclusions.map(p => new RegExp(p, 'iu')) }));
const qualRe = qualifierWords.map(p => new RegExp(word(p), 'iu'));

/** Regeln, die ein einzelner Bestandteil auslöst (wie _matchHead). */
function classify(head) {
  const hits = new Set();
  for (const r of compiled) {
    for (const re of r.re) {
      const m = re.exec(head); if (!m) continue;
      const win = head.slice(Math.max(0, m.index - 12), Math.min(head.length, m.index + m[0].length + 12));
      if (r.ex.some(x => x.test(m[0]) || x.test(win))) continue;
      hits.add(r.id); break;
    }
  }
  for (const r of compiled) if (hits.has(r.id) && r.suppressedBy.some(s => hits.has(s))) hits.delete(r.id);
  return [...hits].sort().join('+');
}

// --- Wörterbuch lesen ---------------------------------------------------------
const entries = [];
for (const path of taxonomyPaths.split(',')) {
  let cur = [];
  for (const line of fs.readFileSync(path, 'utf8').split('\n')) {
    if (!line.trim()) { if (cur.length) entries.push(cur); cur = []; continue; }
    if (line.startsWith('#') || line.startsWith('<')) continue;
    cur.push(line);
  }
  if (cur.length) entries.push(cur);
}

const clean = s => s.trim().toLowerCase().replace(/\s+/g, ' ');
const parsed = entries.map(e => {
  const names = {};
  for (const l of e) {
    const m = /^([a-z]{2,3}):\s*(.+)$/.exec(l);
    if (m && m[1] !== 'xx') names[m[1]] = m[2].split(',').map(clean).filter(Boolean);
  }
  return names;
}).filter(n => n.en);

// Einordnung je Eintrag über die englischen Namen.
const index = {}; // lang -> term -> Set(Einordnung)
const usable = [];
for (const n of parsed) {
  const cls = [...new Set(n.en.map(classify))];
  const consistent = cls.length === 1;
  const c = consistent ? cls[0] : '?';
  for (const lang of TARGET) for (const t of n[lang] ?? []) {
    ((index[lang] ??= {})[t] ??= new Set()).add(c);
  }
  if (!consistent || !c) continue;
  if (n.en.some(x => /yeast/.test(x))) continue; // offene Fachfrage Bierhefe
  if (n.en.some(x => qualRe.some(q => q.test(x)))) continue; // Herkunftsangaben
  usable.push({ en: n.en[0], cls: c, names: n });
}

const out = {}; const dropped = { ambiguous: 0, short: 0, known: 0 };
for (const u of usable) for (const lang of TARGET) for (const t of u.names[lang] ?? []) {
  if ([...t].length < 3 || /\d/.test(t)) { dropped.short++; continue; }
  if (BLOCKED[lang]?.[t]) { dropped.blocked = (dropped.blocked ?? 0) + 1; continue; }
  if (index[lang][t].size !== 1) { dropped.ambiguous++; continue; }
  if (classify(t) === u.cls) { dropped.known++; continue; }
  for (const id of u.cls.split('+')) ((out[lang] ??= {})[id] ??= new Set()).add(t);
}

// --- Dart-Datei schreiben ---------------------------------------------------------
const esc = t => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/'/g, "\\'").replace(/ /g, '\\s+');
let dart = `// GENERIERT von tool/off_terms/extract_off_terms.mjs – nicht von Hand ändern.
// Quelle: Open Food Facts, taxonomies/food/ingredients.txt und taxonomies/additives.txt, Stand ${commit}.
// Lizenz der Daten: Open Database License (ODbL), (c) Open Food Facts.
//
// Zutatenbezeichnungen in Sprachen ohne eigene Wortlisten. Jeder Begriff
// erbt die Regel, die die BESTEHENDEN englischen Wortlisten für den
// englischen Namen desselben Wörterbuch-Eintrags auslösen. Mehrdeutige
// Begriffe sind entfernt. Diese Begriffe erkennen HARAM/UNKLAR, ermöglichen
// aber nie ein grünes Ergebnis (Sprachen ohne Freigabe für Grün).
// ignore_for_file: lines_longer_than_80_chars
library;

/// Sprache -> Regel-ID -> Regex-Muster (Ganzwort, ohne Groß-/Kleinschreibung).
const Map<String, Map<String, List<String>>> offTermPatterns = {
`;
const stats = [];
for (const lang of TARGET) {
  const byRule = out[lang] ?? {};
  dart += `  '${lang}': {\n`;
  let n = 0;
  for (const id of Object.keys(byRule).sort()) {
    const terms = [...byRule[id]].sort();
    n += terms.length;
    dart += `    '${id}': [${terms.map(t => `r'${esc(t)}'`.replace(/^r'(.*)'$/, (m, x) => x.includes("'") ? `'${x}'` : m)).join(', ')}],\n`;
  }
  dart += '  },\n';
  stats.push(`${lang}: ${n}`);
}
dart += '};\n';
fs.writeFileSync(root + 'lib/domain/rules/off_terms.g.dart', dart);
console.log('Einträge verwendbar:', usable.length, '| verworfen:', JSON.stringify(dropped));
console.log('Begriffe je Sprache:', stats.join(', '));
