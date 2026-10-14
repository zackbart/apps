import './style.css';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { CSS2DObject, CSS2DRenderer } from 'three/examples/jsm/renderers/CSS2DRenderer.js';
import rawNodes from './data/nodes.json';
import type { HistoryNode } from './types';
import { EMBLEMS } from './emblems';
import { bindChurch, bindSacraments, renderChurch, renderSacraments, type ScreenDeps } from './screens';
import {
  CHAPTERS,
  EUCHARIST,
  EUCHARIST_OF,
  FAMILIES,
  FAMILY_OF,
  FIRST_YEAR,
  LANE_ORDER,
  NOW,
  SHORT_NAME,
  SIMPLE_MARKERS,
  SIMPLE_ORDER,
  SIMPLE_TRADITIONS,
  TRUNK,
} from './layout';

const nodes = rawNodes as HistoryNode[];
const byId = new Map(nodes.map((n) => [n.id, n]));
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
// Phones get their own layout: narrow screens, and short landscape ones. These match style.css.
const phoneQuery = matchMedia('(max-width: 820px), (max-height: 520px)');
const sideSheetQuery = matchMedia('(max-height: 520px) and (min-width: 560px)');

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
/** Book citations are stored as "Pelikan <vol>:<pages>", for example "Pelikan 2:146-157". */
const pelikanCite = (s: string) => {
  const m = /^Pelikan ([1-5]):(\d+(?:-\d+)?)$/.exec(s);
  if (!m) return null;
  return `Pelikan, <i>The Christian Tradition</i>, vol. ${m[1]}, ${m[2].includes('-') ? 'pp.' : 'p.'} ${m[2]}`;
};
/** Damick has no page numbers, so citations name a chapter and section: "Damick ch3: Lutheranism". */
const damickCite = (s: string) => {
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
const nameOf = (n: HistoryNode) => SHORT_NAME[n.id] ?? n.name;
const isTradId = (id: string | undefined) => !!id && byId.get(id)?.type === 'tradition';

// ---------------------------------------------------------------------------
// Detail level. The simple view shows the big families and moments only.

let simple = true;
let visible = new Set<string>();
function computeVisible() {
  visible = simple ? new Set([...SIMPLE_TRADITIONS, ...SIMPLE_MARKERS]) : new Set(nodes.map((n) => n.id));
}
computeVisible();
const shown = () => nodes.filter((n) => visible.has(n.id));

/** Nearest ancestor that is drawn at the current detail level. */
function parentOf(t: HistoryNode) {
  let p = t.parents?.find(isTradId);
  const seen = new Set<string>();
  while (p && !visible.has(p) && !seen.has(p)) {
    seen.add(p);
    p = byId.get(p)!.parents?.find(isTradId);
  }
  return p && visible.has(p) ? p : undefined;
}

// ---------------------------------------------------------------------------
// Time scale. Later centuries get more room because they hold more branches.

const SCALE: [number, number][] = [
  [FIRST_YEAR, 0.17],
  [1000, 0.21],
  [1500, 0.46],
];
function rawX(year: number) {
  let x = 0;
  for (let i = 0; i < SCALE.length; i++) {
    const [from, k] = SCALE[i];
    const to = SCALE[i + 1]?.[0] ?? Infinity;
    if (year <= from) break;
    x += (Math.min(year, to) - from) * k;
  }
  return x;
}
const X_MID = rawX(NOW) / 2;
const X = (year: number) => rawX(year) - X_MID;
function yearAtX(x: number) {
  let rem = x + X_MID;
  for (let i = 0; i < SCALE.length; i++) {
    const [from, k] = SCALE[i];
    const to = SCALE[i + 1]?.[0] ?? Infinity;
    const span = (to - from) * k;
    if (rem <= span || i === SCALE.length - 1) return from + rem / k;
    rem -= span;
  }
  return NOW;
}
const BEND = 13;

// ---------------------------------------------------------------------------
// Color

type Mode = 'family' | 'eucharist';
let mode: Mode = 'family';

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
const familyKey = (t: HistoryNode) => inherit(FAMILY_OF, t, 'catholic');
const eucharistKey = (t: HistoryNode) => inherit(EUCHARIST_OF, t, 'memorial');

// Distinct hues per tradition in the simple view so every line reads on its own.
const SIMPLE_COLOR: Record<string, string> = {
  'church-of-east': '#4fbdae',
  'oriental-orthodox': '#e7a052',
  'eastern-orthodox': '#a48df0',
  catholic: '#f0cb63',
  lutheran: '#5d9ff5',
  reformed: '#8fc8ff',
  anabaptist: '#9ad97a',
  anglican: '#f08aa8',
  methodist: '#f5786a',
  pentecostal: '#ff9e5e',
  baptist: '#58d3e0',
  'evangelical-nondenom': '#c3b4ff',
};
function colorOf(t: HistoryNode) {
  if (mode === 'eucharist') return new THREE.Color(EUCHARIST[eucharistKey(t)].color);
  if (TRUNK.includes(t.id)) return new THREE.Color(FAMILIES.early.color);
  if (SIMPLE_COLOR[t.id]) return new THREE.Color(SIMPLE_COLOR[t.id]);
  return new THREE.Color(FAMILIES[familyKey(t)].color);
}
const GOLD = new THREE.Color('#e9bf55');
const RUBRIC = new THREE.Color('#e5563f');
const MUTED = new THREE.Color('#c9cfe0');

// ---------------------------------------------------------------------------
// Renderer, camera, lights

const stage = $<HTMLDivElement>('stage');
const app = $<HTMLDivElement>('app');
const panel = $<HTMLElement>('panel');
const panelBody = $<HTMLDivElement>('panel-body');

const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(2, devicePixelRatio));
stage.appendChild(renderer.domElement);
const labelRenderer = new CSS2DRenderer();
labelRenderer.domElement.className = 'labels';
stage.appendChild(labelRenderer.domElement);

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(new THREE.Color('#0f1c3f'), 400, 1400);
const camera = new THREE.PerspectiveCamera(34, 1, 1, 6000);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.12;
controls.zoomToCursor = true;
controls.minDistance = 30;
controls.maxDistance = 2600;
controls.maxPolarAngle = 1.38;
controls.screenSpacePanning = false;
// One finger slides the map, like other maps on a phone. Two fingers pinch to zoom and turn.
controls.touches = { ONE: THREE.TOUCH.PAN, TWO: THREE.TOUCH.DOLLY_ROTATE };

scene.add(new THREE.HemisphereLight(0xe4eaff, 0x0b1530, 1.6));
const sun = new THREE.DirectionalLight(0xffffff, 1.3);
sun.position.set(-1, 2.2, 1.6);
scene.add(sun);

// A gold halo, the way icons mark holiness, used for every council.
function haloTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d')!;
  const glow = g.createRadialGradient(128, 128, 20, 128, 128, 128);
  glow.addColorStop(0, 'rgba(255,214,120,0.55)');
  glow.addColorStop(0.55, 'rgba(233,191,85,0.18)');
  glow.addColorStop(1, 'rgba(233,191,85,0)');
  g.fillStyle = glow;
  g.fillRect(0, 0, 256, 256);
  g.strokeStyle = '#f3cf6e';
  g.lineCap = 'round';
  g.lineWidth = 3;
  for (let i = 0; i < 24; i++) {
    const a = (i / 24) * Math.PI * 2;
    const r0 = 62;
    const r1 = i % 2 ? 84 : 100;
    g.beginPath();
    g.moveTo(128 + Math.cos(a) * r0, 128 + Math.sin(a) * r0);
    g.lineTo(128 + Math.cos(a) * r1, 128 + Math.sin(a) * r1);
    g.stroke();
  }
  g.lineWidth = 7;
  g.beginPath();
  g.arc(128, 128, 50, 0, Math.PI * 2);
  g.stroke();
  g.lineWidth = 9;
  g.beginPath();
  g.moveTo(128, 100);
  g.lineTo(128, 160);
  g.moveTo(108, 120);
  g.lineTo(148, 120);
  g.stroke();
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}
const haloMat = new THREE.SpriteMaterial({ map: haloTexture(), transparent: true, depthWrite: false, fog: false });
const goldMat = new THREE.MeshLambertMaterial({ color: GOLD, emissive: GOLD.clone().multiplyScalar(0.55) });
const goldSoft = new THREE.MeshBasicMaterial({ color: GOLD, transparent: true, opacity: 0.35, side: THREE.DoubleSide });
const rubricMat = new THREE.MeshLambertMaterial({ color: RUBRIC, emissive: RUBRIC.clone().multiplyScalar(0.6) });
const eventMat = new THREE.MeshLambertMaterial({ color: MUTED, emissive: MUTED.clone().multiplyScalar(0.35) });
const spanMat = new THREE.MeshBasicMaterial({ color: MUTED, transparent: true, opacity: 0.28 });
const pickMat = new THREE.MeshBasicMaterial({ colorWrite: false, depthWrite: false });

// ---------------------------------------------------------------------------
// Labels

type LabelKind = 'trad' | 'end' | 'council' | 'schism' | 'event' | 'year';
interface Shape {
  w: number;
  h: number;
  cx: number;
  cy: number;
}
interface Label extends Shape {
  obj: CSS2DObject;
  el: HTMLElement;
  id?: string;
  kind: LabelKind;
  imp: number;
  fixed: boolean;
  text: string;
  font: string;
  /** End and year labels sit one way on wide screens and another on tall ones. */
  flat?: Shape;
  hang?: Shape;
  /** End labels on phones held sideways, with a smaller emblem and font so they stack tighter. */
  small?: Shape;
}
const KIND_RANK: Record<LabelKind, number> = { trad: 0, schism: 1, council: 2, end: 3, event: 4, year: 5 };
// In the simple view the emblems at the right edge act as the key, so they win ties.
const rank = (l: { kind: LabelKind }) => (simple && l.kind === 'end' ? -1 : KIND_RANK[l.kind]);
const measureCtx = document.createElement('canvas').getContext('2d')!;

