// The Story view: the chapters scroll past while a pinned map fills in beside them.
// Scrolling is the timeline. Each chapter zooms the map to its years and draws the
// lines up to the point the reader has reached.

import { CHAPTERS, NOW } from './layout';
import { FlatMap } from './map';
import { esc, KIND_TEXT, nameOf, nodes } from './model';

export interface StoryDeps {
  onSelect: (id: string | null) => void;
  open: (id: string) => void;
  goView: (view: 'map' | 'church' | 'sacraments') => void;
}

/** The big moments of a chapter, for the chips under its text. */
function momentsIn(from: number, to: number) {
  return nodes
    .filter((n) => n.importance === 1 && n.start >= from && n.start <= to && n.id !== 'early-church' && n.id !== 'chalcedonian')
    .sort((a, b) => a.start - b.start)
    .slice(0, 7);
}

export function createStory(root: HTMLElement, deps: StoryDeps) {
  const last = CHAPTERS.length - 1;
  const chapters = CHAPTERS.map((c, i) => {
    const label = i === 0 ? 'The whole story' : `Chapter ${i} of ${last}`;
    const years = i === 0 ? '' : `<span class="ch-years">${c.from} to ${c.to >= NOW ? 'today' : c.to}</span>`;
    const chips =
      i === 0
        ? `<p class="scroll-cue">Scroll to begin with Jesus and the apostles.</p>`
        : `<ul class="moments">${momentsIn(c.from, c.to)
            .map((n) => `<li><button type="button" data-open="${n.id}"><span class="yr">${n.start}</span>${esc(nameOf(n))}<small>${KIND_TEXT[n.type]}</small></button></li>`)
            .join('')}</ul>`;
    return `<article class="chapter" data-ch="${i}"><div class="ch-label"><span>${label}</span>${years}</div><h2>${esc(c.title)}</h2><p>${esc(c.text)}</p>${chips}</article>`;
  }).join('');

  root.innerHTML = `<div class="story-map"><div class="map-host" id="story-map-host"></div><p class="map-note" hidden></p></div>
    <div class="story-text">${chapters}
      <article class="chapter outro" data-ch="end">
        <div class="ch-label"><span>Where do you fit?</span></div>
        <h2>Find your place on the map</h2>
        <p>Trace your own church back to Jesus, see how it compares with another, or open the full map with every branch.</p>
        <div class="outro-actions">
          <button type="button" class="primary" data-go-view="church">Trace my church</button>
          <button type="button" data-go-view="map">Open the full map</button>
          <button type="button" data-go-view="sacraments">Compare the sacraments</button>
        </div>
      </article>
    </div>`;

  const host = root.querySelector<HTMLElement>('#story-map-host')!;
  const map = new FlatMap(host, { interactive: false, onSelect: deps.onSelect });
  const articles = [...root.querySelectorAll<HTMLElement>('.chapter')];
  let active = -2;

  function update() {
    const view = root.getBoundingClientRect();
    const mapBox = host.getBoundingClientRect();
    // On phones the map sits on top, so the reading line is lower down the screen.
    const stacked = mapBox.bottom < view.top + view.height * 0.6 && mapBox.width > view.width * 0.8;
    const line = stacked ? mapBox.bottom + (view.bottom - mapBox.bottom) * 0.3 : view.top + view.height * 0.45;
    let idx = 0;
    articles.forEach((a, i) => {
      if (a.getBoundingClientRect().top <= line) idx = i;
    });
    const a = articles[idx];
    const r = a.getBoundingClientRect();
    const p = Math.min(1, Math.max(0, (line - r.top) / Math.max(1, r.height * 0.8)));
    const chIndex = a.dataset.ch === 'end' ? -1 : Number(a.dataset.ch);
    if (idx !== active) {
      active = idx;
      articles.forEach((x, i) => x.classList.toggle('active', i === idx));
      if (chIndex <= 0) {
        map.setDomain(CHAPTERS[0].from, CHAPTERS[0].to);
        map.setFocus(null);
      } else {
        const c = CHAPTERS[chIndex];
        map.setDomain(c.from, c.to, true, c.to);
        map.setFocus([c.from, c.to]);
      }
    }
    if (chIndex <= 0) map.setReveal(NOW);
    else {
      const c = CHAPTERS[chIndex];
      const floor = chIndex > 1 ? Math.min(c.to, CHAPTERS[chIndex - 1].to) : c.from;
      map.setReveal(Math.max(floor, c.from + (c.to - c.from) * p));
    }
  }

  let queued = false;
  root.addEventListener(
    'scroll',
    () => {
      if (queued) return;
      queued = true;
      requestAnimationFrame(() => {
        queued = false;
        update();
      });
    },
    { passive: true },
  );
  addEventListener('resize', () => requestAnimationFrame(update));

  root.addEventListener('click', (e) => {
    const t = e.target as HTMLElement;
    const open = t.closest<HTMLElement>('[data-open]');
    if (open) return deps.open(open.dataset.open!);
    const go = t.closest<HTMLElement>('[data-go-view]');
    if (go) deps.goView(go.dataset.goView as 'map' | 'church' | 'sacraments');
  });

  function goChapter(step: 1 | -1) {
    const target = articles[Math.min(articles.length - 1, Math.max(0, active + step))];
    target.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' });
  }

  return {
    map,
    update,
    goChapter,
    /** The chapter that tells the story of this year, for search results. */
    showYear(year: number) {
      const i = CHAPTERS.findIndex((c, k) => k > 0 && year >= c.from && year <= c.to);
      articles[Math.max(0, i)].scrollIntoView({ block: 'start' });
    },
  };
}
