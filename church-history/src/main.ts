import '@fontsource/newsreader/latin-400.css';
import '@fontsource/newsreader/latin-500.css';
import '@fontsource/newsreader/latin-400-italic.css';
import '@fontsource/inter/latin-400.css';
import '@fontsource/inter/latin-500.css';
import '@fontsource/inter/latin-600.css';
import './style.css';
import { CHAPTERS, EUCHARIST, FAMILIES, FIRST_YEAR, NOW } from './layout';
import { FlatMap, type Highlight } from './map';
import { createStory } from './story';
import { bindChurch, bindSacraments, renderChurch, renderSacraments, setCompare } from './screens';
import { panelHtml } from './panel';
import {
  byId,
  childrenIn,
  CHOICES,
  clampYear,
  descendantsIn,
  esc,
  eucharistKey,
  familyKey,
  KIND_TEXT,
  lineageIn,
  myChurch,
  nameOf,
  nodes,
  visibleSet,
  type Mode,
} from './model';

type View = 'story' | 'map' | 'church' | 'sacraments';
const VIEWS: View[] = ['story', 'map', 'church', 'sacraments'];

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const app = $<HTMLDivElement>('app');
const panel = $<HTMLElement>('panel');
const panelBody = $<HTMLDivElement>('panel-body');
const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
const phoneQuery = matchMedia('(max-width: 820px)');

// The pinned story map and the side panel sit just under the header.
const header = document.querySelector<HTMLElement>('.top')!;
new ResizeObserver(() => app.style.setProperty('--top-h', `${header.offsetHeight}px`)).observe(header);

let view: View = 'story';
let selected: string | null = null;
let mode: Mode = 'plain';

// ---------------------------------------------------------------------------
// Views

const viewEl: Record<View, HTMLElement> = {
  story: $('view-story'),
  map: $('view-map'),
  church: $('view-church'),
  sacraments: $('view-sacraments'),
};

const story = createStory(viewEl.story, {
  onSelect: (id) => select(id),
  open: (id) => select(id),
  goView: (v) => setView(v),
});
const mapView = new FlatMap($('map-host'), {
  interactive: true,
  onSelect: (id) => select(id),
  onMove: () => document.querySelectorAll('#eras button').forEach((b) => b.setAttribute('aria-pressed', 'false')),
});

const screenDeps = {
  open: (id: string) => select(id),
  showOnMap: (id: string) => {
    setView('map');
    select(id);
  },
  showSacraments: (id: string) => setView('sacraments', id),
  onMine: () => applyHighlight(),
};
bindChurch(viewEl.church, screenDeps);
bindSacraments(viewEl.sacraments, screenDeps);

function setView(v: View, focus?: string) {
  const from = view;
  view = v;
  app.dataset.view = v;
  document.querySelectorAll<HTMLButtonElement>('#views [data-view]').forEach((b) => b.setAttribute('aria-current', String(b.dataset.view === v)));
  for (const k of VIEWS) viewEl[k].hidden = k !== v;
  if (v === 'church') renderChurch(viewEl.church);
  if (v === 'sacraments') renderSacraments(viewEl.sacraments, focus);
  if (v === 'story') requestAnimationFrame(story.update);
  if (from !== v) viewEl[v].scrollTop = 0;
  if (!selected) history.replaceState(null, '', v === 'story' ? location.pathname : `#${v}`);
  applyHighlight();
}
$('views').addEventListener('click', (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-view]');
  if (b && b.dataset.view !== view) setView(b.dataset.view as View);
});

// ---------------------------------------------------------------------------
// Selection and highlight

/** What to light up on a map that shows these nodes. */
function highlightFor(visible: Set<string>, simple: boolean): Highlight {
  const mine = myChurch();
  const personal = mine && visible.has(mine) ? new Set(lineageIn(mine, visible)) : null;
  if (!selected) return { personal };
  const n = byId.get(selected)!;
  const children = childrenIn(visible, simple);
  let lit: Set<string>;
  if (n.type === 'tradition') {
    lit = new Set([selected, ...lineageIn(selected, visible), ...descendantsIn(selected, children)]);
  } else {
    const host = n.on && visible.has(n.on) ? n.on : '';
    lit = new Set([...(host ? lineageIn(host, visible) : []), ...(n.splits ?? []).filter((s) => visible.has(s))]);
  }
  return { lit, selected, personal };
}

