// The two flat views: "My church" traces one line back to Jesus and compares it with
// another, and "Sacraments" lays the rites of every tradition side by side.

import type { HistoryNode } from './types';
import { EMBLEMS } from './emblems';
import { EUCHARIST, SIMPLE_MARKERS } from './layout';
import { byId, CHOICES, esc, eucharistKey, hueOf, lineageIn, momentsOn, myChurch, nameOf, rememberChurch, visibleSet } from './model';
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
const SIMPLE = visibleSet(true);

export const STATUS_TEXT: Record<Status, string> = {
  sacrament: 'Sacrament',
  ordinance: 'Ordinance',
  rite: 'A rite, not counted as a sacrament',
  none: 'Not a formal rite',
  varies: 'Varies by church',
};

export interface ScreenDeps {
  open: (id: string) => void;
  showOnMap: (id: string) => void;
  showSacraments: (id: string) => void;
  /** Called when the reader picks or clears their church. */
  onMine: (id: string | null) => void;
}

const color = (id: string) => hueOf(byId.get(id)!);

function emblem(id: string, cls = '') {
  const svg = EMBLEMS[id];
  return svg ? `<i class="emb ${cls}" style="--c:${color(id)}">${svg}</i>` : `<i class="dot ${cls}" style="--c:${color(id)}"></i>`;
}
const mark = (s: Status) => `<i class="mk ${s}" aria-hidden="true"></i>`;

// ---------------------------------------------------------------------------
// My church

let other: string | null = null;
/** A church from a shared compare link. It is shown, but not saved as the reader's own. */
let linked: string | null = null;
const current = () => linked ?? myChurch();

const lineage = (id: string) => lineageIn(id, SIMPLE);

function stepItem(id: string, mine: string | null) {
  const n = byId.get(id)!;
  const here = id === mine;
  const years = n.end == null ? `${n.start} to today` : `${n.start} to ${n.end}`;
  return `<li class="step${here ? ' here' : ''}">${emblem(id, 'mark')}<button type="button" data-open="${id}"><b>${esc(nameOf(n))}</b><em>${years}</em></button><p>${esc(STEPS[id] ?? n.why ?? n.summary)}</p></li>`;
}
function momentItem(m: HistoryNode) {
  const kind = m.type === 'council' ? 'council' : 'split';
  return `<li class="moment ${kind}"><i class="mark"></i><button type="button" data-open="${m.id}">${esc(nameOf(m))}<em>${m.start}</em></button></li>`;
}

/** Steps and the councils and splits between them, in order. */
function pathItems(ids: string[], line: string[], mine: string | null, skip?: string) {
  const items: { year: number; html: string }[] = ids.map((id) => ({ year: byId.get(id)!.start, html: stepItem(id, mine) }));
  const last = ids[ids.length - 1];
  for (const m of momentsOn(line)) {
    if (!ids.includes(m.on ?? '') || m.id === skip) continue;
    // A council or split comes just before the branch it starts, and inside the shared part only up to the fork.
    if (m.on === last && ids.length < line.length && m.start > byId.get(line[ids.length])!.start) continue;
    items.push({ year: m.start - 0.5, html: momentItem(m) });
  }
  return items.sort((a, b) => a.year - b.year).map((i) => i.html).join('');
}

function sacramentCard(id: string) {
  const row = ROWS.find((r) => r.id === id);
  const e = EUCHARIST[eucharistKey(byId.get(id)!)];
  if (!row) return '';
  return `<section class="card sac-card"><h3>Sacraments in brief</h3><p>${esc(row.summary)}</p><p class="cat" style="--c:${e.color}"><i></i><span><b>Communion:</b> ${esc(e.name)}.</span></p><button type="button" class="link" data-sac="${id}">See every rite side by side</button></section>`;
}

/** Where two lines part, and the moment that parted them. */
function fork(a: string[], b: string[]) {
  let k = 0;
  while (k < a.length && k < b.length && a[k] === b[k]) k++;
  const shared = a.slice(0, k);
  const restA = a.slice(k);
  const restB = b.slice(k);
  const firstA = restA[0] ? byId.get(restA[0])! : undefined;
  const firstB = restB[0] ? byId.get(restB[0])! : undefined;
  const year = Math.min(firstA?.start ?? Infinity, firstB?.start ?? Infinity);
  const moment = SIMPLE_MARKERS.map((id) => byId.get(id)!).find((m) => (m.splits ?? []).some((s) => s === restA[0] || s === restB[0]));
  return { shared, restA, restB, year, moment };
}

