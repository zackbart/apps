// The flat map: time runs left to right and every tradition keeps its own lane.
// Drawn in SVG. The Map view can pan and zoom it, and the Story view drives it
// from the page's scroll position.

import type { HistoryNode } from './types';
import { FIRST_YEAR, LANE_ORDER, NOW, SIMPLE_ORDER, TRUNK } from './layout';
import { ACCENT, hueOf, INK, nameOf, nodes, parentIn, visibleSet, yearText, KIND_TEXT, type Mode } from './model';

const NS = 'http://www.w3.org/2000/svg';
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

// ---------------------------------------------------------------------------
// Time scale. Later centuries get more room because they hold more branches.

const SCALE: [number, number][] = [
  [FIRST_YEAR, 0.17],
  [1000, 0.21],
  [1500, 0.46],
];
export function rawX(year: number) {
  let x = 0;
  for (let i = 0; i < SCALE.length; i++) {
    const [from, k] = SCALE[i];
    const to = SCALE[i + 1]?.[0] ?? Infinity;
    if (year <= from) {
      if (i === 0) x += (year - from) * k;
      break;
    }
    x += (Math.min(year, to) - from) * k;
  }
  return x;
}
export function yearAtRaw(r: number) {
  let rem = r;
  for (let i = 0; i < SCALE.length; i++) {
    const [from, k] = SCALE[i];
    const to = SCALE[i + 1]?.[0] ?? Infinity;
    const span = (to - from) * k;
    if (rem <= span || i === SCALE.length - 1) return from + rem / k;
    rem -= span;
  }
  return NOW;
}
const R_MIN = rawX(FIRST_YEAR);
const R_MAX = rawX(NOW);

// ---------------------------------------------------------------------------

type State = 'lit' | 'normal' | 'dim';

interface Line {
  node: HistoryNode;
  parent?: string;
  path: SVGPathElement;
  hit: SVGPathElement;
  tip: SVGCircleElement;
  label?: SVGTextElement;
  y: number;
  /** Where the line starts, bends, and ends on screen, from the last render. */
  sx: number;
  ex: number;
  bend: number;
}
interface Mark {
  node: HistoryNode;
  host?: string;
  year: number;
  kind: 'council' | 'schism' | 'event';
  g: SVGGElement;
  dot: SVGCircleElement;
  label: SVGTextElement;
  y: number;
}

export interface Highlight {
  /** Lines and moments to bring forward. Everything else steps back. */
  lit?: Set<string> | null;
  selected?: string | null;
  /** The reader's own church line, drawn in the accent without dimming the rest. */
  personal?: Set<string> | null;
}

export interface MapOptions {
  interactive: boolean;
  onSelect: (id: string | null) => void;
  /** Called when the reader pans or zooms by hand. */
  onMove?: () => void;
}

const el = <K extends keyof SVGElementTagNameMap>(tag: K, attrs: Record<string, string | number> = {}, parent?: Element) => {
  const e = document.createElementNS(NS, tag);
  for (const k in attrs) e.setAttribute(k, String(attrs[k]));
  parent?.appendChild(e);
  return e;
};

let measureCtx: CanvasRenderingContext2D | null = null;
function textWidth(text: string, font: string) {
  measureCtx ??= document.createElement('canvas').getContext('2d')!;
  measureCtx.font = font;
  return measureCtx.measureText(text).width;
}
const FONT_LINE = '600 12.5px Inter, system-ui, sans-serif';
const FONT_MINOR = '500 11.5px Inter, system-ui, sans-serif';
const FONT_MARK = '500 11.5px Inter, system-ui, sans-serif';

const ease = (k: number) => 1 - Math.pow(1 - k, 3);

export class FlatMap {
  readonly root: HTMLElement;
  readonly svg: SVGSVGElement;
  private gGrid: SVGGElement;
  private gLines: SVGGElement;
  private gMarks: SVGGElement;
  private gLabels: SVGGElement;
  private opts: MapOptions;