// ---------------------------------------------------------------------------
// The world. Rebuilt whenever the detail level changes.

interface Branch {
  node: HistoryNode;
  z0: number;
  z1: number;
  xs: number;
  xe: number;
  bend: number;
  mat: THREE.MeshLambertMaterial;
  links: THREE.LineDashedMaterial[];
  labels: Label[];
}
interface Marker {
  node: HistoryNode;
  pos: THREE.Vector3;
  group: THREE.Group;
  label: Label;
  kind: 'council' | 'schism' | 'event';
}

let world = new THREE.Group();
let labels: Label[] = [];
let sortedLabels: Label[] = [];
let branches = new Map<string, Branch>();
let markerList: Marker[] = [];
let markerById = new Map<string, Marker>();
let pickables: THREE.Object3D[] = [];
let childrenOf = new Map<string, string[]>();
let laneZ = new Map<string, number>();
let Z_MIN = 0;
let Z_MAX = 0;

function addLabel(opts: {
  kind: LabelKind;
  html: string;
  text: string;
  pos: THREE.Vector3;
  center: [number, number];
  id?: string;
  imp?: number;
  extraClass?: string;
  extraWidth?: number;
}) {
  const el = document.createElement(opts.id ? 'button' : 'div');
  el.className = `lbl ${opts.kind} ${opts.extraClass ?? ''}`;
  el.innerHTML = opts.html;
  if (opts.id) {
    const id = opts.id;
    el.setAttribute('type', 'button');
    el.addEventListener('click', (e) => {
      e.stopPropagation();
      select(id);
    });
    el.addEventListener('pointerdown', (e) => e.stopPropagation());
    el.addEventListener(
      'wheel',
      (e) => {
        e.preventDefault();
        renderer.domElement.dispatchEvent(new WheelEvent('wheel', e));
      },
      { passive: false },
    );
  }
  const obj = new CSS2DObject(el);
  obj.position.copy(opts.pos);
  obj.center.set(opts.center[0], opts.center[1]);
  world.add(obj);
  const size = opts.kind === 'trad' ? (opts.imp === 1 ? 13.5 : 12) : opts.kind === 'end' ? 13 : 12.5;
  const font = `${opts.kind === 'trad' || opts.kind === 'end' ? 600 : 500} ${size}px 'Instrument Sans', sans-serif`;
  measureCtx.font = font;
  const textW = measureCtx.measureText(opts.text).width;
  const label: Label = {
    obj,
    el,
    id: opts.id,
    kind: opts.kind,
    imp: opts.imp ?? 1,
    w: textW + 20 + (opts.extraWidth ?? 0),
    h: opts.kind === 'end' ? 23 : size + 10,
    cx: opts.center[0],
    cy: opts.center[1],
    fixed: opts.kind === 'year',
    text: opts.text,
    font,
  };
  if (opts.kind === 'end') {
    label.flat = { w: label.w, h: label.h, cx: label.cx, cy: label.cy };
    label.hang = { w: 21, h: 21 + textW + 16, cx: 0.5, cy: 0 };
    label.small = { w: textW * (12.5 / 13) + 33, h: 18, cx: label.cx, cy: label.cy };
  } else if (opts.kind === 'year') {
    // Tall screens run the years down the left edge, just above their grid lines.
    label.flat = { w: label.w, h: label.h, cx: label.cx, cy: label.cy };
    label.hang = { w: label.w, h: label.h, cx: 1 - 10 / label.w, cy: 1 };
  }
  labels.push(label);
  return label;
}

const yearText = (n: HistoryNode) => {
  if (n.type === 'tradition') return n.end == null ? `${n.start} to today` : `${n.start} to ${n.end}`;
  if (n.end != null && n.end !== n.start) return `${n.start} to ${n.end}`;
  return String(n.start);
};

function zOnBranch(b: Branch, year: number) {
  const x = X(year);
  if (x <= b.xs) return b.z0;
  if (x >= b.xs + b.bend) return b.z1;
  const t = (x - b.xs) / b.bend;
  return b.z0 + (b.z1 - b.z0) * t * t * (3 - 2 * t);
}
function anchorZ(id: string | undefined, year: number) {
  const b = id ? branches.get(id) : undefined;
  if (b) return zOnBranch(b, Math.max(b.node.start, Math.min(year, b.node.end ?? NOW)));
  return laneZ.get('__trunk__') ?? 0;
}

function computeLanes(traditions: HistoryNode[]) {
  const order = [...(simple ? SIMPLE_ORDER : LANE_ORDER)];
  const insertedUnder = new Map<string, string>();
  for (const t of traditions) {
    if (TRUNK.includes(t.id) || order.includes(t.id)) continue;
    const p = parentOf(t) ?? 'catholic';
    const anchor = TRUNK.includes(p) ? '__trunk__' : p;
    let i = order.indexOf(anchor);
    if (i < 0) i = order.length - 1;
    let j = i + 1;
    while (j < order.length && insertedUnder.get(order[j]) === anchor) j++;
    order.splice(j, 0, t.id);
    insertedUnder.set(t.id, anchor);
  }
  const present = order.filter((id) => id === '__trunk__' || visible.has(id));
  laneZ = new Map();
  let z = 0;
  present.forEach((id, i) => {
    const imp = id === '__trunk__' ? 1 : byId.get(id)!.importance;
    if (i > 0) z += simple ? 22 : imp === 1 ? 11 : imp === 2 ? 7.5 : 5.5;
    laneZ.set(id, z);
  });
  for (const [k, v] of laneZ) laneZ.set(k, v - z / 2);
  Z_MIN = Math.min(...laneZ.values());
  Z_MAX = Math.max(...laneZ.values());
}
const laneOf = (id: string) => (TRUNK.includes(id) ? laneZ.get('__trunk__')! : laneZ.get(id) ?? laneZ.get('__trunk__')!);

function buildFloor() {
  const years = simple ? [500, 1000, 1500, 1600, 1700, 1800, 1900] : [];
  if (!simple) for (let c = 100; c <= 1900; c += 100) years.push(c);
  const pts: number[] = [];
  for (const y of years) pts.push(X(y), -0.6, Z_MIN - 12, X(y), -0.6, Z_MAX + 12);
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
  world.add(new THREE.LineSegments(g, new THREE.LineBasicMaterial({ color: 0xefe6cf, transparent: true, opacity: 0.08 })));
  const nowLine = new THREE.Line(
    new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(X(NOW), -0.6, Z_MIN - 12), new THREE.Vector3(X(NOW), -0.6, Z_MAX + 12)]),
    new THREE.LineDashedMaterial({ color: 0xefe6cf, dashSize: 2, gapSize: 2, transparent: true, opacity: 0.3 }),
  );
  nowLine.computeLineDistances();
  world.add(nowLine);
  for (const y of years) {
    addLabel({ kind: 'year', html: String(y), text: String(y), pos: new THREE.Vector3(X(y), -0.6, Z_MAX + 14), center: [0.5, 0] });
  }
  addLabel({ kind: 'year', html: 'AD 30', text: 'AD 30', pos: new THREE.Vector3(X(FIRST_YEAR), -0.6, Z_MAX + 14), center: [0.5, 0] });
  addLabel({ kind: 'year', html: 'Today', text: 'Today', pos: new THREE.Vector3(X(NOW), -0.6, Z_MAX + 14), center: [0.5, 0], extraClass: 'now' });
}