function applyHighlight() {
  story.map.setHighlight(highlightFor(visibleSet(true), true));
  mapView.setHighlight(highlightFor(visibleSet(mapView.simple), mapView.simple));
  // Say what the red line is, since nothing else on the map does.
  const mine = myChurch();
  const n = selected ? byId.get(selected)! : null;
  const text = n
    ? n.type === 'tradition'
      ? `<i></i>${esc(nameOf(n))}, with the line it came from and the branches that grew from it.`
      : `<i></i>The lines touched by ${esc(nameOf(n))}.`
    : mine
      ? `<i></i>Your church: ${esc(nameOf(byId.get(mine)!))}. <button type="button" data-goto="church">Change</button>`
      : '';
  document.querySelectorAll<HTMLElement>('.map-note').forEach((el) => {
    el.hidden = !text || (mode !== 'plain' && el.closest('.map-view') !== null);
    el.innerHTML = text;
  });
}
document.addEventListener('click', (e) => {
  const go = (e.target as HTMLElement).closest<HTMLElement>('[data-goto]');
  if (go) setView(go.dataset.goto as View);
});

function panelContext() {
  const simple = view === 'map' ? mapView.simple : true;
  const visible = visibleSet(simple);
  return { visible, children: childrenIn(visible, simple), mode };
}

function select(id: string | null) {
  selected = id && byId.has(id) ? id : null;
  if (!selected) {
    panel.hidden = true;
    app.classList.remove('panel-open');
    history.replaceState(null, '', view === 'story' ? location.pathname : `#${view}`);
    applyHighlight();
    return;
  }
  const n = byId.get(selected)!;
  // Something hidden in the simple map turns on the detail view.
  if (view === 'map' && !visibleSet(mapView.simple).has(selected)) setDetail(false);
  panelBody.innerHTML = panelHtml(n, panelContext());
  panel.hidden = false;
  app.classList.add('panel-open');
  panelBody.scrollTop = 0;
  history.replaceState(null, '', `#${selected}`);
  applyHighlight();
  if (view === 'map') mapView.showYear(n.start);
}

panelBody.addEventListener('click', (e) => {
  const go = (e.target as HTMLElement).closest<HTMLElement>('[data-go]');
  if (go && go.dataset.go !== selected) select(go.dataset.go!);
});
$('close').addEventListener('click', () => select(null));