  simple = true;
  mode: Mode = 'plain';
  private visible = visibleSet(true);
  private lines: Line[] = [];
  private lineById = new Map<string, Line>();
  private marks: Mark[] = [];
  private laneY = new Map<string, number>();
  private offRowY = 0;
  /** Only lines that exist by this year get a lane. The Story view raises it chapter by chapter. */
  private cutoff = NOW;
  private laneAnim: { from: Map<string, number>; to: Map<string, number>; offFrom: number; offTo: number; t0: number; dur: number } | null = null;

  /** Visible span of time, in scaled units. */
  private r0 = R_MIN;
  private r1 = R_MAX;
  private tween: { from: [number, number]; to: [number, number]; t0: number; dur: number } | null = null;
  /** Lines and moments after this year are not drawn yet. */
  reveal = NOW;
  /** Moments inside this span get labels. Used by the Story view. */
  focus: [number, number] | null = null;
  private hl: Highlight = {};

  private w = 0;
  private h = 0;
  private raf = 0;

  constructor(root: HTMLElement, opts: MapOptions) {
    this.root = root;
    this.opts = opts;
    this.svg = el('svg', { class: 'flatmap', role: 'img' }) as SVGSVGElement;
    this.svg.setAttribute('aria-label', 'Map of church traditions from Jesus to today');
    this.gGrid = el('g', { class: 'grid' }, this.svg);
    this.gLines = el('g', { class: 'lines' }, this.svg);
    this.gMarks = el('g', { class: 'marks' }, this.svg);
    this.gLabels = el('g', { class: 'labels' }, this.svg);
    root.appendChild(this.svg);
    new ResizeObserver(() => this.resize()).observe(root);
    this.bindPointer();
    this.build();
    // Label widths are measured with the web font, so measure again once it has loaded.
    document.fonts?.ready.then(() => {
      this.tipRoom.key = '';
      this.render();
    });
  }

  // -------------------------------------------------------------------------
  // Building

  setSimple(simple: boolean) {
    if (this.simple === simple) return;
    this.simple = simple;
    this.build();
  }

  private build() {
    this.visible = visibleSet(this.simple);
    for (const g of [this.gLines, this.gMarks, this.gLabels]) g.replaceChildren();
    this.lines = [];
    this.lineById = new Map();
    this.marks = [];

    const traditions = nodes.filter((n) => n.type === 'tradition' && this.visible.has(n.id)).sort((a, b) => a.start - b.start);
    for (const t of traditions) {
      const g = el('g', { class: 'line', 'data-id': t.id }, this.gLines);
      const hit = el('path', { class: 'hit', 'data-id': t.id }, g);
      const path = el('path', { class: 'stroke' }, g);
      const tip = el('circle', { class: 'tip', r: 2.6 }, g);
      el('title', {}, g).textContent = `${nameOf(t)}, ${yearText(t)}`;
      const line: Line = { node: t, parent: parentIn(t, this.visible), path, hit, tip, y: 0, sx: 0, ex: 0, bend: 0 };
      // The trunk is one line in three parts. Only its first part is named.
      if (!TRUNK.includes(t.id) || t.id === 'apostolic') {
        line.label = el('text', { class: 'line-label', 'data-id': t.id }, this.gLabels) as SVGTextElement;
        line.label.textContent = nameOf(t);
      }
      this.lines.push(line);
      this.lineById.set(t.id, line);
    }

    const moments = nodes.filter((n) => n.type !== 'tradition' && this.visible.has(n.id));
    for (const m of moments) {
      const kind: Mark['kind'] = m.type === 'council' ? 'council' : m.type === 'schism' ? 'schism' : 'event';
      const host = m.on && this.visible.has(m.on) ? m.on : m.on ? parentIn({ ...m, parents: [m.on] }, this.visible) : undefined;
      const span = m.end != null && m.end - m.start >= 15;
      const year = m.type === 'figure' && span ? Math.round((m.start + (m.end as number)) / 2) : m.start;
      const g = el('g', { class: `mark ${kind}`, 'data-id': m.id }, this.gMarks);
      el('circle', { class: 'hit', r: 10, 'data-id': m.id }, g);
      const dot = el('circle', { class: 'dot', r: kind === 'council' ? 4.6 : kind === 'schism' ? 5.4 : 3.2, 'data-id': m.id }, g);
      el('title', {}, g).textContent = `${nameOf(m)}, ${yearText(m)} (${KIND_TEXT[m.type].toLowerCase()})`;
      const label = el('text', { class: `mark-label ${kind}`, 'data-id': m.id }, this.gLabels) as SVGTextElement;
      label.textContent = nameOf(m);
      el('tspan', { class: 'yr', dx: 4 }, label).textContent = m.type === 'figure' ? '' : String(m.start);
      this.marks.push({ node: m, host, year, kind, g, dot, label, y: 0 });
    }
    this.layoutLanes();
    this.render();
  }