function buildBranches(traditions: HistoryNode[]) {
  for (const t of traditions) {
    const z1 = laneOf(t.id);
    const p = parentOf(t);
    const z0 = p ? anchorZ(p, t.start) : z1;
    const xs = X(t.start);
    const xe = X(t.end ?? NOW);
    const bend = Math.abs(z1 - z0) < 0.01 ? 0 : Math.min(BEND, Math.max(2, (xe - xs) * 0.6));
    const trunk = TRUNK.includes(t.id);
    const radius = trunk ? 1.3 : simple ? 0.8 : t.importance === 1 ? 0.72 : t.importance === 2 ? 0.48 : 0.34;

    const pts: THREE.Vector3[] = [];
    const steps = bend > 0 ? 16 : 0;
    for (let i = 0; i <= steps; i++) {
      const k = steps ? i / steps : 0;
      pts.push(new THREE.Vector3(xs + bend * k, 0, z0 + (z1 - z0) * k * k * (3 - 2 * k)));
    }
    if (xe > xs + bend + 0.01) pts.push(new THREE.Vector3(xe, 0, z1));
    if (pts.length < 2) pts.push(new THREE.Vector3(xs + 0.5, 0, z1));
    const path = new THREE.CurvePath<THREE.Vector3>();
    for (let i = 1; i < pts.length; i++) path.add(new THREE.LineCurve3(pts[i - 1], pts[i]));

    const segs = Math.max(24, steps * 3 + 8);
    const mat = new THREE.MeshLambertMaterial({ transparent: true, opacity: t.outsideNicene ? 0.6 : 1 });
    world.add(new THREE.Mesh(new THREE.TubeGeometry(path, segs, radius, 10, false), mat));
    const pick = new THREE.Mesh(new THREE.TubeGeometry(path, segs, Math.max(2.4, radius * 2.6), 6, false), pickMat);
    pick.userData.id = t.id;
    world.add(pick);
    pickables.push(pick);

    const cap = new THREE.Mesh(new THREE.SphereGeometry(radius * (t.end == null ? 1.9 : 1.15), 16, 12), mat);
    cap.position.copy(pts[pts.length - 1]);
    world.add(cap);
    if (!p) {
      const startCap = new THREE.Mesh(new THREE.SphereGeometry(radius * 2.2, 16, 12), mat);
      startCap.position.copy(pts[0]);
      world.add(startCap);
    }

    const links: THREE.LineDashedMaterial[] = [];
    if (!simple) {
      for (const other of (t.parents ?? []).filter((id) => isTradId(id) && visible.has(id)).slice(1)) {
        const a = new THREE.Vector3(xs, 0, anchorZ(other, t.start));
        const b = new THREE.Vector3(xs + Math.max(bend, 6), 0, z1);
        const curve = new THREE.QuadraticBezierCurve3(a, a.clone().lerp(b, 0.5).setY(5), b);
        const lineMat = new THREE.LineDashedMaterial({ dashSize: 1.2, gapSize: 1, transparent: true, opacity: 0.7 });
        const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints(curve.getPoints(30)), lineMat);
        line.computeLineDistances();
        world.add(line);
        links.push(lineMat);
      }
    }

    const branch: Branch = { node: t, z0, z1, xs, xe, bend, mat, links, labels: [] };
    branches.set(t.id, branch);

    const emblem = EMBLEMS[t.id];
    const hideStart = simple && (t.id === 'early-church' || t.id === 'chalcedonian');
    if (!hideStart) {
      const lead = t.id === 'apostolic' && emblem ? `<i class="emb">${emblem}</i>` : '';
      branch.labels.push(
        addLabel({
          kind: 'trad',
          id: t.id,
          imp: t.importance,
          html: `${lead}${esc(nameOf(t))}<small>${t.start}</small>`,
          text: `${nameOf(t)} ${t.start}`,
          pos: new THREE.Vector3(xs + bend + 1.5, radius + 0.3, z1),
          center: [0, 1],
          extraClass: t.importance > 1 && !simple ? 'minor' : '',
          extraWidth: lead ? 24 : 0,
        }),
      );
    }
    if (t.end == null) {
      branch.labels.push(
        addLabel({
          kind: 'end',
          id: t.id,
          imp: t.importance,
          html: `${emblem ? `<i class="emb">${emblem}</i>` : ''}<span>${esc(nameOf(t))}</span>`,
          text: nameOf(t),
          pos: new THREE.Vector3(xe + radius * 2 + 1.5, 0, z1),
          center: [0, 0.5],
          extraWidth: emblem ? 30 : 0,
        }),
      );
    }
  }
}

function buildMarkers(list: HistoryNode[]) {
  // Councils close in time alternate between a short and a tall halo so their labels never stack.
  const councils = list.filter((n) => n.type === 'council').sort((a, b) => a.start - b.start);
  const tall = new Set(councils.filter((_, i) => i % 2 === 1).map((n) => n.id));
  for (const m of list) {
    const kind: Marker['kind'] = m.type === 'council' ? 'council' : m.type === 'schism' ? 'schism' : 'event';
    const host = m.on && visible.has(m.on) ? m.on : m.on ? parentOf({ ...m, parents: [m.on] }) : undefined;
    const span = m.end != null && m.end - m.start >= 15;
    const year = m.type === 'figure' && span ? Math.round((m.start + (m.end as number)) / 2) : m.start;
    const hostNode = host ? byId.get(host) : undefined;
    const z = !hostNode || year > (hostNode.end ?? NOW) + 5 ? Z_MAX + 7 : anchorZ(host, year);
    const pos = new THREE.Vector3(X(year), 0, z);
    const group = new THREE.Group();
    group.position.copy(pos);
    let labelY = 3.2;

    if (kind === 'council') {
      const big = simple || m.importance === 1;
      const h = (big ? 9 : 6) + (tall.has(m.id) ? 7 : 0);
      const stem = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, h, 8), goldMat);
      stem.position.y = h / 2;
      const halo = new THREE.Sprite(haloMat);
      const s = big ? 6.5 : 4.5;
      halo.scale.set(s, s, 1);
      halo.position.y = h + s * 0.32;
      const base = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.7, 28), goldSoft);
      base.rotation.x = -Math.PI / 2;
      base.position.y = -0.55;
      group.add(stem, halo, base);
      labelY = h + s * 0.75;
    } else if (kind === 'schism') {
      const ring = new THREE.Mesh(new THREE.TorusGeometry(2.6, 0.24, 10, 40), rubricMat);
      ring.rotation.y = Math.PI / 2;
      group.add(ring);
      labelY = 3.6;
    } else if (span && m.type !== 'figure') {
      const len = X(m.end as number) - X(m.start);
      const bar = new THREE.Mesh(new THREE.BoxGeometry(len, 0.18, 0.18), spanMat);
      bar.position.set(len / 2, 2.2, 0);
      const dot = new THREE.Mesh(new THREE.OctahedronGeometry(0.55), eventMat);
      dot.position.y = 2.2;
      group.add(bar, dot);
    } else {
      const dot = new THREE.Mesh(new THREE.OctahedronGeometry(0.6), eventMat);
      dot.position.y = 2.2;
      group.add(dot);
    }
    group.traverse((o) => (o.userData.id = m.id));
    world.add(group);
    pickables.push(group);

    const label = addLabel({
      kind,
      id: m.id,
      imp: simple ? 1 : m.importance,
      html: `${esc(nameOf(m))}<small>${m.type === 'figure' ? '' : m.start}</small>`,
      text: `${nameOf(m)} ${m.start}`,
      pos: pos.clone().setY(labelY),
      center: [0.5, 1],
    });
    const marker: Marker = { node: m, pos, group, label, kind };
    markerList.push(marker);
    markerById.set(m.id, marker);
  }
}

function build() {
  scene.remove(world);
  world.traverse((o) => {
    const mesh = o as THREE.Mesh;
    if (mesh.geometry) mesh.geometry.dispose();
  });
  // The label renderer only drops elements of objects removed directly, so clear the old ones here.
  for (const l of labels) l.el.remove();
  world = new THREE.Group();
  labels = [];
  branches = new Map();
  markerList = [];
  markerById = new Map();
  pickables = [];

  const traditions = shown()
    .filter((n) => n.type === 'tradition')
    .sort((a, b) => a.start - b.start);
  computeLanes(traditions);
  buildFloor();
  buildBranches(traditions);
  buildMarkers(shown().filter((n) => n.type !== 'tradition'));

  childrenOf = new Map();
  for (const t of traditions) {
    const p = parentOf(t);
    const all = simple ? (p ? [p] : []) : (t.parents ?? []).filter(isTradId);
    for (const id of all) {
      if (!childrenOf.has(id)) childrenOf.set(id, []);
      childrenOf.get(id)!.push(t.id);
    }
  }
  scene.add(world);
  sortedLabels = labels
    .filter((l) => !l.fixed)
    .sort((a, b) => a.imp - b.imp || rank(a) - rank(b));
  orientLabels();
  applyColors();
  applyHighlight();
  sizeCursor();
  tlDirty = true;
}

// ---------------------------------------------------------------------------
// Relationships

function ancestors(id: string) {
  const out: string[] = [];
  let cur = byId.get(id);
  const seen = new Set<string>();
  while (cur) {
    const p = parentOf(cur);
    if (!p || seen.has(p)) break;
    seen.add(p);
    out.unshift(p);
    cur = byId.get(p);
  }
  return out;
}
function descendants(id: string, acc = new Set<string>()) {
  for (const c of childrenOf.get(id) ?? []) {
    if (acc.has(c)) continue;
    acc.add(c);
    descendants(c, acc);
  }
  return acc;
}

// ---------------------------------------------------------------------------
// Color and highlight

let selected: string | null = null;
let lit: Set<string> | null = null;
let dirty = true;

function applyColors() {
  dirty = true;
  for (const b of branches.values()) {
    const c = colorOf(b.node);
    b.mat.color.copy(c);
    b.mat.emissive.copy(c).multiplyScalar(0.42);
    for (const l of b.links) l.color.copy(c);
    for (const l of b.labels) l.el.style.setProperty('--c', `#${c.getHexString()}`);
  }
  renderLegend();
}

function markerLit(m: Marker) {
  if (!lit) return true;
  return m.node.id === selected || lit.has(m.node.on ?? '') || (m.node.splits ?? []).some((s) => lit!.has(s));
}

function applyHighlight() {
  app.classList.toggle('dimmed', !!lit);
  for (const b of branches.values()) {
    const on = !lit || lit.has(b.node.id);
    b.mat.opacity = on ? (b.node.outsideNicene ? 0.6 : 1) : 0.1;
    b.mat.depthWrite = on;
    for (const l of b.links) l.opacity = on ? 0.7 : 0.08;
    for (const l of b.labels) l.el.classList.toggle('lit', !!lit && on);
  }
  for (const m of markerList) {
    const on = markerLit(m);
    m.group.visible = on;
    m.label.el.classList.toggle('lit', !!lit && on);
  }
  for (const l of labels) l.el.classList.toggle('sel', !!selected && l.id === selected);
  dirty = true;
}

// ---------------------------------------------------------------------------
// Camera moves

const LANDSCAPE_DIR = new THREE.Vector3(-0.1, 1.55, 1).normalize();
// Phones held sideways look down more steeply, which spreads the lines further apart.
const STEEP_DIR = new THREE.Vector3(-0.1, 2.6, 1).normalize();
const PORTRAIT_DIR = new THREE.Vector3(1, 0.85, 0.1).normalize();
const defaultDir = () => (tall ? PORTRAIT_DIR : phoneQuery.matches ? STEEP_DIR : LANDSCAPE_DIR).clone();