function compareTable(a: string, b: string) {
  const ra = ROWS.find((r) => r.id === a);
  const rb = ROWS.find((r) => r.id === b);
  if (!ra || !rb) return '';
  const ea = EUCHARIST[eucharistKey(byId.get(a)!)];
  const eb = EUCHARIST[eucharistKey(byId.get(b)!)];
  const cell = (r: Row, rite: string) => {
    const c = r.cells[rite];
    return `<td><span class="status ${c.status}">${mark(c.status)}${STATUS_TEXT[c.status]}</span><p>${esc(c.note)}</p></td>`;
  };
  const rows = RITES.map((r) => {
    const same = ra.cells[r.id].status === rb.cells[r.id].status;
    return `<tr class="${same ? '' : 'differs'}"><th scope="row">${esc(r.name)}${same ? '' : '<small>Differs</small>'}</th>${cell(ra, r.id)}${cell(rb, r.id)}</tr>`;
  }).join('');
  return `<section class="compare-table"><h3>Side by side</h3>
    <div class="table-wrap"><table>
      <thead><tr><th></th><th scope="col">${emblem(a)}${esc(nameOf(byId.get(a)!))}</th><th scope="col">${emblem(b)}${esc(nameOf(byId.get(b)!))}</th></tr></thead>
      <tbody>
        <tr><th scope="row">In brief</th><td><p>${esc(ra.summary)}</p></td><td><p>${esc(rb.summary)}</p></td></tr>
        <tr class="${ea === eb ? '' : 'differs'}"><th scope="row">View of communion${ea === eb ? '' : '<small>Differs</small>'}</th><td><span class="cat" style="--c:${ea.color}"><i></i>${esc(ea.name)}</span></td><td><span class="cat" style="--c:${eb.color}"><i></i>${esc(eb.name)}</span></td></tr>
        ${rows}
      </tbody>
    </table></div></section>`;
}

export function renderChurch(root: HTMLElement) {
  const mine = current();
  const chips = CHOICES.map(
    (id) =>
      `<button type="button" class="pick" data-pick="${id}" aria-pressed="${id === mine}">${emblem(id)}${esc(nameOf(byId.get(id)!))}</button>`,
  ).join('');
  if (other === mine) other = null;
  const options = CHOICES.filter((id) => id !== mine)
    .map((id) => `<option value="${id}"${id === other ? ' selected' : ''}>${esc(nameOf(byId.get(id)!))}</option>`)
    .join('');

  let body = `<p class="empty">Pick a church above to see the path from Jesus to it.</p>`;
  if (mine) {
    const a = lineage(mine);
    const compare = `<label class="compare-pick">Compare with <select id="other"><option value="">No other church</option>${options}</select></label>`;
    if (!other) {
      body = `${compare}
        <ol class="path solo">${pathItems(a, a, mine)}</ol>
        ${sacramentCard(mine)}
        <div class="actions"><button type="button" data-map="${mine}">See it on the map</button></div>`;
    } else {
      const b = lineage(other);
      const f = fork(a, b);
      const nA = nameOf(byId.get(mine)!);
      const nB = nameOf(byId.get(other)!);
      let lede: string;
      if (!f.restA.length || !f.restB.length) {
        const [child, parent, rest] = f.restA.length ? [mine, other, f.restA] : [other, mine, f.restB];
        const via = rest.slice(0, -1).map((id) => esc(nameOf(byId.get(id)!)));
        lede = via.length
          ? `${esc(nameOf(byId.get(child)!))} comes from ${esc(nameOf(byId.get(parent)!))} by way of ${via.join(' and ')}. Their paths part in ${f.year}.`
          : `${esc(nameOf(byId.get(child)!))} grew out of ${esc(nameOf(byId.get(parent)!))} in ${f.year}. Everything before that is shared.`;
      } else {
        lede = `${esc(nA)} and ${esc(nB)} share their history from Jesus until ${f.year}.`;
      }
      const part = f.moment
        ? `<div class="fork-moment"><span>Where they part</span><button type="button" data-open="${f.moment.id}">${esc(nameOf(f.moment))}<em>${f.moment.start}</em></button><p>${esc(f.moment.summary)}</p></div>`
        : '';
      const col = (rest: string[], id: string, cls: string) =>
        rest.length
          ? `<div class="branch ${cls}"><h4>${emblem(id)}${esc(nameOf(byId.get(id)!))}</h4><ol class="path">${rest.map((s) => stepItem(s, mine)).join('')}</ol></div>`
          : `<div class="branch ${cls} none"><h4>${emblem(id)}${esc(nameOf(byId.get(id)!))}</h4><p>Continues the shared line.</p></div>`;
      body = `${compare}
        <p class="compare-lede">${lede}</p>
        <section class="shared"><h3>Shared history</h3><ol class="path">${pathItems(f.shared, a, null, f.moment?.id)}</ol></section>
        ${part}
        <section class="fork">${col(f.restA, mine, 'mine')}${col(f.restB, other, 'theirs')}</section>
        ${compareTable(mine, other)}
        <div class="actions"><button type="button" data-map="${mine}">See ${esc(nA)} on the map</button><button type="button" data-map="${other}">See ${esc(nB)} on the map</button></div>`;
    }
  }

  root.innerHTML = `<div class="screen-inner">
    <h2>Where did my church come from?</h2>
    <p class="lede">Pick your church to trace its line back to Jesus. Add a second church to see where the two part ways and how their sacraments differ.</p>
    <div class="picks">${chips}</div>
    ${body}
  </div>`;
}