  private layoutLanes(animate = false) {
    const order = [...(this.simple ? SIMPLE_ORDER : LANE_ORDER)];
    const insertedUnder = new Map<string, string>();
    for (const { node: t, parent } of this.lines) {
      if (TRUNK.includes(t.id) || order.includes(t.id)) continue;
      const p = parent ?? 'catholic';
      const anchor = TRUNK.includes(p) ? '__trunk__' : p;
      let i = order.indexOf(anchor);
      if (i < 0) i = order.length - 1;
      let j = i + 1;
      while (j < order.length && insertedUnder.get(order[j]) === anchor) j++;
      order.splice(j, 0, t.id);
      insertedUnder.set(t.id, anchor);
    }
    const present = order.filter((id) => id === '__trunk__' || (this.visible.has(id) && this.lineById.get(id)!.node.start <= this.cutoff));
    const top = 30;
    const bottom = 44;
    const avail = Math.max(100, this.h - top - bottom);
    const max = this.simple ? (present.length < 8 ? 64 : 52) : 26;
    const gap = Math.min(max, Math.max(this.simple ? 24 : 13, avail / (present.length + 0.1)));
    const used = gap * (present.length - 1);
    const y0 = top + Math.max(0, (avail - used) / 2) - gap * 0.2;
    const target = new Map(present.map((id, i) => [id, y0 + i * gap]));
    // Lines without a lane yet wait on their parent's lane, so they grow out of it later.
    for (const l of this.lines) if (!target.has(l.node.id) && !TRUNK.includes(l.node.id)) target.set(l.node.id, this.laneIn(target, l.parent));
    const offRow = y0 + used + gap * 0.75;
    const needed = offRow + bottom;
    // A long list of lanes can be taller than the screen. Then the map scrolls down.
    this.svg.style.height = needed > this.h + 4 ? `${Math.ceil(needed)}px` : '';
    if (animate && !reduceMotion && this.laneY.size) {
      this.laneAnim = { from: new Map(this.laneY), to: target, offFrom: this.offRowY, offTo: offRow, t0: performance.now(), dur: 650 };
      this.schedule();
    } else {
      this.laneAnim = null;
      this.laneY = target;
      this.offRowY = offRow;
    }
  }
  private laneIn(map: Map<string, number>, id: string | undefined): number {
    if (!id || TRUNK.includes(id)) return map.get('__trunk__')!;
    return map.get(id) ?? this.laneIn(map, this.lineById.get(id)?.parent);
  }
  private laneOf(id: string) {
    return TRUNK.includes(id) ? this.laneY.get('__trunk__')! : this.laneY.get(id) ?? this.laneY.get('__trunk__')!;
  }

  private resize() {
    const w = this.root.clientWidth;
    const h = this.root.clientHeight;
    if (!w || !h || (w === this.w && h === this.h)) return;
    this.w = w;
    this.h = h;
    this.layoutLanes();
    this.render();
  }

  // -------------------------------------------------------------------------
  // State

  setMode(mode: Mode) {
    this.mode = mode;
    this.render();
  }
  setHighlight(hl: Highlight) {
    this.hl = hl;
    this.render();
  }
  setReveal(year: number) {
    if (Math.abs(year - this.reveal) < 0.5) return;
    this.reveal = year;
    this.schedule();
  }
  setFocus(range: [number, number] | null) {
    this.focus = range;
    this.schedule();
  }