/** Tall screens look back from today, so the living lines end side by side along the bottom. */
let tall = false;
let phone = false;
function orientLabels() {
  for (const l of labels) {
    if (!l.flat || !l.hang) continue;
    Object.assign(l, tall ? l.hang : phone && l.small ? l.small : l.flat);
    if (l.kind === 'end') l.el.classList.toggle('vert', tall);
    l.obj.center.set(l.cx, l.cy);
  }
  dirty = true;
}
/** Room the year labels need on the left of tall screens, in pixels. */
const YEAR_ROOM = 46;
/** Room the end labels need past the line ends, in pixels: below them on tall screens, and
 * to the right on phones held sideways. Desktop leaves room in the scene instead. With the
 * panel open on a tall screen only the emblems need to show, since the panel names the line. */
const roomInPixels = () => tall || phoneQuery.matches;
function endRoom(panelOpen: boolean) {
  const ends = labels.filter((l) => l.kind === 'end');
  if (tall) return { b: panelOpen ? 30 : Math.max(0, ...ends.map((l) => l.hang!.h)), r: 0 };
  if (phoneQuery.matches) return { b: 0, r: Math.max(0, ...ends.map((l) => l.small!.w)) };
  return { b: 0, r: 0 };
}

interface Tween {
  t0: number;
  dur: number;
  fromT: THREE.Vector3;
  toT: THREE.Vector3;
  fromDir: THREE.Vector3;
  toDir: THREE.Vector3;
  fromD: number;
  toD: number;
}
let tween: Tween | null = null;
const ease = (k: number) => 1 - Math.pow(1 - k, 3);

function flyTo(target: THREE.Vector3, dist: number, dir?: THREE.Vector3, dur = 750) {
  const off = camera.position.clone().sub(controls.target);
  const toDir = (dir ?? off.clone().normalize()).clone();
  if (!dir && toDir.y < 0.25) toDir.copy(defaultDir());
  dist = THREE.MathUtils.clamp(dist, controls.minDistance, controls.maxDistance);
  if (reduceMotion || dur === 0) {
    controls.target.copy(target);
    camera.position.copy(target).addScaledVector(toDir, dist);
    tween = null;
    dirty = true;
    return;
  }
  tween = {
    t0: performance.now(),
    dur,
    fromT: controls.target.clone(),
    toT: target.clone(),
    fromDir: off.clone().normalize(),
    toDir,
    fromD: off.length(),
    toD: dist,
  };
}

/** Clear screen area left after the header, the story card, and an open panel. */
function safeArea(panelOpen: boolean, underCard = false) {
  const w = stage.clientWidth;
  const h = stage.clientHeight;
  if (phoneQuery.matches) return phoneSafeArea(w, h, panelOpen, underCard);
  const storyH = $<HTMLElement>('story').offsetHeight;
  return {
    l: 24,
    r: panelOpen ? 440 : 60,
    t: Math.max(110, $<HTMLElement>('views').getBoundingClientRect().bottom - stage.getBoundingClientRect().top + 16),
    b: Math.min(storyH + 50, h * 0.4),
    w,
    h,
  };
}

/** Boxes of the controls and cards drawn over the map, relative to the stage. */
function chromeRects(panelOpen = !panel.hidden, withCard = true) {
  const o = stage.getBoundingClientRect();
  const rects = [...document.querySelectorAll<HTMLElement>('.top h1, .legend, .search, .seg, .corner, .views')]
    .map((el) => el.getBoundingClientRect())
    .map((r) => ({ l: r.left - o.left, t: r.top - o.top, r: r.right - o.left, b: r.bottom - o.top }));
  // The cards slide in and out, so use where they rest rather than where they are mid-move.
  const card = panelOpen ? panel : $<HTMLElement>('story');
  if (withCard) rects.push({ l: card.offsetLeft, t: card.offsetTop, r: card.offsetLeft + card.offsetWidth, b: card.offsetTop + card.offsetHeight });
  return rects.filter((r) => r.r > r.l && r.b > r.t);
}

/** Phone layouts vary, so measure what covers the map and keep the largest clear rectangle. */
function phoneSafeArea(w: number, h: number, panelOpen: boolean, underCard: boolean) {
  let s = { l: 8, r: 8, t: 8, b: 8, w, h };
  const area = (a: typeof s) => Math.max(0, w - a.l - a.r) * Math.max(0, h - a.t - a.b);
  for (const c of chromeRects(panelOpen, !underCard)) {
    const options = [
      { ...s, t: Math.max(s.t, c.b + 8) },
      { ...s, b: Math.max(s.b, h - c.t + 8) },
      { ...s, l: Math.max(s.l, c.r + 8) },
      { ...s, r: Math.max(s.r, w - c.l + 8) },
    ];
    s = options.reduce((best, a) => (area(a) > area(best) ? a : best));
  }
  return s;
}

const fitCam = new THREE.PerspectiveCamera();
interface FitOpts {
  panel?: boolean;
  /** Leave room for the end labels. */
  hang?: boolean;
  /** Let the story card cover part of the frame. */
  underCard?: boolean;
  /** Fit these points instead of the box corners, for a tighter frame. */
  points?: THREE.Vector3[];
}

function fitBox(min: THREE.Vector3, max: THREE.Vector3, dir: THREE.Vector3, opts: FitOpts = {}) {
  const panelOpen = !!opts.panel;
  const s = safeArea(panelOpen, opts.underCard);
  if (opts.hang) {
    const room = endRoom(panelOpen);
    s.b += room.b;
    s.r += room.r;
  }
  if (tall) s.l += YEAR_ROOM;
  const nx0 = (s.l / s.w) * 2 - 1;
  const nx1 = 1 - (s.r / s.w) * 2;
  const ny0 = (s.b / s.h) * 2 - 1;
  const ny1 = 1 - (s.t / s.h) * 2;
  fitCam.copy(camera);
  const corners: THREE.Vector3[] = opts.points ?? [];
  if (!opts.points) for (const x of [min.x, max.x]) for (const y of [min.y, max.y]) for (const z of [min.z, max.z]) corners.push(new THREE.Vector3(x, y, z));
  const target = min.clone().add(max).multiplyScalar(0.5).setY(0);
  const v = new THREE.Vector3();
  const extents = (dist: number) => {
    fitCam.position.copy(target).addScaledVector(dir, dist);
    fitCam.lookAt(target);
    fitCam.updateMatrixWorld();
    let x0 = Infinity;
    let x1 = -Infinity;
    let y0 = Infinity;
    let y1 = -Infinity;
    for (const c of corners) {
      v.copy(c).project(fitCam);
      if (v.z > 1) return null;
      x0 = Math.min(x0, v.x);
      x1 = Math.max(x1, v.x);
      y0 = Math.min(y0, v.y);
      y1 = Math.max(y1, v.y);
    }
    return [x0, x1, y0, y1] as const;
  };
  const right = new THREE.Vector3(dir.z, 0, -dir.x).normalize();
  const fwd = new THREE.Vector3(-dir.x, 0, -dir.z).normalize();
  const tanHalf = Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
  let dist = 300;
  for (let iter = 0; iter < 4; iter++) {
    let lo = 10;
    let hi = 5000;
    for (let k = 0; k < 24; k++) {
      const mid = (lo + hi) / 2;
      const e = extents(mid);
      if (e && e[1] - e[0] <= nx1 - nx0 && e[3] - e[2] <= ny1 - ny0) hi = mid;
      else lo = mid;
    }
    dist = hi;
    const e = extents(dist);
    if (!e) break;
    const halfH = dist * tanHalf;
    target.addScaledVector(right, -(((nx0 + nx1) / 2 - (e[0] + e[1]) / 2) * halfH * camera.aspect));
    target.addScaledVector(fwd, (-((ny0 + ny1) / 2 - (e[2] + e[3]) / 2) * halfH) / Math.max(0.3, dir.y));
  }
  return { target, dist };
}

function frameBox(
  min: THREE.Vector3,
  max: THREE.Vector3,
  opts: FitOpts & { dir?: THREE.Vector3; dur?: number } = {},
) {
  let dir = opts.dir;
  if (!dir) {
    dir = camera.position.clone().sub(controls.target).normalize();
    if (dir.y < 0.35) dir = defaultDir();
  }
  const { target, dist } = fitBox(min, max, dir, opts);
  flyTo(target, dist, dir, opts.dur);
}

/** Phones zoom in on the lines that branch off in the years, and the lines they leave. */
function branchingZRange(from: number, to: number) {
  let lo = Infinity;
  let hi = -Infinity;
  for (const b of branches.values()) {
    if (b.node.start < from || b.node.start > to) continue;
    lo = Math.min(lo, b.z1, b.z0);
    hi = Math.max(hi, b.z1, b.z0);
  }
  for (const m of markerList) {
    if (m.node.start < from || m.node.start > to) continue;
    lo = Math.min(lo, m.pos.z);
    hi = Math.max(hi, m.pos.z);
  }
  if (!isFinite(lo)) return zRangeFor(from, to);
  // Keep a few lanes either side so a lone line does not fill the screen.
  const mid = (lo + hi) / 2;
  const half = Math.max((hi - lo) / 2, 50);
  return [mid - half, mid + half] as const;
}

function zRangeFor(from: number, to: number) {
  let lo = Infinity;
  let hi = -Infinity;
  for (const b of branches.values()) {
    if (b.node.start > to || (b.node.end ?? NOW) < from) continue;
    lo = Math.min(lo, b.z1, b.z0);
    hi = Math.max(hi, b.z1, b.z0);
  }
  if (!isFinite(lo)) lo = hi = 0;
  return [lo, hi] as const;
}

