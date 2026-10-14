// The data and the relationships between nodes, shared by every view.

import rawNodes from './data/nodes.json';
import type { HistoryNode } from './types';
import {
  EUCHARIST,
  EUCHARIST_OF,
  FAMILIES,
  FAMILY_OF,
  FIRST_YEAR,
  NOW,
  SHORT_NAME,
  SIMPLE_MARKERS,
  SIMPLE_ORDER,
  SIMPLE_TRADITIONS,
  TRUNK,
} from './layout';

export const nodes = rawNodes as HistoryNode[];
export const byId = new Map(nodes.map((n) => [n.id, n]));

export const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
export const nameOf = (n: HistoryNode) => SHORT_NAME[n.id] ?? n.name;
export const isTradId = (id: string | undefined) => !!id && byId.get(id)?.type === 'tradition';
export const clampYear = (y: number) => Math.min(NOW, Math.max(FIRST_YEAR, y));

export const KIND_TEXT: Record<string, string> = {
  tradition: 'Tradition',
  council: 'Council',
  schism: 'Split',
  event: 'Event',
  figure: 'Person',
};

export const yearText = (n: HistoryNode) => {
  if (n.type === 'tradition') return n.end == null ? `${n.start} to today` : `${n.start} to ${n.end}`;
  if (n.end != null && n.end !== n.start) return `${n.start} to ${n.end}`;
  return String(n.start);
};

/** The traditions offered in "My church" and the sacraments grid, in map order. */
export const CHOICES = SIMPLE_ORDER.filter((id) => id !== '__trunk__');

// ---------------------------------------------------------------------------
// Detail level. The simple view shows the big families and moments only.

const SIMPLE_SET = new Set([...SIMPLE_TRADITIONS, ...SIMPLE_MARKERS]);
const ALL_SET = new Set(nodes.map((n) => n.id));
export const visibleSet = (simple: boolean) => (simple ? SIMPLE_SET : ALL_SET);

/** Nearest ancestor that is drawn at this detail level. */
export function parentIn(t: HistoryNode, visible: Set<string>) {
  let p = t.parents?.find(isTradId);
  const seen = new Set<string>();
  while (p && !visible.has(p) && !seen.has(p)) {
    seen.add(p);
    p = byId.get(p)!.parents?.find(isTradId);
  }
  return p && visible.has(p) ? p : undefined;
}

/** The line from Jesus down to this tradition, oldest first. */
export function lineageIn(id: string, visible: Set<string>) {
  const line = [id];
  let cur = byId.get(id);
  while (cur) {
    const p = parentIn(cur, visible);
    if (!p || line.includes(p)) break;
    line.unshift(p);
    cur = byId.get(p);
  }
  return line;
}

export function childrenIn(visible: Set<string>, simple: boolean) {
  const out = new Map<string, string[]>();
  for (const t of nodes) {
    if (t.type !== 'tradition' || !visible.has(t.id)) continue;
    const p = parentIn(t, visible);
    const all = simple ? (p ? [p] : []) : (t.parents ?? []).filter((id) => isTradId(id) && visible.has(id));
    for (const id of all) {
      if (!out.has(id)) out.set(id, []);
      out.get(id)!.push(t.id);
    }
  }
  return out;
}

export function descendantsIn(id: string, children: Map<string, string[]>, acc = new Set<string>()) {
  for (const c of children.get(id) ?? []) {
    if (acc.has(c)) continue;
    acc.add(c);
    descendantsIn(c, children, acc);
  }
  return acc;
}

/** Councils and splits on the simple map that happened while this line ran through each step. */
export function momentsOn(ids: string[]) {
  return SIMPLE_MARKERS.map((id) => byId.get(id)!).filter((m) => {
    const i = ids.indexOf(m.on ?? '');
    if (i < 0) return false;
    const next = ids[i + 1] ? byId.get(ids[i + 1])!.start : Infinity;
    return m.start <= next;
  });
}

// ---------------------------------------------------------------------------
// Color

export type Mode = 'plain' | 'family' | 'eucharist';