// On phones the panel is a bottom sheet. Pull it down from the handle, or from the top of its text, to close it.
let pull: { y: number; t: number; dy: number; on: boolean } | null = null;
panel.addEventListener(
  'touchstart',
  (e) => {
    const fromTop = (e.target as HTMLElement).closest('.grab') || panelBody.scrollTop <= 0;
    pull = phoneQuery.matches && fromTop && e.touches.length === 1 ? { y: e.touches[0].clientY, t: performance.now(), dy: 0, on: false } : null;
  },
  { passive: true },
);
panel.addEventListener(
  'touchmove',
  (e) => {
    if (!pull) return;
    const dy = e.touches[0].clientY - pull.y;
    if (!pull.on && dy < 4) {
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
// Map view controls

const eras = $<HTMLDivElement>('eras');
eras.innerHTML = CHAPTERS.map(
  (c, i) => `<button type="button" data-era="${i}" aria-pressed="${i === 0}">${i === 0 ? 'Whole story' : esc(c.title)}</button>`,
).join('');
eras.addEventListener('click', (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-era]');
  if (!b) return;
  const c = CHAPTERS[Number(b.dataset.era)];
  eras.querySelectorAll('button').forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
  mapView.setDomain(c.from, c.to);
});

const legend = $<HTMLElement>('legend');
function renderLegend() {
  legend.hidden = mode === 'plain';
  if (legend.hidden) return;
  const traditions = nodes.filter((n) => n.type === 'tradition' && visibleSet(mapView.simple).has(n.id));
  const used = new Set(traditions.map((t) => (mode === 'eucharist' ? eucharistKey(t) : familyKey(t))));
  const swatches = Object.entries(mode === 'eucharist' ? EUCHARIST : FAMILIES).filter(([k]) => used.has(k) || (mode === 'family' && k === 'early'));
  const title = mode === 'eucharist' ? 'What happens at communion' : 'Church families';
  const note = mode === 'eucharist' ? `<p class="legend-note">Colors show each tradition's main emphasis. Many views overlap.</p>` : '';
  legend.innerHTML = `<h4>${title}</h4><ul>${swatches
    .map(([, s]) => `<li style="--c:${s.color}"><i></i><span>${esc(s.name)}${mode === 'eucharist' && s.note ? `<small>${esc(s.note)}</small>` : ''}</span></li>`)
    .join('')}</ul>${note}`;
}
document.querySelectorAll<HTMLButtonElement>('.seg button').forEach((btn) => {
  btn.addEventListener('click', () => {
    mode = btn.dataset.mode as Mode;
    document.querySelectorAll('.seg button').forEach((b) => b.setAttribute('aria-pressed', String(b === btn)));
    mapView.setMode(mode);
    renderLegend();
    applyHighlight();
    if (selected) panelBody.innerHTML = panelHtml(byId.get(selected)!, panelContext());
  });
});

const detail = $<HTMLInputElement>('detail');
function setDetail(isSimple: boolean) {
  detail.checked = !isSimple;
  mapView.setSimple(isSimple);
  renderLegend();
  applyHighlight();
}
detail.addEventListener('change', () => setDetail(!detail.checked));

// ---------------------------------------------------------------------------
// Search

const q = $<HTMLInputElement>('q');
const results = $<HTMLUListElement>('results');
const search = $<HTMLDivElement>('search');
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
      return { n, score };
    })
    .filter((h) => h.score < 9)
    .sort((a, b) => a.score - b.score || a.n.importance - b.n.importance || a.n.start - b.n.start)
    .slice(0, 8)
    .map((h) => h.n);
  hitIndex = 0;
  results.innerHTML = hits.length
    ? hits.map((n, i) => `<li role="option" data-go="${n.id}" aria-selected="${i === 0}">${esc(nameOf(n))}<span>${KIND_TEXT[n.type]}, ${n.start}</span></li>`).join('')
    : `<li aria-disabled="true">No match. Try a church name or a year like 1054.</li>`;
  if (/^\d{2,4}$/.test(s)) results.insertAdjacentHTML('afterbegin', `<li data-year="${Number(s)}">Go to the year ${Number(s)}<span>Map</span></li>`);
  results.hidden = false;
}
function pickHit(el: HTMLElement | null) {
  if (!el) return;
  if (el.dataset.go) select(el.dataset.go);
  if (el.dataset.year) {
    const y = clampYear(Number(el.dataset.year));
    if (view !== 'map') setView('map');
    mapView.setDomain(clampYear(y - 80), clampYear(y + 80));
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
// Phones show a search button that opens the field over the title.
$('search-btn').addEventListener('click', () => {
  search.classList.add('open');
  q.focus();
});

// ---------------------------------------------------------------------------
// Keyboard

addEventListener('keydown', (e) => {
  const typing = (e.target as HTMLElement).closest('input, select, textarea');
  if (typing) return;
  if (e.key === '/') {
    e.preventDefault();
    search.classList.add('open');
    q.focus();
  } else if (e.key === 'Escape') {
    select(null);
  } else if (view === 'map' && !e.metaKey && !e.ctrlKey && mapView.key(e)) {
    e.preventDefault();
  } else if (view === 'story' && (e.key === 'ArrowRight' || e.key === 'ArrowLeft')) {
    e.preventDefault();
    story.goChapter(e.key === 'ArrowRight' ? 1 : -1);
  }
});

// ---------------------------------------------------------------------------
// Start

function route() {
  const hash = decodeURIComponent(location.hash.slice(1));
  const compare = /^compare=([\w-]+)(?:,([\w-]+))?$/.exec(hash);
  if (compare && CHOICES.includes(compare[1])) {
    setCompare(compare[1], compare[2] && CHOICES.includes(compare[2]) ? compare[2] : null);
    setView('church');
  } else if (VIEWS.includes(hash as View)) {
    setView(hash as View);
  } else if (byId.has(hash)) {
    setView('map');
    select(hash);
  } else {
    setView('story');
  }
}

mapView.setDomain(FIRST_YEAR, NOW, false);
route();
renderLegend();
addEventListener('hashchange', route);