function flyToRange(from: number, to: number, dur?: number) {
  const whole = from <= FIRST_YEAR && to >= NOW;
  const [lo, hi] = whole ? [Z_MIN, Z_MAX] : roomInPixels() && to < NOW ? branchingZRange(from, to) : zRangeFor(from, to);
  const x0 = whole ? X(FIRST_YEAR) - 6 : X(from);
  // Desktop keeps room right of today for the end labels. Phones and tall screens measure it in pixels.
  const x1 = whole ? X(NOW) + (roomInPixels() ? 4 : 34) : X(to);
  const zPad = roomInPixels() ? 4 : 8;
  frameBox(new THREE.Vector3(x0, 0, lo - zPad), new THREE.Vector3(x1, 12, hi + (whole && !roomInPixels() ? 16 : zPad)), {
    dir: defaultDir(),
    dur,
    panel: !panel.hidden,
    hang: to >= NOW,
    // Landscape phones need every pixel of height for the whole map. Its lower left corner
    // is empty, so the story card can sit over it.
    underCard: whole && sideSheetQuery.matches,
    points: whole && roomInPixels() ? outline() : undefined,
  });
}

/** Where every line starts, bends, and ends, plus the tops of the councils. Phones fit the
 * whole map to these, since the corners of its box are mostly empty and cost a lot of room. */
function outline() {
  const pts: THREE.Vector3[] = [];
  for (const b of branches.values()) {
    // The ends carry the emblems, so give them a little room either side.
    pts.push(new THREE.Vector3(b.xs - 4, 0, b.z0), new THREE.Vector3(b.xe + 2, 0, b.z1 - 6), new THREE.Vector3(b.xe + 2, 0, b.z1 + 6));
  }
  for (const m of markerList) pts.push(m.pos.clone().setY(m.kind === 'council' ? 12 : 3));
  return pts;
}

function focusNode(id: string) {
  const n = byId.get(id)!;
  if (n.type === 'tradition') {
    const b = branches.get(id);
    if (!b) return;
    const xe = Math.min(b.xe, X(NOW));
    const living = b.node.end == null;
    frameBox(
      new THREE.Vector3(b.xs - 6, 0, Math.min(b.z0, b.z1) - 6),
      new THREE.Vector3(xe + (living && roomInPixels() ? 4 : 30), 8, Math.max(b.z0, b.z1) + 6),
      { panel: true, hang: living },
    );
  } else {
    const m = markerById.get(id);
    if (!m) return;
    frameBox(m.pos.clone().add(new THREE.Vector3(-28, 0, -16)), m.pos.clone().add(new THREE.Vector3(28, 14, 16)), { panel: true });
  }
}

// ---------------------------------------------------------------------------
// Selection and the detail panel

function showPanel(on: boolean) {
  panel.hidden = !on;
  app.classList.toggle('panel-open', on);
}

function select(id: string | null, opts: { fly?: boolean } = {}) {
  if (id && byId.has(id) && !visible.has(id)) setDetail(false);
  selected = id && byId.has(id) ? id : null;
  if (!selected) {
    lit = null;
    showPanel(false);
    history.replaceState(null, '', location.pathname);
    applyHighlight();
    return;
  }
  const n = byId.get(selected)!;
  if (n.type === 'tradition') {
    lit = new Set([selected, ...ancestors(selected), ...descendants(selected)]);
  } else {
    const host = n.on && visible.has(n.on) ? n.on : '';
    lit = new Set([host, ...ancestors(host), ...(n.splits ?? []).filter((s) => visible.has(s))]);
  }
  renderPanel(n);
  showPanel(true);
  panel.scrollTop = 0;
  panelBody.scrollTop = 0;
  history.replaceState(null, '', `#${selected}`);
  applyHighlight();
  if (opts.fly === false) return;
  if (view === 'explore') focusNode(selected);
  // The timeline walks to where the selection began.
  else if (view === 'timeline') tlGoalX = clampTimeline(X(n.start));
}

const KIND_TEXT: Record<string, string> = {
  tradition: 'Tradition',
  council: 'Council',
  schism: 'Split',
  event: 'Event',
  figure: 'Person',
};

function nodeColor(n: HistoryNode) {
  if (n.type === 'tradition') return `#${colorOf(n).getHexString()}`;
  if (n.type === 'council') return '#e9bf55';
  if (n.type === 'schism') return '#e5563f';
  return '#c9cfe0';
}

function chip(id: string) {
  const n = byId.get(id);
  if (!n) return '';
  return `<button type="button" data-go="${n.id}" style="--c:${nodeColor(n)}"><span class="yr">${n.start}</span><i></i>${esc(nameOf(n))}</button>`;
}

function renderPanel(n: HistoryNode) {
  const parts: string[] = [];
  const emblem = EMBLEMS[n.id];
  parts.push(
    `<div class="head" style="--c:${nodeColor(n)}">${emblem ? `<i class="emb big">${emblem}</i>` : ''}<div><div class="kind">${KIND_TEXT[n.type]}, ${yearText(n)}</div><h2>${esc(nameOf(n))}</h2></div></div>`,
  );
  parts.push(`<p class="summary">${esc(n.summary)}</p>`);
  if (n.why) parts.push(`<h3>Why it matters</h3><p class="why">${esc(n.why)}</p>`);

  if (n.sacraments) {
    let cat = '';
    if (n.type === 'tradition') {
      const e = EUCHARIST[eucharistKey(n)];
      cat = `<div class="cat" style="--c:${e.color}"><i></i><span><b>Communion:</b> ${esc(e.name)}${e.note ? `. ${esc(e.note)}.` : ''}</span></div>`;
    }
    parts.push(`<div class="sac"><h3>Sacraments</h3><p>${esc(n.sacraments)}</p>${cat}</div>`);
  }
  if (n.today && n.type === 'tradition' && n.end == null) parts.push(`<p class="today"><b>Today.</b> ${esc(n.today)}</p>`);

  if (n.type === 'tradition') {
    const line = [...ancestors(n.id), n.id];
    if (line.length > 1) {
      parts.push(
        `<h3>Family line</h3><ol class="lineage">${line
          .map((id) => {
            const a = byId.get(id)!;
            const here = id === n.id ? ' class="here"' : '';
            return `<li${here} style="--c:${nodeColor(a)}"><button type="button" data-go="${id}">${esc(nameOf(a))}<small>${a.start}</small></button></li>`;
          })
          .join('')}</ol>`,
      );
    }
    const kids = (childrenOf.get(n.id) ?? []).slice().sort((a, b) => byId.get(a)!.start - byId.get(b)!.start);
    if (kids.length) parts.push(`<h3>Branches that grew from it</h3><div class="chips">${kids.map(chip).join('')}</div>`);
  } else {
    const splits = (n.splits ?? []).filter((s) => visible.has(s));
    if (splits.length) parts.push(`<h3>What came out of it</h3><div class="chips">${splits.map(chip).join('')}</div>`);
  }

  // Everything below is for digging deeper, folded away by default.
  const more: string[] = [];
  if (n.facts?.length) more.push(`<h3>Key facts</h3><ul class="facts">${n.facts.map((f) => `<li>${esc(f)}</li>`).join('')}</ul>`);
  if (n.type === 'tradition') {
    const also = (n.parents ?? []).filter(isTradId).filter((p) => p !== parentOf(n));
    if (also.length) more.push(`<h3>Also shaped by</h3><div class="chips">${also.map(chip).join('')}</div>`);
    const onLine = nodes.filter((m) => m.type !== 'tradition' && m.on === n.id).sort((a, b) => a.start - b.start);
    if (onLine.length) more.push(`<h3>On this line</h3><div class="chips">${onLine.map((m) => chip(m.id)).join('')}</div>`);
  } else if (n.on && byId.has(n.on)) {
    more.push(`<h3>Happened within</h3><div class="chips">${chip(n.on)}</div>`);
  }
  if (n.disputed) more.push(`<h3>Seen differently</h3><p class="disputed">${esc(n.disputed)}</p>`);
  if (n.sources?.length) {
    const links = n.sources
      .map((u) => {
        const book = pelikanCite(u) ?? damickCite(u);
        if (book) return `<cite>${book}</cite>`;
        let host = u;
        try {
          host = new URL(u).hostname.replace(/^www\./, '');
        } catch {
          /* keep raw */
        }
        return `<a href="${esc(u)}" target="_blank" rel="noopener">${esc(host)}</a>`;
      })
      .join(' · ');
    more.push(`<div class="sources">Sources: ${links}</div>`);
  }
  if (more.length) parts.push(`<details class="more"><summary>More about ${esc(nameOf(n))}</summary>${more.join('')}</details>`);
  panelBody.innerHTML = parts.join('');
}

panelBody.addEventListener('click', (e) => {
  const go = (e.target as HTMLElement).closest<HTMLElement>('[data-go]');
  if (go && go.dataset.go !== selected) select(go.dataset.go!);
});
$<HTMLButtonElement>('close').addEventListener('click', () => select(null));

// On portrait phones the panel is a bottom sheet. Pull it down from the handle, or from the
// top of its text, to close it.
let pull: { y: number; t: number; dy: number; on: boolean } | null = null;
panel.addEventListener(
  'touchstart',
  (e) => {
    const sheet = phoneQuery.matches && !sideSheetQuery.matches;
    const fromTop = (e.target as HTMLElement).closest('.grab') || panelBody.scrollTop <= 0;
    pull = sheet && fromTop && e.touches.length === 1 ? { y: e.touches[0].clientY, t: performance.now(), dy: 0, on: false } : null;
  },
  { passive: true },
);
panel.addEventListener(
  'touchmove',
  (e) => {
    if (!pull) return;
    const dy = e.touches[0].clientY - pull.y;
    if (!pull.on && dy < 4) {
      // Moving up scrolls the text as usual.
      if (dy < -4) pull = null;
      return;
    }
    e.preventDefault();
    pull.on = true;
    pull.dy = Math.max(0, dy);
    panel.style.transition = 'none';
    panel.style.transform = `translateY(${pull.dy}px)`;
  },
  { passive: false },
);
panel.addEventListener('touchend', () => {
  if (!pull?.on) {
    pull = null;
    return;
  }
  const fast = pull.dy / (performance.now() - pull.t) > 0.5;
  const close = pull.dy > panel.offsetHeight * 0.3 || (fast && pull.dy > 40);
  pull = null;
  panel.style.transition = reduceMotion ? 'none' : 'transform 0.2s ease-out';
  panel.style.transform = close ? 'translateY(100%)' : '';
  const done = () => {
    panel.style.transition = '';
    panel.style.transform = '';
    if (close) select(null);
  };
  if (reduceMotion) done();
  else setTimeout(done, 200);
});
panel.addEventListener('touchcancel', () => {
  pull = null;
  panel.style.transform = '';
});