function inherit(map: Record<string, string>, t: HistoryNode, fallback: string) {
  let cur: HistoryNode | undefined = t;
  const seen = new Set<string>();
  while (cur && !seen.has(cur.id)) {
    seen.add(cur.id);
    if (cur.outsideNicene) return 'outside';
    if (map[cur.id]) return map[cur.id];
    const p: string | undefined = cur.parents?.find(isTradId);
    cur = p ? byId.get(p) : undefined;
  }
  return fallback;
}
export const familyKey = (t: HistoryNode) => inherit(FAMILY_OF, t, 'catholic');
export const eucharistKey = (t: HistoryNode) => inherit(EUCHARIST_OF, t, 'memorial');

export const INK = '#151515';
export const ACCENT = '#d63d22';
export const COUNCIL = '#151515';
export const SPLIT = '#151515';

// Distinct hues per tradition in the simple view so every line reads on its own.
const SIMPLE_COLOR: Record<string, string> = {
  'church-of-east': '#0e8a80',
  'oriental-orthodox': '#d17a1e',
  'eastern-orthodox': '#7a4fcf',
  catholic: '#b88a00',
  lutheran: '#2c6cd4',
  reformed: '#1797c9',
  anabaptist: '#2f9447',
  anglican: '#c2408a',
  methodist: '#d1405a',
  pentecostal: '#e2701b',
  baptist: '#0f8fa0',
  'evangelical-nondenom': '#8a6a2e',
};

/** A tradition's own color, used by the family and communion modes and by the emblems. */
export function hueOf(t: HistoryNode, mode: Mode = 'family') {
  if (mode === 'eucharist') return EUCHARIST[eucharistKey(t)].color;
  if (TRUNK.includes(t.id)) return FAMILIES.early.color;
  return SIMPLE_COLOR[t.id] ?? FAMILIES[familyKey(t)].color;
}

/** Color for any node in the side panel and chips. */
export function nodeColor(n: HistoryNode, mode: Mode = 'family') {
  if (n.type === 'tradition') return hueOf(n, mode === 'plain' ? 'family' : mode);
  if (n.type === 'council') return COUNCIL;
  if (n.type === 'schism') return SPLIT;
  return '#8a8a8a';
}

// ---------------------------------------------------------------------------
// Book citations

/** Book citations are stored as "Pelikan <vol>:<pages>", for example "Pelikan 2:146-157". */
export const pelikanCite = (s: string) => {
  const m = /^Pelikan ([1-5]):(\d+(?:-\d+)?)$/.exec(s);
  if (!m) return null;
  return `Pelikan, <i>The Christian Tradition</i>, vol. ${m[1]}, ${m[2].includes('-') ? 'pp.' : 'p.'} ${m[2]}`;
};
/** Damick has no page numbers, so citations name a chapter and section: "Damick ch3: Lutheranism". */
export const damickCite = (s: string) => {
  const m = /^Damick (intro|ch[1-8]|epilogue|appendix[1-4]): (.+)$/.exec(s);
  if (!m) return null;
  const part = m[1].replace(/^ch/, 'ch. ').replace(/^appendix/, 'appendix ').replace(/^intro$/, 'introduction');
  // Top-level section headings are in capitals in the book.
  const small = new Set(['a', 'an', 'and', 'as', 'at', 'for', 'in', 'of', 'on', 'or', 'the', 'to']);
  const title =
    m[2] === m[2].toUpperCase()
      ? m[2]
          .toLowerCase()
          .split(' ')
          .map((w, i) => (i > 0 && small.has(w) ? w : w.replace(/\p{L}/u, (c) => c.toUpperCase())))
          .join(' ')
      : m[2];
  return `Damick, <i>Orthodoxy and Heterodoxy</i>, ${part}, "${esc(title)}"`;
};

// ---------------------------------------------------------------------------
// "My church" is remembered between visits.

const STORE = 'church-history:my-church';
export function myChurch() {
  try {
    const id = localStorage.getItem(STORE);
    return id && byId.has(id) ? id : null;
  } catch {
    return null;
  }
}
export function rememberChurch(id: string | null) {
  try {
    if (id) localStorage.setItem(STORE, id);
    else localStorage.removeItem(STORE);
  } catch {
    /* private mode */
  }
}