  get domain(): [number, number] {
    return [yearAtRaw(this.r0), yearAtRaw(this.r1)];
  }
  /**
   * Show this span of years. A little room is added on each side. With a cutoff,
   * only lines that exist by that year get lanes.
   */
  setDomain(from: number, to: number, animate = true, cutoff = NOW) {
    if (cutoff !== this.cutoff) {
      this.cutoff = cutoff;
      this.layoutLanes(animate && !!this.w);
    }
    const pad = (rawX(to) - rawX(from)) * 0.04;
    const target = this.clampR(rawX(from) - pad, rawX(to) + pad);
    if (!animate || reduceMotion || !this.w) {
      this.tween = null;
      [this.r0, this.r1] = target;
      this.render();
      return;
    }
    this.tween = { from: [this.r0, this.r1], to: target, t0: performance.now(), dur: 650 };
    this.schedule();
  }
  /** Pan just enough to bring a year into view. */
  showYear(year: number) {
    const r = rawX(year);
    const span = this.r1 - this.r0;
    const inner = span * 0.08;
    if (r >= this.r0 + inner && r <= this.r1 - inner) return;
    const t = this.clampR(r - span / 2, r + span / 2);
    this.tween = { from: [this.r0, this.r1], to: t, t0: performance.now(), dur: 500 };
    this.schedule();
  }
  private clampR(a: number, b: number): [number, number] {
    const lo = R_MIN - 4;
    const hi = R_MAX + 2;
    const minSpan = 16;
    let span = Math.max(minSpan, Math.min(hi - lo, b - a));
    let c = (a + b) / 2;
    c = Math.max(lo + span / 2, Math.min(hi - span / 2, c));
    span = Math.min(span, hi - lo);
    return [c - span / 2, c + span / 2];
  }

  private schedule() {
    if (this.raf) return;
    this.raf = requestAnimationFrame((now) => {
      this.raf = 0;
      if (this.tween) {
        const k = Math.min(1, (now - this.tween.t0) / this.tween.dur);
        const e = ease(k);
        this.r0 = this.tween.from[0] + (this.tween.to[0] - this.tween.from[0]) * e;
        this.r1 = this.tween.from[1] + (this.tween.to[1] - this.tween.from[1]) * e;
        if (k >= 1) this.tween = null;
        else this.schedule();
      }
      if (this.laneAnim) {
        const a = this.laneAnim;
        const k = Math.min(1, (now - a.t0) / a.dur);
        const e = ease(k);
        for (const [id, to] of a.to) {
          const from = a.from.get(id) ?? to;
          this.laneY.set(id, from + (to - from) * e);
        }
        this.offRowY = a.offFrom + (a.offTo - a.offFrom) * e;
        if (k >= 1) this.laneAnim = null;
        else this.schedule();
      }
      this.render();
    });
  }

  // -------------------------------------------------------------------------
  // Drawing

  private tipRoom = { key: '', px: 150 };
  private get labelRoom() {
    if (this.domain[1] < NOW - 5) return 16;
    // Living lines are named at their tips, so the right edge keeps room for the longest name.
    const key = `${this.simple}:${this.w}`;
    if (this.tipRoom.key !== key) {
      const widest = Math.max(
        ...this.lines
          .filter((l) => l.label && l.node.end == null)
          .map((l) => textWidth(l.label!.textContent!, !this.simple && l.node.importance > 1 ? FONT_MINOR : FONT_LINE)),
      );
      this.tipRoom = { key, px: Math.min(Math.max(widest + 16, 90), this.w * 0.34) };
    }
    return this.tipRoom.px;
  }
  private X(year: number) {
    const left = 16;
    const right = this.w - this.labelRoom;
    return left + ((rawX(year) - this.r0) / (this.r1 - this.r0)) * (right - left);
  }

  private stateOf(ids: string[]): State {
    const { lit, personal } = this.hl;
    if (lit) return ids.some((id) => lit.has(id)) ? 'lit' : 'dim';
    if (personal && ids.some((id) => personal.has(id))) return 'lit';
    return 'normal';
  }