// ---------------------------------------------------------------------------
// Communion legend, only shown in that color mode

const legend = $<HTMLElement>('legend');
// Phones can fold the key away, since it covers the top of the map.
let legendFolded = false;
const CHEVRON = $<HTMLButtonElement>('story-toggle').innerHTML;
legend.addEventListener('click', (e) => {
  if (!(e.target as HTMLElement).closest('.legend-toggle')) return;
  legendFolded = !legendFolded;
  legend.classList.toggle('folded', legendFolded);
  renderLegend();
  dirty = true;
});
function renderLegend() {
  legend.hidden = mode !== 'eucharist';
  if (legend.hidden) return;
  const used = new Set([...branches.values()].map((b) => eucharistKey(b.node)));
  legend.innerHTML = `<button type="button" class="legend-toggle" aria-expanded="${!legendFolded}" aria-label="${legendFolded ? 'Show the key' : 'Hide the key'}">${CHEVRON}</button><h4>What happens at communion</h4><ul>${Object.entries(EUCHARIST)
    .filter(([k]) => used.has(k))
    .map(([, s]) => `<li style="--c:${s.color}"><i></i><span>${esc(s.name)}${s.note ? `<small>${esc(s.note)}</small>` : ''}</span></li>`)
    .join('')}</ul><p class="legend-note">Colors show each tradition's main emphasis. Many views overlap.</p>`;
  fitLegend();
}
// On wide screens the key sits above the story card. Stop it there and let it scroll.
function fitLegend() {
  legend.style.maxHeight = '';
  legend.style.overflowY = '';
  const card = document.getElementById('story');
  if (legend.hidden || !card || card.hidden) return;
  const l = legend.getBoundingClientRect();
  const c = card.getBoundingClientRect();
  const sideBySide = l.right <= c.left || c.right <= l.left;
  if (sideBySide || c.top <= l.top || l.bottom <= c.top - 12) return;
  legend.style.maxHeight = `${Math.max(120, c.top - l.top - 12)}px`;
  legend.style.overflowY = 'auto';
}
addEventListener('resize', fitLegend);

document.querySelectorAll<HTMLButtonElement>('.seg button').forEach((btn) => {
  btn.addEventListener('click', () => {
    mode = btn.dataset.mode as Mode;
    document.querySelectorAll('.seg button').forEach((b) => b.setAttribute('aria-pressed', String(b === btn)));
    applyColors();
    if (selected) renderPanel(byId.get(selected)!);
  });
});

// ---------------------------------------------------------------------------
// Detail switch

const detail = $<HTMLInputElement>('detail');
function setDetail(isSimple: boolean) {
  if (simple === isSimple) return;
  simple = isSimple;
  detail.checked = !simple;
  computeVisible();
  if (selected && !visible.has(selected)) {
    selected = null;
    lit = null;
    showPanel(false);
  }
  build();
  if (selected) select(selected, { fly: false });
}
detail.addEventListener('change', () => {
  setDetail(!detail.checked);
  goChapter(chapter);
});

// ---------------------------------------------------------------------------
// The story, told in chapters

const storyBody = $<HTMLDivElement>('story-body');
const dots = $<HTMLOListElement>('dots');
let chapter = 0;
dots.innerHTML = CHAPTERS.map((c, i) => `<li><button type="button" data-ch="${i}" aria-label="${esc(c.title)}"></button></li>`).join('');

function renderChapter() {
  const c = CHAPTERS[chapter];
  const text = (tall && c.tallText) || c.text;
  let label = chapter === 0 ? 'The whole story' : `Chapter ${chapter} of ${CHAPTERS.length - 1}`;
  if (view === 'timeline' && chapter === 1) label = tall ? 'Swipe up to move through time' : 'Scroll or drag to move through time';
  const year = view === 'timeline' ? `<span class="tl-year" id="tl-year">${Math.round(yearAtX(tlX))}</span>` : '';
  storyBody.innerHTML = `<div class="ch-label"><span>${label}</span>${year}</div><h2>${esc(c.title)}</h2><p><span class="drop">${esc(text.charAt(0))}</span>${esc(text.slice(1))}</p>`;
  dots.querySelectorAll('button').forEach((b, i) => b.setAttribute('aria-current', String(i === chapter)));
  $<HTMLButtonElement>('prev').disabled = chapter <= (view === 'timeline' ? 1 : 0);
  $<HTMLButtonElement>('next').disabled = chapter === CHAPTERS.length - 1;
}
function goChapter(i: number, dur?: number) {
  if (view === 'timeline') {
    chapter = THREE.MathUtils.clamp(i, 1, CHAPTERS.length - 1);
    tlGoalX = clampTimeline(X(CHAPTERS[chapter].focus));
    renderChapter();
    return;
  }
  if (view !== 'explore') return;
  chapter = THREE.MathUtils.clamp(i, 0, CHAPTERS.length - 1);
  renderChapter();
  const c = CHAPTERS[chapter];
  flyToRange(c.from, c.to, dur);
}
$<HTMLButtonElement>('prev').addEventListener('click', () => goChapter(chapter - 1));
$<HTMLButtonElement>('next').addEventListener('click', () => goChapter(chapter + 1));
dots.addEventListener('click', (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-ch]');
  if (b) goChapter(Number(b.dataset.ch));
});

// Phones can fold the story down to its title and arrows to give the map more room.
const story = $<HTMLElement>('story');
// The card's height changes with each chapter.
new ResizeObserver(fitLegend).observe(story);
const storyToggle = $<HTMLButtonElement>('story-toggle');
function toggleStory() {
  const open = story.classList.toggle('collapsed') === false;
  storyToggle.setAttribute('aria-expanded', String(open));
  storyToggle.setAttribute('aria-label', open ? 'Hide the text' : 'Show the text');
  if (!selected) goChapter(chapter);
}
storyToggle.addEventListener('click', toggleStory);
storyBody.addEventListener('click', (e) => {
  if (phoneQuery.matches && (e.target as HTMLElement).closest('h2')) toggleStory();
});

// ---------------------------------------------------------------------------
// Search

const q = $<HTMLInputElement>('q');
const results = $<HTMLUListElement>('results');
let hitIndex = 0;
function runSearch() {
  const s = q.value.trim().toLowerCase();
  if (!s) {
    results.hidden = true;
    return;
  }
  const hits = nodes
    .map((n) => {
      const name = nameOf(n).toLowerCase();
      const full = n.name.toLowerCase();
      const score = name.startsWith(s) || full.startsWith(s) ? 0 : name.includes(s) || full.includes(s) ? 1 : n.summary.toLowerCase().includes(s) ? 2 : 9;
      return { n, score: score + (visible.has(n.id) ? 0 : 0.5) };
    })
    .filter((h) => h.score < 9)
    .sort((a, b) => a.score - b.score || a.n.importance - b.n.importance || a.n.start - b.n.start)
    .slice(0, 8)
    .map((h) => h.n);
  hitIndex = 0;
  results.innerHTML = hits.length
    ? hits
        .map(
          (n, i) =>
            `<li role="option" data-go="${n.id}" aria-selected="${i === 0}">${esc(nameOf(n))}<span>${KIND_TEXT[n.type]}, ${n.start}</span></li>`,
        )
        .join('')
    : `<li aria-disabled="true">No match. Try a church name or a year like 1054.</li>`;
  if (/^\d{2,4}$/.test(s)) {
    const y = Number(s);
    results.insertAdjacentHTML('afterbegin', `<li data-year="${y}">Go to the year ${y}<span>Timeline</span></li>`);
  }
  results.hidden = false;
}
function pickHit(el: HTMLElement | null) {
  if (!el) return;
  if (el.dataset.go) select(el.dataset.go);
  if (el.dataset.year) {
    const y = THREE.MathUtils.clamp(Number(el.dataset.year), FIRST_YEAR, NOW);
    if (view === 'timeline') tlGoalX = clampTimeline(X(y));
    else {
      setView('explore');
      flyToRange(y - 60, y + 60);
    }
  }
  results.hidden = true;
  q.value = '';
  q.blur();
}
q.addEventListener('input', runSearch);
q.addEventListener('keydown', (e) => {
  const items = [...results.querySelectorAll<HTMLElement>('li[data-go],li[data-year]')];
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    e.preventDefault();
    hitIndex = (hitIndex + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % Math.max(1, items.length);
    items.forEach((li, i) => li.setAttribute('aria-selected', String(i === hitIndex)));
  } else if (e.key === 'Enter') {
    pickHit(items[hitIndex] ?? items[0] ?? null);
  } else if (e.key === 'Escape') {
    q.value = '';
    results.hidden = true;
    q.blur();
  }
});
results.addEventListener('pointerdown', (e) => {
  e.preventDefault();
  pickHit((e.target as HTMLElement).closest<HTMLElement>('li[data-go],li[data-year]'));
});
q.addEventListener('blur', () =>
  setTimeout(() => {
    results.hidden = true;
    if (!q.value) search.classList.remove('open');
  }, 100),
);
// Portrait phones show a search button that opens the field over the title.
const search = $<HTMLDivElement>('search');
$<HTMLButtonElement>('search-btn').addEventListener('click', () => {
  search.classList.add('open');
  q.focus();
});

// ---------------------------------------------------------------------------
// Picking in the scene

