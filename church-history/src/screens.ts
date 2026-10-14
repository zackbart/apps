// The two flat views: "My church" traces one line back to Jesus, and "Sacraments"
// lays the rites of every tradition side by side. Both reuse the map's detail panel.

import type { HistoryNode } from './types';
import { EMBLEMS } from './emblems';
import sacramentData from './data/sacraments.json';
import stepData from './data/steps.json';

type Status = 'sacrament' | 'ordinance' | 'rite' | 'none' | 'varies';
interface Rite {
  id: string;
  name: string;
  short: string;
  what: string;
}
interface Row {
  id: string;
  summary: string;
  cells: Record<string, { status: Status; note: string }>;
  sources: string[];
}
const RITES = sacramentData.rites as Rite[];
const ROWS = sacramentData.rows as Row[];
const STEPS = stepData.steps as Record<string, string>;

export const STATUS_TEXT: Record<Status, string> = {
  sacrament: 'Sacrament',
  ordinance: 'Ordinance',
  rite: 'A rite, not a sacrament',
  none: 'Not a formal rite',
  varies: 'Varies by church',
};

export interface ScreenDeps {
  byId: Map<string, HistoryNode>;
  nameOf: (n: HistoryNode) => string;
  colorOf: (id: string) => string;
  /** The line from Jesus down to this tradition, oldest first. */
  lineage: (id: string) => string[];
  /** Councils and splits along these lines, oldest first. */
  momentsOn: (ids: string[]) => HistoryNode[];
  open: (id: string) => void;
  showOnMap: (id: string) => void;
  showSacraments: (id: string) => void;
  /** Traditions to offer, in the order they sit on the map. */
  choices: string[];
}

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
const STORE = 'church-history:my-church';

export function myChurch() {
  try {
    return localStorage.getItem(STORE);
  } catch {
    return null;
  }
}
function remember(id: string) {
  try {
    localStorage.setItem(STORE, id);
  } catch {
    /* private mode */
  }
}

function emblem(id: string, color: string, cls = '') {
  const svg = EMBLEMS[id];
  return svg ? `<i class="emb ${cls}" style="--c:${color}">${svg}</i>` : `<i class="dot ${cls}" style="--c:${color}"></i>`;
}

// ---------------------------------------------------------------------------
// My church

export function renderChurch(root: HTMLElement, deps: ScreenDeps) {
  const mine = myChurch();
  const chips = deps.choices
    .map((id) => {
      const n = deps.byId.get(id)!;
      return `<button type="button" class="pick" data-pick="${id}" aria-pressed="${id === mine}" style="--c:${deps.colorOf(id)}">${emblem(id, deps.colorOf(id))}${esc(deps.nameOf(n))}</button>`;
    })
    .join('');

  let path = `<p class="empty">Pick a church above to see the path from Jesus to it.</p>`;
  if (mine && deps.byId.has(mine)) {
    const line = deps.lineage(mine);
    const items: { year: number; html: string }[] = line.map((id) => {
      const n = deps.byId.get(id)!;
      const here = id === mine;
      const years = n.end == null ? `${n.start} to today` : `${n.start} to ${n.end}`;
      return {
        year: n.start,
        html: `<li class="step${here ? ' here' : ''}" style="--c:${deps.colorOf(id)}">${emblem(id, deps.colorOf(id), 'mark')}<button type="button" data-open="${id}"><b>${esc(deps.nameOf(n))}</b><em>${years}</em></button><p>${esc(STEPS[id] ?? n.why ?? n.summary)}${here ? ' <strong>This is your church.</strong>' : ''}</p></li>`,
      };
    });
    for (const m of deps.momentsOn(line)) {
      const kind = m.type === 'council' ? 'council' : 'split';
      items.push({
        // A council or split comes just before the branch it starts.
        year: m.start - 0.5,
        html: `<li class="moment ${kind}"><i class="mark"></i><button type="button" data-open="${m.id}">${esc(deps.nameOf(m))}<em>${m.start}</em></button></li>`,
      });
    }
    items.sort((a, b) => a.year - b.year);
    // The connector takes on each step's color, so the line reads like the map.
    const stops = line.map((id, i) => `${deps.colorOf(id)} ${Math.round((i / Math.max(1, line.length - 1)) * 100)}%`).join(', ');
    path = `<ol class="path" style="--line:linear-gradient(${stops})">${items.map((i) => i.html).join('')}</ol>
      <div class="actions">
        <button type="button" data-map="${mine}">See it on the map</button>
        <button type="button" data-sac="${mine}">Compare its sacraments</button>
      </div>`;
  }

  root.innerHTML = `<div class="screen-inner">
    <h2>Where did my church come from?</h2>
    <p class="lede">Pick your church to trace its line back to Jesus, one step at a time.</p>
    <div class="picks">${chips}</div>
    ${path}
  </div>`;
}