  private strokeFor(t: HistoryNode, state: State) {
    if (this.mode === 'plain') {
      if (state === 'lit') return ACCENT;
      if (state === 'dim') return '#dcdcdc';
      return TRUNK.includes(t.id) ? '#3a3a3a' : '#8e8e8e';
    }
    return hueOf(t, this.mode);
  }

  render() {
    if (!this.w || !this.h) return;
    const reveal = this.reveal;
    const plotLeft = 16;
    const plotRight = this.w - this.labelRoom;
    const boxes: [number, number, number, number][] = [];
    const free = (b: [number, number, number, number]) =>
      b[0] >= -2 && b[2] <= this.w + 2 && !boxes.some((o) => b[0] < o[2] && b[2] > o[0] && b[1] < o[3] && b[3] > o[1]);
    const take = (b: [number, number, number, number]) => boxes.push(b);
    const { selected } = this.hl;

    // Grid: hairlines at round years, labeled along the bottom.
    this.gGrid.replaceChildren();
    const [y0, y1] = this.domain;
    const span = y1 - y0;
    const step = [10, 25, 50, 100, 250, 500].find((s) => span / s <= (this.w < 560 ? 4 : 8)) ?? 500;
    const gridBottom = this.offRowY + 22;
    const years: number[] = [];
    for (let y = Math.ceil(Math.max(y0, 0) / step) * step; y <= Math.min(y1, NOW); y += step) if (y > FIRST_YEAR + step * 0.3) years.push(y);
    const tick = (year: number, text: string, cls = '') => {
      const x = this.X(year);
      el('line', { x1: x, x2: x, y1: 8, y2: gridBottom - 14, class: `hair ${cls}` }, this.gGrid);
      const t = el('text', { x, y: gridBottom, class: `tick ${cls}`, 'text-anchor': 'middle' }, this.gGrid);
      t.textContent = text;
    };
    if (y0 <= FIRST_YEAR + 1) tick(FIRST_YEAR, 'AD 30', 'edge');
    for (const y of years) if (y < NOW - step * 0.3) tick(y, String(y));
    if (y1 >= NOW - 1) tick(NOW, 'Today', 'edge now');
    if (reveal < NOW && reveal >= y0 && reveal <= y1) {
      const x = this.X(reveal);
      el('line', { x1: x, x2: x, y1: 8, y2: gridBottom - 14, class: 'reveal' }, this.gGrid);
    }

    // Lines.
    for (const l of this.lines) l.y = this.laneOf(l.node.id);
    const tipLabels: Line[] = [];
    const startLabels: Line[] = [];
    for (const l of this.lines) {
      const t = l.node;
      const shown = t.start <= reveal;
      l.path.parentElement!.style.display = shown ? '' : 'none';
      if (l.label) l.label.style.display = 'none';
      if (!shown) continue;
      const sx = this.X(t.start);
      const endYear = Math.min(t.end ?? NOW, reveal);
      const ex = Math.max(sx + 0.5, this.X(endYear));
      const p = l.parent;
      const py = p ? this.lineById.get(p)!.y : l.y;
      const bend = Math.abs(py - l.y) < 0.5 ? 0 : Math.min(30, Math.max(10, Math.abs(py - l.y) * 0.6));
      const d = bend
        ? `M${sx} ${py}C${sx + bend * 0.55} ${py} ${sx + bend * 0.45} ${l.y} ${sx + bend} ${l.y}L${Math.max(ex, sx + bend)} ${l.y}`
        : `M${sx} ${l.y}L${ex} ${l.y}`;
      l.path.setAttribute('d', d);
      l.hit.setAttribute('d', d);
      const state = this.stateOf([t.id]);
      const imp = TRUNK.includes(t.id) ? 0 : this.simple ? 1 : t.importance;
      const width = (imp === 0 ? 4 : imp === 1 ? 2.6 : imp === 2 ? 1.7 : 1.2) + (state === 'lit' ? 1.2 : 0);
      const color = this.strokeFor(t, state);
      l.path.setAttribute('stroke', color);
      l.path.setAttribute('stroke-width', String(width));
      l.path.setAttribute('opacity', this.mode !== 'plain' && state === 'dim' ? '0.2' : t.outsideNicene ? '0.6' : '1');
      if (t.outsideNicene) l.path.setAttribute('stroke-dasharray', '5 3');
      else l.path.removeAttribute('stroke-dasharray');
      l.path.parentElement!.classList.toggle('selected', selected === t.id);
      // A dot at the tip while the line is still growing.
      const growing = (t.end == null || t.end > reveal) && reveal < NOW;
      l.tip.style.display = growing ? '' : 'none';
      if (growing) {
        l.tip.setAttribute('cx', String(ex));
        l.tip.setAttribute('cy', String(l.y));
        l.tip.setAttribute('fill', color);
      }
      l.sx = sx;
      l.ex = ex;
      l.bend = bend;
      if (!l.label) continue;
      l.label.setAttribute('fill', state === 'lit' && this.mode === 'plain' ? ACCENT : state === 'dim' ? '#b4b4b4' : INK);
      l.label.classList.toggle('minor', !this.simple && t.importance > 1);
      l.label.classList.toggle('strong', state === 'lit');
      const living = t.end == null || t.end > reveal;
      if (t.id !== 'apostolic' && living && ex <= plotRight + 2 && ex >= plotLeft) tipLabels.push(l);
      else startLabels.push(l);
    }

    // Tip labels first: they are the main way to tell lines apart.
    const order = (a: Line, b: Line) => this.rank(a.node) - this.rank(b.node);
    for (const l of tipLabels.sort(order)) {
      const ex = l.ex;
      const font = l.label!.classList.contains('minor') ? FONT_MINOR : FONT_LINE;
      const w = textWidth(l.label!.textContent!, font);
      const b: [number, number, number, number] = [ex + 6, l.y - 8, ex + 8 + w, l.y + 6];
      // A name that does not fit at the tip goes at the start of the line instead.
      if (!free(b) && selected !== l.node.id) {
        startLabels.push(l);
        continue;
      }
      take(b);
      l.label!.setAttribute('x', String(ex + 7));
      l.label!.setAttribute('y', String(l.y + 4));
      l.label!.style.display = '';
    }

    // Moments. Their labels compete with the start labels of lines, by importance.
    const markLabels: { m: Mark; x: number }[] = [];
    for (const m of this.marks) {
      const shown = m.year <= reveal;
      m.g.style.display = shown ? '' : 'none';
      m.label.style.display = 'none';
      if (!shown) continue;
      const host = m.host ? this.lineById.get(m.host) : undefined;
      const onHost = host && m.year <= (host.node.end ?? NOW) + 5 && m.year >= host.node.start - 5;
      m.y = onHost ? host!.y : this.offRowY;
      const x = this.X(m.year);
      m.g.setAttribute('transform', `translate(${x} ${m.y})`);
      const lit = this.hl.lit;
      const touches = (set: Set<string>) =>
        set.has(m.host ?? '') || set.has(m.node.on ?? '') || (m.node.splits ?? []).some((id) => set.has(id));
      const state: State = selected === m.node.id ? 'lit' : lit ? (touches(lit) ? 'lit' : 'dim') : 'normal';
      const inFocus = !this.focus || (m.year >= this.focus[0] && m.year <= this.focus[1]);
      m.g.classList.toggle('dim', state === 'dim' || !inFocus);
      m.g.classList.toggle('selected', selected === m.node.id);
      if (x < plotLeft - 4 || x > this.w) continue;
      if (inFocus && state !== 'dim') markLabels.push({ m, x });
      else if (selected === m.node.id) markLabels.push({ m, x });
    }
    const all: ({ kind: 'mark'; m: Mark; x: number; r: number } | { kind: 'start'; l: Line; r: number })[] = [
      ...markLabels.map((o) => ({ kind: 'mark' as const, ...o, r: this.rank(o.m.node) })),
      ...startLabels.map((l) => ({ kind: 'start' as const, l, r: this.rank(l.node) - (l.node.id === 'apostolic' ? 10 : 0) })),
    ].sort((a, b) => a.r - b.r);
    for (const item of all) {
      if (item.kind === 'mark') {
        const { m, x } = item;
        // The year sits 4px after the name.
        const w = textWidth(m.label.textContent!, FONT_MARK) + 6;
        const above: [number, number, number, number] = [x - w / 2 - 2, m.y - 22, x + w / 2 + 2, m.y - 8];
        const below: [number, number, number, number] = [x - w / 2 - 2, m.y + 9, x + w / 2 + 2, m.y + 23];
        const b = free(above) ? above : free(below) ? below : selected === m.node.id ? above : null;
        if (!b) continue;
        take(b);
        m.label.setAttribute('x', String(x));
        m.label.setAttribute('text-anchor', 'middle');
        m.label.setAttribute('y', String(b === above ? m.y - 11 : m.y + 20));
        m.label.style.display = '';
      } else {
        const l = item.l;
        const font = l.label!.classList.contains('minor') ? FONT_MINOR : FONT_LINE;
        const w = textWidth(l.label!.textContent!, font);
        // Skip lines that are not on screen at all.
        if (this.X(l.node.end ?? NOW) < plotLeft + 20 || l.sx > this.w) continue;
        const lx = Math.max(l.sx + l.bend + 4, plotLeft + 2);
        const b: [number, number, number, number] = [lx - 1, l.y - 18, lx + w + 2, l.y - 4];
        if (!free(b) && selected !== l.node.id) continue;
        take(b);
        l.label!.setAttribute('x', String(lx));
        l.label!.setAttribute('y', String(l.y - 7));
        l.label!.style.display = '';
      }
    }
  }

