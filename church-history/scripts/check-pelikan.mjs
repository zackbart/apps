// Check every Pelikan citation in research/*.json. Citations look like
// "Pelikan 2:146-157" (volume:printed pages). Each cited page must exist in
// that volume, using the local text in research/books/pelikan/text/ (not in git).
// Usage: node scripts/check-pelikan.mjs
import { existsSync, readFileSync, readdirSync } from 'node:fs';

const research = new URL('../research/', import.meta.url);
const textDir = new URL('books/pelikan/text/', research);
const FORMAT = /^Pelikan ([1-5]):(\d+)(?:-(\d+))?$/;

// Last printed page per volume, read from the pages' running headers.
const pages = new Map();
if (existsSync(textDir)) {
  for (const f of readdirSync(textDir)) {
    const vol = Number(/^vol(\d)/.exec(f)?.[1]);
    if (!vol) continue;
    const seen = new Set();
    for (const page of readFileSync(new URL(f, textDir), 'utf8').split(/=== PDF page \d+ ===/)) {
      const lines = page.split('\n').map((l) => l.trim()).filter(Boolean);
      for (const l of [lines[0], lines.at(-1)]) {
        const m = /(?:^|\s)(\d{1,3})$/.exec(l ?? '') ?? /^(\d{1,3})(?:\s|$)/.exec(l ?? '');
        if (m) seen.add(Number(m[1]));
      }
    }
    // Last body page, ignoring stray large numbers from the scan.
    pages.set(vol, Math.max(...[...seen].filter((n) => n < 500)));
  }
}

const problems = [];
let count = 0;
const walk = (v, where) => {
  if (typeof v === 'string') {
    if (!/pelikan/i.test(v) || !/^Pelikan\b/.test(v)) return;
    count++;
    const m = FORMAT.exec(v);
    if (!m) return problems.push(`${where}: bad format "${v}" (use "Pelikan <vol>:<page>" or "Pelikan <vol>:<from>-<to>")`);
    const [vol, from, to] = [Number(m[1]), Number(m[2]), Number(m[3] ?? m[2])];
    if (to < from || to - from > 30) problems.push(`${where}: odd page range "${v}"`);
    const last = pages.get(vol);
    if (last && (from < 1 || to > last)) problems.push(`${where}: vol ${vol} runs to page ${last}`);
  } else if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${where}[${i}]`));
  else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) walk(x, where ? `${where}.${k}` : (v.id ?? k));
};
for (const f of readdirSync(research).filter((f) => f.endsWith('.json'))) {
  const data = JSON.parse(readFileSync(new URL(f, research), 'utf8'));
  for (const n of data.nodes ?? []) walk(n.sources ?? [], `${f} ${n.id}.sources`);
  if (!data.nodes) walk(data, f);
}
console.log(`${count} Pelikan citations${pages.size ? '' : ' (book text not found, format checked only)'}`);
if (problems.length) {
  console.log(problems.join('\n'));
  process.exitCode = 1;
}