export function bindChurch(root: HTMLElement, deps: ScreenDeps) {
  root.addEventListener('click', (e) => {
    const t = e.target as HTMLElement;
    const pick = t.closest<HTMLElement>('[data-pick]');
    if (pick) {
      remember(pick.dataset.pick!);
      renderChurch(root, deps);
      root.querySelector('.path')?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      return;
    }
    const open = t.closest<HTMLElement>('[data-open]');
    if (open) return deps.open(open.dataset.open!);
    const map = t.closest<HTMLElement>('[data-map]');
    if (map) return deps.showOnMap(map.dataset.map!);
    const sac = t.closest<HTMLElement>('[data-sac]');
    if (sac) deps.showSacraments(sac.dataset.sac!);
  });
}

// ---------------------------------------------------------------------------
// Sacraments

let picked: { row: string; rite: string } | null = null;

const mark = (s: Status) => `<i class="mk ${s}" aria-hidden="true"></i>`;

function noteHtml(deps: ScreenDeps) {
  if (!picked) {
    return `<p class="hint-note">Tap any mark to see what that church does. Tap a church's name for its full story.</p>`;
  }
  const rite = RITES.find((r) => r.id === picked!.rite);
  const row = ROWS.find((r) => r.id === picked!.row);
  if (!rite) return '';
  if (!row) return `<h4>${esc(rite.name)}</h4><p>${esc(rite.what)}</p>`;
  const n = deps.byId.get(row.id)!;
  const cell = row.cells[rite.id];
  return `<div class="note-head">${emblem(row.id, deps.colorOf(row.id))}<div><small>${esc(deps.nameOf(n))}</small><h4>${esc(rite.name)}</h4></div><span class="status ${cell.status}">${mark(cell.status)}${STATUS_TEXT[cell.status]}</span></div><p>${esc(cell.note)}</p><p class="what">${esc(rite.name)}: ${esc(rite.what)}</p>`;
}

export function renderSacraments(root: HTMLElement, deps: ScreenDeps, focus?: string) {
  const mine = focus ?? myChurch();
  const head = RITES.map((r) => `<th scope="col"><button type="button" data-rite="${r.id}">${esc(r.short)}</button></th>`).join('');
  const body = ROWS.map((row) => {
    const n = deps.byId.get(row.id);
    if (!n) return '';
    const cells = RITES.map((r) => {
      const c = row.cells[r.id];
      const on = picked?.row === row.id && picked.rite === r.id;
      return `<td><button type="button" data-cell="${row.id}|${r.id}" aria-pressed="${on}" aria-label="${esc(deps.nameOf(n))}, ${esc(r.name)}: ${STATUS_TEXT[c.status]}">${mark(c.status)}</button></td>`;
    }).join('');
    return `<tr class="${row.id === mine ? 'mine' : ''}"><th scope="row"><button type="button" data-open="${row.id}" style="--c:${deps.colorOf(row.id)}">${emblem(row.id, deps.colorOf(row.id))}<span>${esc(deps.nameOf(n))}</span></button></th>${cells}</tr>`;
  }).join('');
  const key = (Object.keys(STATUS_TEXT) as Status[]).map((s) => `<span>${mark(s)}${STATUS_TEXT[s]}</span>`).join('');

  root.innerHTML = `<div class="screen-inner wide">
    <h2>The sacraments, side by side</h2>
    <p class="lede">Which churches treat each rite as a sacrament. An ordinance is a practice kept in obedience to Christ. Churches differ over how it relates to grace.</p>
    <div class="key">${key}</div>
    <div class="sac-layout">
      <div class="grid-wrap"><table class="sac-grid"><thead><tr><th></th>${head}</tr></thead><tbody>${body}</tbody></table></div>
      <aside class="cell-note" aria-live="polite">${noteHtml(deps)}</aside>
    </div>
  </div>`;
  if (mine) root.querySelector('tr.mine')?.scrollIntoView({ block: 'nearest' });
}

export function bindSacraments(root: HTMLElement, deps: ScreenDeps) {
  root.addEventListener('click', (e) => {
    const t = e.target as HTMLElement;
    const cell = t.closest<HTMLElement>('[data-cell]');
    const rite = t.closest<HTMLElement>('[data-rite]');
    if (cell || rite) {
      const [row, r] = cell ? cell.dataset.cell!.split('|') : ['', rite!.dataset.rite!];
      picked = { row, rite: r };
      root.querySelectorAll('[data-cell]').forEach((b) => b.setAttribute('aria-pressed', String(b === cell)));
      const note = root.querySelector<HTMLElement>('.cell-note')!;
      note.innerHTML = noteHtml(deps);
      // Wide screens keep the note beside the grid. Narrow ones scroll down to it.
      if (getComputedStyle(note).position !== 'sticky') note.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      return;
    }
    const open = t.closest<HTMLElement>('[data-open]');
    if (open) deps.open(open.dataset.open!);
  });
}