  /** Lower ranks win label space. */
  private rank(n: HistoryNode) {
    if (n.id === this.hl.selected) return -100;
    let r = n.importance * 10;
    if (this.hl.lit?.has(n.id) || this.hl.personal?.has(n.id)) r -= 15;
    if (n.type === 'tradition') r -= 3;
    else if (n.type === 'council' || n.type === 'schism') r -= 1;
    return r + n.start / 10000;
  }

  // -------------------------------------------------------------------------
  // Input

  private bindPointer() {
    const svg = this.svg;
    const pts = new Map<number, { x: number; y: number }>();
    let drag: { x: number; r0: number; r1: number; moved: boolean } | null = null;
    let pinch: { d: number; mid: number; r0: number; r1: number } | null = null;

    const rAt = (clientX: number) => {
      const rect = svg.getBoundingClientRect();
      const left = 16;
      const right = this.w - this.labelRoom;
      return this.r0 + ((clientX - rect.left - left) / (right - left)) * (this.r1 - this.r0);
    };
    const zoomAt = (clientX: number, factor: number) => {
      const r = rAt(clientX);
      this.tween = null;
      [this.r0, this.r1] = this.clampR(r - (r - this.r0) * factor, r + (this.r1 - r) * factor);
      this.schedule();
    };
    const pxToR = () => (this.r1 - this.r0) / Math.max(1, this.w - this.labelRoom - 16);

    svg.addEventListener(
      'wheel',
      (e) => {
        if (!this.opts.interactive) return;
        const horizontal = Math.abs(e.deltaX) > Math.abs(e.deltaY);
        // Plain vertical scrolling moves a tall map up and down instead of zooming.
        if (!e.ctrlKey && !horizontal && this.svg.clientHeight > this.root.clientHeight + 8 && !e.altKey) return;
        e.preventDefault();
        if (horizontal && !e.ctrlKey) {
          this.tween = null;
          const dr = e.deltaX * pxToR();
          [this.r0, this.r1] = this.clampR(this.r0 + dr, this.r1 + dr);
          this.schedule();
        } else {
          const k = e.deltaMode === 1 ? 20 : 1;
          zoomAt(e.clientX, Math.exp(e.deltaY * k * (e.ctrlKey ? 0.01 : 0.0022)));
        }
        this.opts.onMove?.();
      },
      { passive: false },
    );

    svg.addEventListener('pointerdown', (e) => {
      pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (!this.opts.interactive) {
        drag = { x: e.clientX, r0: this.r0, r1: this.r1, moved: false };
        return;
      }
      if (pts.size === 1) drag = { x: e.clientX, r0: this.r0, r1: this.r1, moved: false };
      if (pts.size === 2) {
        const [a, b] = [...pts.values()];
        pinch = { d: Math.abs(a.x - b.x) || 1, mid: (a.x + b.x) / 2, r0: this.r0, r1: this.r1 };
        if (drag) drag.moved = true;
      }
    });
    svg.addEventListener('pointermove', (e) => {
      if (!pts.has(e.pointerId)) return;
      pts.set(e.pointerId, { x: e.clientX, y: e.clientY });
      if (!this.opts.interactive) {
        if (drag && Math.abs(e.clientX - drag.x) > 6) drag.moved = true;
        return;
      }
      if (pinch && pts.size >= 2) {
        const [a, b] = [...pts.values()];
        const d = Math.abs(a.x - b.x) || 1;
        const rect = svg.getBoundingClientRect();
        const left = 16;
        const right = this.w - this.labelRoom;
        const k = (pinch.mid - rect.left - left) / (right - left);
        const span = ((pinch.r1 - pinch.r0) * pinch.d) / d;
        const anchor = pinch.r0 + k * (pinch.r1 - pinch.r0);
        const mid = ((a.x + b.x) / 2 - pinch.mid) * ((pinch.r1 - pinch.r0) / (right - left));
        this.tween = null;
        [this.r0, this.r1] = this.clampR(anchor - k * span - mid, anchor + (1 - k) * span - mid);
        this.schedule();
        this.opts.onMove?.();
        return;
      }
      if (!drag) return;
      const dx = e.clientX - drag.x;
      if (!drag.moved && Math.abs(dx) < 5) return;
      if (!drag.moved) svg.setPointerCapture(e.pointerId);
      drag.moved = true;
      svg.classList.add('dragging');
      this.opts.onMove?.();
      const dr = -dx * ((drag.r1 - drag.r0) / Math.max(1, this.w - this.labelRoom - 16));
      this.tween = null;
      [this.r0, this.r1] = this.clampR(drag.r0 + dr, drag.r1 + dr);
      this.schedule();
    });
    const end = (e: PointerEvent) => {
      const wasTap = drag && !drag.moved && pts.size === 1;
      pts.delete(e.pointerId);
      if (pts.size < 2) pinch = null;
      svg.classList.remove('dragging');
      if (e.type === 'pointerup' && wasTap) {
        const id = (e.target as Element).closest('[data-id]')?.getAttribute('data-id') ?? null;
        this.opts.onSelect(id);
      }
      if (pts.size === 0) drag = null;
    };
    svg.addEventListener('pointerup', end);
    svg.addEventListener('pointercancel', end);

    svg.addEventListener('pointerover', (e) => {
      const id = (e.target as Element).closest('[data-id]')?.getAttribute('data-id');
      svg.querySelectorAll('.hover').forEach((n) => n.classList.remove('hover'));
      if (id) svg.querySelectorAll(`[data-id="${CSS.escape(id)}"]`).forEach((n) => n.closest('g.line, g.mark, text')?.classList.add('hover'));
    });
    svg.addEventListener('pointerleave', () => svg.querySelectorAll('.hover').forEach((n) => n.classList.remove('hover')));
  }

  /** Keyboard control for the Map view: arrows pan, plus and minus zoom. */
  key(e: KeyboardEvent) {
    const span = this.r1 - this.r0;
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      const dr = span * 0.15 * (e.key === 'ArrowLeft' ? -1 : 1);
      this.tween = { from: [this.r0, this.r1], to: this.clampR(this.r0 + dr, this.r1 + dr), t0: performance.now(), dur: 220 };
    } else if (e.key === '+' || e.key === '=' || e.key === '-') {
      const k = e.key === '-' ? 1.4 : 1 / 1.4;
      const c = (this.r0 + this.r1) / 2;
      this.tween = { from: [this.r0, this.r1], to: this.clampR(c - (span * k) / 2, c + (span * k) / 2), t0: performance.now(), dur: 220 };
    } else return false;
    this.schedule();
    this.opts.onMove?.();
    return true;
  }
}