export function bindChurch(root: HTMLElement, deps: ScreenDeps) {
  root.addEventListener('click', (e) => {
    const t = e.target as HTMLElement;
    const pick = t.closest<HTMLElement>('[data-pick]');
    if (pick) {
      const id = pick.dataset.pick!;
      const next = current() === id ? null : id;
      linked = null;
      rememberChurch(next);
      deps.onMine(next);
      renderChurch(root);
      root.querySelector('.compare-pick')?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      return;
    }
    const open = t.closest<HTMLElement>('[data-open]');
    if (open) return deps.open(open.dataset.open!);
    const map = t.closest<HTMLElement>('[data-map]');
    if (map) return deps.showOnMap(map.dataset.map!);
    const sac = t.closest<HTMLElement>('[data-sac]');
    if (sac) deps.showSacraments(sac.dataset.sac!);
  });
  root.addEventListener('change', (e) => {
    const s = e.target as HTMLSelectElement;
    if (s.id !== 'other') return;
    other = s.value || null;
    renderChurch(root);
    root.querySelector('.compare-lede')?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  });
}

/** Set the comparison from outside, for links like #compare=baptist,catholic. */
export function setCompare(a: string, b: string | null) {
  linked = a;
  other = b && b !== a ? b : null;
}

// ---------------------------------------------------------------------------
// Sacraments

let picked: { row: string; rite: string } | null = null;

function noteHtml() {
  if (!picked) {
    return `<p class="hint-note">Tap any mark to see what that church does. Tap a church's name for its full story.</p>`;
  }
  const rite = RITES.find((r) => r.id === picked!.rite);
  const row = ROWS.find((r) => r.id === picked!.row);
  if (!rite) return '';
  if (!row) return `<h4>${esc(rite.name)}</h4><p>${esc(rite.what)}</p>`;
  const n = byId.get(row.id)!;
  const cell = row.cells[rite.id];
  return `<div class="note-head">${emblem(row.id)}<div><small>${esc(nameOf(n))}</small><h4>${esc(rite.name)}</h4></div></div><span class="status ${cell.status}">${mark(cell.status)}${STATUS_TEXT[cell.status]}</span><p>${esc(cell.note)}</p><p class="what">${esc(rite.name)}: ${esc(rite.what)}</p>`;
}

export function renderSacraments(root: HTMLElement, focus?: string) {
  const mine = focus ?? myChurch();
  const head = RITES.map((r) => `<th scope="col"><button type="button" data-rite="${r.id}">${esc(r.short)}</button></th>`).join('');
  const body = ROWS.map((row) => {
    const n = byId.get(row.id);
    if (!n) return '';
    const cells = RITES.map((r) => {
      const c = row.cells[r.id];
      const on = picked?.row === row.id && picked.rite === r.id;
      return `<td><button type="button" data-cell="${row.id}|${r.id}" aria-pressed="${on}" aria-label="${esc(nameOf(n))}, ${esc(r.name)}: ${STATUS_TEXT[c.status]}">${mark(c.status)}</button></td>`;
    }).join('');
    return `<tr class="${row.id === mine ? 'mine' : ''}"><th scope="row"><button type="button" data-open="${row.id}">${emblem(row.id)}<span>${esc(nameOf(n))}</span></button></th>${cells}</tr>`;
  }).join('');
  const key = (Object.keys(STATUS_TEXT) as Status[]).map((s) => `<span>${mark(s)}${STATUS_TEXT[s]}</span>`).join('');

  root.innerHTML = `<div class="screen-inner wide">
    <h2>The sacraments, side by side</h2>
    <p class="lede">Which churches treat each rite as a sacrament. An ordinance is a practice kept in obedience to Christ. Churches differ over how it relates to grace.</p>
    <div class="key">${key}</div>
    <div class="sac-layout">
      <div class="grid-wrap"><table class="sac-grid"><thead><tr><th></th>${head}</tr></thead><tbody>${body}</tbody></table></div>
      <aside class="cell-note" aria-live="polite">${noteHtml()}</aside>
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
      note.innerHTML = noteHtml();
      // Wide screens keep the note beside the grid. Narrow ones scroll down to it.
      if (getComputedStyle(note).position !== 'sticky') note.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      return;
    }
    const open = t.closest<HTMLElement>('[data-open]');
    if (open) deps.open(open.dataset.open!);
  });
}