const ray = new THREE.Raycaster();
const pointer = new THREE.Vector2();
let downAt: { x: number; y: number } | null = null;
function rayAt(clientX: number, clientY: number) {
  const r = renderer.domElement.getBoundingClientRect();
  pointer.set(((clientX - r.left) / r.width) * 2 - 1, -((clientY - r.top) / r.height) * 2 + 1);
  ray.setFromCamera(pointer, camera);
  for (const h of ray.intersectObjects(pickables, true)) {
    const id = h.object.userData.id as string | undefined;
    if (!id) continue;
    const m = markerById.get(id);
    if (m && !m.group.visible) continue;
    return id;
  }
  return null;
}
/** The label nearest the point, within slop pixels. Touch screens let taps through labels. */
function labelAt(x: number, y: number, slop: number) {
  let best: string | null = null;
  let bestD = Infinity;
  for (const l of labels) {
    if (!l.id || !l.obj.visible) continue;
    const r = l.el.getBoundingClientRect();
    const d = Math.hypot(Math.max(r.left - x, 0, x - r.right), Math.max(r.top - y, 0, y - r.bottom));
    if (d <= slop && d < bestD) {
      best = l.id;
      bestD = d;
    }
  }
  return best;
}
/** Fingers are blunt, so touch searches outward in rings until a label or line turns up. */
function pickAt(clientX: number, clientY: number, touch = false) {
  for (const radius of touch ? [0, 8, 16, 24] : [0]) {
    const label = labelAt(clientX, clientY, radius);
    if (label) return label;
    const steps = radius ? 8 : 1;
    for (let i = 0; i < steps; i++) {
      const a = (i / steps) * Math.PI * 2;
      const id = rayAt(clientX + Math.cos(a) * radius, clientY + Math.sin(a) * radius);
      if (id) return id;
    }
  }
  return null;
}
renderer.domElement.addEventListener('pointerdown', (e) => {
  downAt = { x: e.clientX, y: e.clientY };
});
renderer.domElement.addEventListener('pointerup', (e) => {
  if (!downAt) return;
  const moved = Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y);
  downAt = null;
  const touch = e.pointerType === 'touch';
  if (moved > (touch ? 10 : 6)) return;
  select(pickAt(e.clientX, e.clientY, touch));
});
let hoverQueued = false;
renderer.domElement.addEventListener('pointermove', (e) => {
  if (hoverQueued || e.buttons || e.pointerType !== 'mouse') return;
  hoverQueued = true;
  requestAnimationFrame(() => {
    hoverQueued = false;
    renderer.domElement.style.cursor = rayAt(e.clientX, e.clientY) ? 'pointer' : '';
  });
});

addEventListener('keydown', (e) => {
  if (document.activeElement === q) return;
  if (view !== 'timeline' && view !== 'explore' && e.key.startsWith('Arrow')) return;
  if (e.key === '/') {
    e.preventDefault();
    q.focus();
  } else if (e.key === 'Escape') {
    select(null);
  } else if (e.key === 'ArrowRight') {
    goChapter(chapter + 1);
  } else if (e.key === 'ArrowLeft') {
    goChapter(chapter - 1);
  }
});

// ---------------------------------------------------------------------------
// Label layout: show what fits at this zoom, hide what would overlap

const proj = new THREE.Vector3();
function isLit(l: Label) {
  if (!lit || !l.id) return false;
  if (l.id === selected || lit.has(l.id)) return true;
  const m = markerById.get(l.id);
  return !!m && markerLit(m);
}

/** Phones have no spare width, so slide a label along its anchor to keep it on screen. */
function slide(l: Label, sx: number, w: number) {
  const cx = THREE.MathUtils.clamp(THREE.MathUtils.clamp(l.cx, (sx + l.w + 4 - w) / l.w, (sx - 4) / l.w), 0, 1);
  l.obj.center.x = cx;
  return cx;
}

function layoutLabels() {
  const w = stage.clientWidth;
  const h = stage.clientHeight;
  const zoom = camera.position.distanceTo(controls.target);
  const placed: number[] = [];
  const fits = (x0: number, y0: number, x1: number, y1: number) => {
    for (let i = 0; i < placed.length; i += 4) {
      if (x0 < placed[i + 2] && x1 > placed[i] && y0 < placed[i + 3] && y1 > placed[i + 1]) return false;
    }
    return true;
  };
  const order = lit ? [...sortedLabels].sort((a, b) => Number(isLit(b)) - Number(isLit(a))) : sortedLabels;
  // On phones the map runs under the controls and cards, so labels there would be hidden anyway.
  if (phone) {
    for (const c of chromeRects()) placed.push(c.l, c.t, c.r, c.b);
    // So would anything cut by the screen edge.
    placed.push(-1e4, -1e4, 1e4, 0, -1e4, h, 1e4, 1e4, -1e4, -1e4, 0, 1e4, w, -1e4, 1e4, 1e4);
    // Years can crowd where the early centuries recede, so they skip each other too.
    const years: number[][] = [];
    for (const l of labels) {
      if (!l.fixed) continue;
      proj.copy(l.obj.position).project(camera);
      const sx = ((proj.x + 1) / 2) * w;
      const x0 = sx - slide(l, sx, w) * l.w;
      const y0 = ((1 - proj.y) / 2) * h - l.cy * l.h;
      const box = [x0, y0, x0 + l.w, y0 + l.h];
      l.obj.visible = fits(box[0], box[1], box[2], box[3]) && !years.some((o) => box[0] < o[2] && box[2] > o[0] && box[1] < o[3] && box[3] > o[1]);
      if (l.obj.visible) years.push(box);
    }
  }
  for (const l of order) {
    let on = true;
    if (l.id !== selected) {
      if (!simple) on = zoom < (l.imp === 1 ? Infinity : l.imp === 2 ? 420 : 210);
      if (lit && !isLit(l)) on = false;
    }
    if (on) {
      proj.copy(l.obj.position).project(camera);
      if (proj.z > 1 || proj.x < -1.2 || proj.x > 1.2 || proj.y < -1.2 || proj.y > 1.2) on = false;
      else {
        const sx = ((proj.x + 1) / 2) * w;
        const sy = ((1 - proj.y) / 2) * h;
        const x0 = sx - (phone ? slide(l, sx, w) : l.cx) * l.w;
        const y0 = sy - l.cy * l.h;
        // A label the screen edge would cut reads as a mistake, so leave it out.
        if (l.id !== selected && (x0 < 0 || x0 + l.w > w || y0 < 0 || y0 + l.h > h)) on = false;
        else if (fits(x0 - 2, y0 - 1, x0 + l.w + 2, y0 + l.h + 1) || l.id === selected) placed.push(x0, y0, x0 + l.w, y0 + l.h);
        else on = false;
      }
    }
    l.obj.visible = on;
  }
}


// ---------------------------------------------------------------------------
// Views: a guided timeline, the free 3D map, and two flat screens

type View = 'timeline' | 'explore' | 'church' | 'sacraments';
let view: View = 'explore';
const viewsNav = $<HTMLElement>('views');
const churchScreen = $<HTMLElement>('screen-church');
const sacramentScreen = $<HTMLElement>('screen-sacraments');

/** The timeline holds the camera on a rail. Scrolling moves the reader through time. */
let tlX = X(FIRST_YEAR);
let tlGoalX = tlX;
let tlDirty = true;
let railDist = 0;
const railTarget = new THREE.Vector3();
const railGoal = new THREE.Vector3();
let railGoalDist = 0;
const railDir = new THREE.Vector3();
/** World units of time in view at once. Portrait screens show less. */
const tlSpan = () => (tall ? 110 : phoneQuery.matches ? 130 : 165);
const clampTimeline = (x: number) => THREE.MathUtils.clamp(x, X(FIRST_YEAR), X(NOW));

// A curtain of gold light marks the reader's year.
function curtainTexture() {
  const c = document.createElement('canvas');
  c.width = 4;
  c.height = 128;
  const g = c.getContext('2d')!;
  const grad = g.createLinearGradient(0, 0, 0, 128);
  grad.addColorStop(0, 'rgba(233,191,85,0)');
  grad.addColorStop(1, 'rgba(233,191,85,0.55)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 4, 128);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}
const cursor = new THREE.Group();
const curtain = new THREE.Mesh(
  new THREE.PlaneGeometry(1, 1),
  new THREE.MeshBasicMaterial({ map: curtainTexture(), transparent: true, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, fog: false }),
);
curtain.rotation.y = Math.PI / 2;
const floorLine = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ color: GOLD, transparent: true, opacity: 0.75, depthWrite: false, fog: false }));
floorLine.rotation.x = -Math.PI / 2;
cursor.add(curtain, floorLine);
// The reader's year, written on the floor where the gold line meets the year labels.
const cursorYearEl = document.createElement('div');
cursorYearEl.className = 'lbl year cursor-year';
const cursorYear = new CSS2DObject(cursorYearEl);
cursorYear.center.set(0.5, 0);
cursor.add(cursorYear);
cursor.visible = false;
scene.add(cursor);
function sizeCursor() {
  // Tall screens look along the curtain's face, so it would fill the view. The floor line is enough there.
  curtain.visible = !tall;
  const span = Z_MAX - Z_MIN + 36;
  const mid = (Z_MIN + Z_MAX) / 2;
  curtain.scale.set(span, 18, 1);
  curtain.position.set(0, 9, mid);
  floorLine.scale.set(0.45, span, 1);
  floorLine.position.set(0, -0.5, mid);
  // Tall screens stack the years in a column at the screen edge, so the pill joins that column.
  cursorYear.position.set(0, -0.6, Z_MAX + (tall ? 14 : 21));
}

