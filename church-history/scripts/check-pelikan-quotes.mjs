// Check the quotes in research/rebase-*.md against the local Pelikan text.
// Each quote follows a citation such as `Pelikan 2:183-187` and is written as
// "printed page 183", optional notes, a colon, then "..." or `...` | `...`.
// The quote must appear on that printed page of that volume. The scan puts
// margin notes between lines, so matching tolerates a few extra words.
// Usage: node scripts/check-pelikan-quotes.mjs [research/rebase-2.md ...]
import { readFileSync, readdirSync } from 'node:fs';

const research = new URL('../research/', import.meta.url);
const textDir = new URL('books/pelikan/text/', research);
const words = (s) => s.toLowerCase().replace(/[’‘]/g, "'").match(/[a-z0-9']+/g) ?? [];

// volume -> printed page -> words. Printed pages come from the running header,
// filled in from the PDF page offset where the scan garbled the header.
const vols = new Map();
for (const f of readdirSync(textDir)) {
  const vol = Number(/^vol(\d)/.exec(f)?.[1]);
  if (!vol) continue;
  const parts = readFileSync(new URL(f, textDir), 'utf8').split(/=== PDF page (\d+) ===/);
  const pages = [];
  for (let i = 1; i < parts.length; i += 2) {
    const head = parts[i + 1].split('\n').map((l) => l.trim()).find(Boolean) ?? '';
    const m = /(?:^|\s)(\d{1,3})$/.exec(head) ?? /^(\d{1,3})(?:\s|$)/.exec(head);
    pages.push({ pdf: Number(parts[i]), printed: m ? Number(m[1]) : null, text: parts[i + 1] });
  }
  const offsets = new Map();
  for (const p of pages) if (p.printed) offsets.set(p.pdf - p.printed, (offsets.get(p.pdf - p.printed) ?? 0) + 1);
  const offset = [...offsets].sort((a, b) => b[1] - a[1])[0][0];
  vols.set(vol, new Map(pages.map((p) => [p.pdf - offset, words(p.text)])));
}

// True if the quote's words appear in order, allowing small gaps for margin
// notes and words split across lines by hyphenation.
function found(quote, page) {
  const [first, ...rest] = words(quote);
  for (let start = 0; start < page.length; start++) {
    let i;
    if (page[start] === first) i = start + 1;
    else if (page[start] + page[start + 1] === first) i = start + 2;
    else continue;
    let ok = true;
    for (const w of rest) {
      let hit = -1;
      for (let j = i; j < Math.min(page.length, i + 10) && hit < 0; j++) {
        if (page[j] === w) hit = j + 1;
        // A word hyphenated across lines, possibly with a margin note between.
        else for (let k = j + 1; k < Math.min(page.length, j + 10) && hit < 0; k++) if (page[j] + page[k] === w) hit = k + 1;
      }
      if (hit < 0) {
        ok = false;
        break;
      }
      i = hit;
    }
    if (ok) return true;
  }
  return false;
}

const CITE = /`?Pelikan ([1-5]):(\d+)(?:-(\d+))?\b/g;
// Notes may sit between the page and the quote, as in: printed page 13. Fields checked: summary. Quote: "..."
const QUOTE = /printed page (\d+)[^"`]*?: (?=["`])/gi;
// The quotes in the text after a QUOTE marker, up to the next marker. Each
// result is a list of readings, any of which may match: a "..." span may be
// one quote with inner quotation marks, or several quotes joined by "and".
const quotesIn = (seg) => {
  if (seg[0] === '`') return [...seg.matchAll(/`([^`]+)`/g)].map((m) => [m[1]]);
  const whole = seg.slice(1, seg.lastIndexOf('"'));
  const parts = whole.split(/"(?:,| and| \|)? "/);
  return parts.length > 1 ? parts.map((p) => [p, whole]) : [[whole]];
};

const files = process.argv.slice(2).length
  ? process.argv.slice(2)
  : readdirSync(research).filter((f) => /^rebase-\d+\.md$/.test(f)).map((f) => `research/${f}`);
let total = 0;
const bad = [];
for (const f of files) {
  // A quote belongs to the nearest citation before it on the same or an earlier line.
  let cite = null;
  for (const line of readFileSync(f, 'utf8').split('\n')) {
    const marks = [...line.matchAll(QUOTE)];
    const events = [
      ...[...line.matchAll(CITE)].map((m) => ({ at: m.index, cite: m })),
      ...marks.map((m, k) => ({ at: m.index, quote: m, seg: line.slice(m.index + m[0].length, marks[k + 1]?.index) })),
    ].sort((x, y) => x.at - y.at);
    for (const e of events) {
      if (e.cite) {
        cite = e.cite;
        continue;
      }
      for (const readings of quotesIn(e.seg)) {
        total++;
        if (!cite) {
          bad.push(`${f}: quote with no citation before it: "${readings[0]}"`);
          continue;
        }
        const [, vol, from, to = from] = cite;
        const p = Number(e.quote[1]);
        const where = `${f}: Pelikan ${vol}:${from}${to !== from ? '-' + to : ''} p.${p}`;
        if (p < Number(from) || p > Number(to)) bad.push(`${where}: quoted page is outside the cited range`);
        // Allow one page either side for page breaks and header noise.
        const near = [p, p - 1, p + 1].map((n) => vols.get(Number(vol)).get(n) ?? []);
        if (!readings.some((q) => near.some((pg) => found(q, pg)))) bad.push(`${where}: quote not found: "${readings[0]}"`);
      }
    }
  }
}
console.log(`${total} quotes checked, ${bad.length} problems`);
if (bad.length) {
  console.log(bad.join('\n'));
  process.exitCode = 1;
}
