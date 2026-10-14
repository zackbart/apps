// Check Damick citations and quotes against the local text of Orthodoxy and
// Heterodoxy in research/books/damick/text/ (not in git). The book has no page
// numbers, so a citation names a chapter file and a section heading:
// "Damick ch3: Lutheranism". In research/*.json each one must name a real
// heading in that chapter. In the logs (research/damick-*.md), each quote
// written after a citation as  quote: "..."  must appear in that section.
// Usage: node scripts/check-damick.mjs
import { readFileSync, readdirSync } from 'node:fs';

const research = new URL('../research/', import.meta.url);
const textDir = new URL('books/damick/text/', research);
// In logs a heading may contain commas, so take the rest of the citation and
// match the longest known heading it starts with (see heading() below).
const CITE = /Damick (intro|ch[1-8]|epilogue|appendix[1-4]): ([^`"\n]+)/g;
const norm = (s) => s.toLowerCase().replace(/[’‘]/g, "'").replace(/[“”]/g, '"').replace(/\s+/g, ' ').trim();
const words = (s) => norm(s).match(/[a-z0-9']+/g) ?? [];

// chapter -> heading -> words of that section (up to the next heading of any level).
const chapters = new Map();
for (const f of readdirSync(textDir)) {
  const sections = new Map();
  const parts = readFileSync(new URL(f, textDir), 'utf8').split(/^=== H[1-4] (.+) ===$/m);
  for (let i = 1; i < parts.length; i += 2) sections.set(norm(parts[i]), words(parts[i + 1]));
  chapters.set(f.replace(/\.txt$/, '').replace('introduction', 'intro'), sections);
}
const section = (ch, heading) => chapters.get(ch)?.get(norm(heading));
const heading = (ch, text) => {
  const t = norm(text);
  const known = [...(chapters.get(ch)?.keys() ?? [])].filter((h) => t.startsWith(h)).sort((a, b) => b.length - a.length);
  return known[0];
};
const contains = (hay, quote) => {
  const q = words(quote).join(' ');
  return q && ` ${hay.join(' ')} `.includes(` ${q} `);
};

const problems = [];
let cites = 0;
let quotes = 0;
const walk = (v, where) => {
  if (typeof v === 'string') {
    if (!/^Damick\b/.test(v)) return;
    cites++;
    const m = /^Damick (intro|ch[1-8]|epilogue|appendix[1-4]): (.+)$/.exec(v);
    if (!m) problems.push(`${where}: bad format "${v}" (use "Damick ch3: <section heading>")`);
    else if (!section(m[1], m[2])) problems.push(`${where}: no section "${m[2]}" in ${m[1]}`);
  } else if (Array.isArray(v)) v.forEach((x, i) => walk(x, `${where}[${i}]`));
  else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) walk(x, `${where}.${k}`);
};
for (const f of readdirSync(research).filter((f) => f.endsWith('.json'))) walk(JSON.parse(readFileSync(new URL(f, research), 'utf8')), f);

for (const f of readdirSync(research).filter((f) => /^damick-.*\.md$/.test(f))) {
  let cite = null;
  for (const line of readFileSync(new URL(f, research), 'utf8').split('\n')) {
    const events = [
      ...[...line.matchAll(CITE)].map((m) => ({ at: m.index, cite: m })),
      ...[...line.matchAll(/quote: "(.+?)"(?=[.,;)]?\s*$|\s*\|)/gi)].map((m) => ({ at: m.index, quote: m[1] })),
    ].sort((a, b) => a.at - b.at);
    for (const e of events) {
      if (e.cite) {
        cite = e.cite;
        continue;
      }
      quotes++;
      const h = cite && heading(cite[1], cite[2]);
      const sec = h && section(cite[1], h);
      if (!sec) problems.push(`${f}: quote without a valid citation before it: "${e.quote}"`);
      else if (!contains(sec, e.quote)) problems.push(`${f}: Damick ${cite[1]}: ${h}: quote not found: "${e.quote}"`);
    }
  }
}
console.log(`${cites} Damick citations, ${quotes} log quotes checked`);
if (problems.length) {
  console.log(problems.join('\n'));
  process.exitCode = 1;
}