function timelineFrame(x: number) {
  const span = tlSpan();
  const end = X(NOW) + (roomInPixels() ? 4 : 34);
  const cx = THREE.MathUtils.clamp(x, X(FIRST_YEAR) - 8 + span / 2, end - span / 2);
  const y0 = yearAtX(cx - span / 2);
  const y1 = yearAtX(cx + span / 2);
  // Close in on the lines that branch in view. Today pulls back to show every living line.
  const [lo, hi] = y1 >= NOW - 1 ? zRangeFor(y0, y1) : branchingZRange(y0, y1);
  return fitBox(new THREE.Vector3(cx - span / 2, 0, lo - 6), new THREE.Vector3(cx + span / 2, 12, hi + 6), defaultDir(), {
    hang: y1 >= NOW - 1,
  });
}

function chapterForYear(y: number) {
  let c = 1;
  for (let i = 2; i < CHAPTERS.length; i++) if (y >= (CHAPTERS[i - 1].focus + CHAPTERS[i].focus) / 2) c = i;
  return c;
}

function stepTimeline() {
  const dx = tlGoalX - tlX;
  if (Math.abs(dx) > 0.01) {
    tlX += reduceMotion ? dx : dx * 0.16;
    tlDirty = true;
    cursor.position.x = tlX;
    const year = yearAtX(tlX);
    const c = chapterForYear(year);
    if (c !== chapter) {
      chapter = c;
      renderChapter();
    }
    const el = document.getElementById('tl-year');
    if (el) el.textContent = String(Math.round(year));
    cursorYearEl.textContent = String(Math.round(year));
  }
  if (tlDirty) {
    const f = timelineFrame(tlX);
    railGoal.copy(f.target);
    railGoalDist = f.dist;
    tlDirty = false;
  }
  // Ease toward the rail, so turning back from Explore or a new chapter glides.
  const k = reduceMotion ? 1 : 0.14;
  const goalDir = defaultDir();
  const moving =
    railTarget.distanceToSquared(railGoal) > 1e-4 || Math.abs(railDist - railGoalDist) > 0.01 || railDir.distanceToSquared(goalDir) > 1e-6;
  if (!moving) return;
  railTarget.lerp(railGoal, k);
  railDist += (railGoalDist - railDist) * k;
  railDir.lerp(goalDir, k).normalize();
  controls.target.copy(railTarget);
  camera.position.copy(railTarget).addScaledVector(railDir, railDist);
  dirty = true;
}

/** Scroll and drag distance in pixels, turned into time. */
function nudge(px: number) {
  const size = tall ? stage.clientHeight : stage.clientWidth;
  tlGoalX = clampTimeline(tlGoalX + (px * tlSpan()) / size);
}
renderer.domElement.addEventListener(
  'wheel',
  (e) => {
    if (view !== 'timeline') return;
    e.preventDefault();
    const px = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
    nudge(px * (e.deltaMode === 1 ? 16 : 1));
  },
  { passive: false },
);
let drag: { x: number; y: number; goal: number; id: number } | null = null;
renderer.domElement.addEventListener('pointerdown', (e) => {
  if (view !== 'timeline' || !e.isPrimary) return;
  drag = { x: e.clientX, y: e.clientY, goal: tlGoalX, id: e.pointerId };
  renderer.domElement.setPointerCapture(e.pointerId);
});
renderer.domElement.addEventListener('pointermove', (e) => {
  if (!drag || e.pointerId !== drag.id) return;
  // Tall screens run time down the page, wide ones left to right. Dragging pulls the map along.
  const px = tall ? drag.y - e.clientY : drag.x - e.clientX;
  tlGoalX = drag.goal;
  nudge(px);
});
const endDrag = () => (drag = null);
renderer.domElement.addEventListener('pointerup', endDrag);
renderer.domElement.addEventListener('pointercancel', endDrag);

/** Traditions on the simple map, from Jesus down to this one. Used by "My church". */
function simpleLineage(id: string) {
  const keep = new Set(SIMPLE_TRADITIONS);
  const line = [id];
  let cur = byId.get(id);
  while (cur) {
    let p = cur.parents?.find(isTradId);
    while (p && !keep.has(p)) p = byId.get(p)!.parents?.find(isTradId);
    if (!p || line.includes(p)) break;
    line.unshift(p);
    cur = byId.get(p);
  }
  return line;
}

const screenDeps: ScreenDeps = {
  byId,
  nameOf,
  colorOf: (id) => `#${colorOf(byId.get(id)!).getHexString()}`,
  lineage: simpleLineage,
  // Councils and splits that happened while the line ran through each step.
  momentsOn: (ids) =>
    SIMPLE_MARKERS.map((id) => byId.get(id)!).filter((m) => {
      const i = ids.indexOf(m.on ?? '');
      if (i < 0) return false;
      const next = ids[i + 1] ? byId.get(ids[i + 1])!.start : Infinity;
      return m.start <= next;
    }),
  open: (id) => select(id, { fly: false }),
  showOnMap: (id) => {
    setView('explore');
    select(id);
  },
  showSacraments: (id) => setView('sacraments', id),
  choices: SIMPLE_ORDER.filter((id) => id !== '__trunk__'),
};
bindChurch(churchScreen, screenDeps);
bindSacraments(sacramentScreen, screenDeps);

function setView(v: View, focus?: string) {
  const from = view;
  view = v;
  app.dataset.view = v;
  viewsNav.querySelectorAll<HTMLButtonElement>('[data-view]').forEach((b) => b.setAttribute('aria-current', String(b.dataset.view === v)));
  churchScreen.hidden = v !== 'church';
  sacramentScreen.hidden = v !== 'sacraments';
  controls.enabled = v === 'explore';
  cursor.visible = v === 'timeline';
  $<HTMLElement>('hint').textContent =
    v === 'explore' ? 'Drag to turn. Scroll to zoom. Click any line.' : 'Scroll or drag to move through time. Click any line.';
  if (v === 'timeline') {
    tween = null;
    // Pick up where the camera is looking, so switching views never jumps.
    if (from !== 'timeline') {
      if (from === 'explore') tlX = tlGoalX = clampTimeline(controls.target.x);
      railTarget.copy(controls.target);
      railDir.copy(camera.position).sub(controls.target).normalize();
      railDist = camera.position.distanceTo(controls.target);
    }
    cursor.position.x = tlX;
    cursorYearEl.textContent = String(Math.round(yearAtX(tlX)));
    tlDirty = true;
    chapter = chapterForYear(yearAtX(tlX));
    renderChapter();
  } else if (v === 'explore') {
    renderChapter();
    if (from !== 'explore') {
      if (selected) focusNode(selected);
      else goChapter(chapter);
    }
  } else if (v === 'church') {
    renderChurch(churchScreen, screenDeps);
    churchScreen.scrollTop = 0;
  } else {
    renderSacraments(sacramentScreen, screenDeps, focus);
  }
  dirty = true;
}
viewsNav.addEventListener('click', (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-view]');
  if (b && b.dataset.view !== view) setView(b.dataset.view as View);
});

// ---------------------------------------------------------------------------
// Loop

function resize() {
  const w = stage.clientWidth;
  const h = stage.clientHeight;
  renderer.setSize(w, h);
  labelRenderer.setSize(w, h);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  dirty = true;
  tlDirty = true;
  curtain.visible = !camera.aspect || camera.aspect >= 0.85;
  cursorYear.position.z = Z_MAX + (camera.aspect < 0.85 ? 14 : 21);
  // At the screen edge the pill starts at its point instead of centering on it.
  cursorYear.center.x = camera.aspect < 0.85 ? 0 : 0.5;
  if (tall === camera.aspect < 0.85 && phone === phoneQuery.matches) return;
  tall = camera.aspect < 0.85;
  phone = phoneQuery.matches;
  orientLabels();
  renderChapter();
  // A phone turned on its side needs the whole frame again. Skip it while the keyboard is up.
  if (phoneQuery.matches && labels.length && document.activeElement !== q) {
    if (selected) focusNode(selected);
    else goChapter(chapter);
  }
}
addEventListener('resize', resize);
controls.addEventListener('change', () => (dirty = true));
controls.addEventListener('start', () => (tween = null));

const tmpDir = new THREE.Vector3();
function frame(now: number) {
  if (view === 'timeline') stepTimeline();
  if (tween) {
    const k = Math.min(1, (now - tween.t0) / tween.dur);
    const e = ease(k);
    controls.target.lerpVectors(tween.fromT, tween.toT, e);
    tmpDir.copy(tween.fromDir).lerp(tween.toDir, e).normalize();
    const d = Math.exp(Math.log(tween.fromD) + (Math.log(tween.toD) - Math.log(tween.fromD)) * e);
    camera.position.copy(controls.target).addScaledVector(tmpDir, d);
    if (k >= 1) tween = null;
    dirty = true;
  }
  controls.update();
  // Draw only when something changed, so a still map costs a phone nothing.
  if (dirty) {
    const zoom = camera.position.distanceTo(controls.target);
    const fog = scene.fog as THREE.Fog;
    fog.near = zoom * 0.9;
    fog.far = zoom * 2.8 + 200;
    layoutLabels();
    dirty = false;
    renderer.render(scene, camera);
    labelRenderer.render(scene, camera);
  }
  requestAnimationFrame(frame);
}

function start() {
  resize();
  build();
  renderChapter();
  const fromHash = decodeURIComponent(location.hash.slice(1));
  // Open close on the fish at the start of the line, then pull back to the whole story.
  flyTo(new THREE.Vector3(X(60), 0, laneZ.get('__trunk__')!), 70, defaultDir(), 0);
  requestAnimationFrame(frame);
  $<HTMLDivElement>('loading').classList.add('done');
  // The timeline rail eases the camera back from the fish on its own.
  railDist = 70;
  setView('timeline');
  if (fromHash && byId.has(fromHash)) select(fromHash);
}

document.fonts.ready.then(start);
