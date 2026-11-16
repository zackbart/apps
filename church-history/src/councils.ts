import councilData from './data/councils.json';
import { esc } from './model';

export const councils = councilData;
const groups = { all: 'All councils', early: 'First seven', catholic: 'Later Catholic councils', other: 'Regional & disputed' };
type Group = keyof typeof groups;
const years = (c: (typeof councils)[number]) => `${c.start === 49 ? 'c. ' : ''}${c.start}${c.end !== c.start ? `–${c.end}` : ''}`;
const standing = (c: (typeof councils)[number]) => c.number ? `${c.number <= 7 ? 'Early ecumenical council' : 'Catholic ecumenical council'} · ${c.number}` : 'Apostolic, regional, confessional or disputed assembly';

export function createCouncils(el: HTMLElement) {
  let active = 'nicaea-i';
  let group: Group = 'all';
  let query = '';
  el.innerHTML = `<div class="screen-inner wide councils-inner">
    <h2>Councils</h2>
    <p class="lede">What the church debated, what it decided, and why Christians still disagree about the answers.</p>
    <details class="council-scope"><summary>Which councils are included?</summary>
      <p>All 21 councils recognized as ecumenical by the Catholic Church, plus seven apostolic, regional, confessional or disputed assemblies. Every council already on this map is included. This is not an inventory of every local synod in Christian history.</p>
      <p>Eastern Orthodox churches receive the first seven; Oriental Orthodox churches receive the first three; the Church of the East receives the first two. Protestant reception varies by tradition and by teaching. Recognizing a council’s doctrine does not necessarily mean accepting every disciplinary canon.</p>
      <p>The two Constantinople assemblies of 869–870 and 879–880 have separate entries. Neither signatures nor imperial support alone tells us how a decision was received.</p>
      <p>Read the <a href="https://www.oca.org/orthodoxy/the-orthodox-faith/doctrine-scripture/sources-of-christian-doctrine/the-councils" target="_blank" rel="noopener noreferrer">Orthodox account</a> and the <a href="https://www.papalencyclicals.net/councils" target="_blank" rel="noopener noreferrer">Catholic enumeration</a>. Council texts express their authors’ positions; the reception notes distinguish those claims from agreement across traditions.</p>
    </details>
    <div class="councils-layout">
      <aside class="council-index" aria-label="Find a council">
        <label for="council-search">Search councils</label>
        <input id="council-search" type="search" placeholder="Name, year, teaching or person" autocomplete="off">
        <label for="council-group">Browse</label>
        <select id="council-group">${Object.entries(groups).map(([value,label]) => `<option value="${value}">${label}</option>`).join('')}</select>
        <p class="council-count" role="status"></p>
        <a class="council-skip" href="#council-title">Skip to the selected council</a>
        <nav class="council-list" aria-label="Councils in chronological order"></nav>
      </aside>
      <article class="council-reading" aria-labelledby="council-title"></article>
    </div>
  </div>`;
  const list = el.querySelector<HTMLElement>('.council-list')!;
  const article = el.querySelector<HTMLElement>('.council-reading')!;
  const count = el.querySelector<HTMLElement>('.council-count')!;
  const input = el.querySelector<HTMLInputElement>('#council-search')!;
  const filter = el.querySelector<HTMLSelectElement>('#council-group')!;
  function matches() {
    const terms = query.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
    return councils.filter(c => (group === 'all' || c.group === group) && terms.every(t => [c.name, c.start, c.end, c.question, c.context, ...c.decisions, c.aftermath, c.reception, c.background, ...c.facts, c.caution].join(' ').toLocaleLowerCase().includes(t)));
  }
  function fitList() {
    if (el.hidden) return;
    list.style.maxHeight = matchMedia('(max-width: 820px)').matches ? '230px' : `${Math.max(120, el.getBoundingClientRect().bottom - list.getBoundingClientRect().top - 24)}px`;
    revealActive();
  }
  function revealActive() {
    const row = list.querySelector<HTMLElement>('[aria-current="true"]');
    if (!row) return;
    const rowBox = row.getBoundingClientRect();
    const listBox = list.getBoundingClientRect();
    if (rowBox.top < listBox.top) list.scrollTop += rowBox.top - listBox.top;
    else if (rowBox.bottom > listBox.bottom) list.scrollTop += rowBox.bottom - listBox.bottom;
  }
  el.addEventListener('scroll', fitList, { passive: true });
  new ResizeObserver(() => { fitList(); revealActive(); }).observe(el);
  function renderList() {
    const found = matches();
    count.textContent = `${found.length} of ${councils.length} councils`;
    list.innerHTML = found.length ? found.map(c => `<button type="button" data-council="${c.id}" aria-current="${c.id === active}"><span>${esc(c.name)}</span><small>${years(c)}</small></button>`).join('') : '<p>No councils match. Try another term or choose “All councils”.</p>';
    fitList();
    revealActive();
  }
  function renderArticle() {
    const c = councils.find(c => c.id === active)!;
    const index = councils.indexOf(c);
    article.innerHTML = `<p class="council-meta">${years(c)} · ${standing(c)}</p>
      <h3 id="council-title" tabindex="-1">${esc(c.name)}</h3>
      <p class="council-question">${esc(c.question)}</p>
      <section><h4>Why it met</h4><p>${esc(c.context)}</p></section>
      <section><h4>What it decided</h4><ul>${c.decisions.map(d => `<li>${esc(d)}</li>`).join('')}</ul></section>
      <section><h4>What followed</h4><p>${esc(c.aftermath)}</p></section>
      <section class="council-reception"><h4>Who receives it?</h4><p>${esc(c.reception)}</p></section>
      ${c.background ? `<section><h4>Why it still matters</h4><p>${esc(c.background)}</p></section>` : ''}
      ${c.facts.length ? `<details><summary>More from the map’s research</summary><ul>${c.facts.map(f => `<li>${esc(f)}</li>`).join('')}</ul>${c.caution ? `<p>${esc(c.caution)}</p>` : ''}</details>` : ''}
      <section class="council-sources"><h4>Read the sources</h4><p>Start with ${esc(c.reading)}.</p><ol>${c.sources.map((s) => `<li><a href="${esc(s.url)}" target="_blank" rel="noopener noreferrer">${esc(s.label)}</a></li>`).join('')}</ol></section>
      <div class="council-actions"><a href="#councils=${c.id}">Link to this council</a>${c.nodeId ? `<a href="#${c.nodeId}">See on the map</a>` : ''}</div>
      <nav class="council-pagination" aria-label="Read councils chronologically">${index > 0 ? `<button type="button" data-council="${councils[index-1].id}">Previous: ${esc(councils[index-1].name)}</button>` : '<span></span>'}${index < councils.length-1 ? `<button type="button" data-council="${councils[index+1].id}">Next: ${esc(councils[index+1].name)}</button>` : ''}</nav>`;
  }
  function show(id?: string, focus = false) {
    if (id && councils.some(c => c.id === id)) {
      active = id;
      if (!matches().some(c => c.id === active)) {
        group = 'all'; query = ''; filter.value = group; input.value = query;
      }
    }
    renderList(); renderArticle();
    if (focus) {
      article.querySelector<HTMLElement>('h3')!.focus({ preventScroll: true });
      article.scrollIntoView({ block: 'start' });
    }
  }
  input.addEventListener('input', () => { query = input.value; renderList(); });
  filter.addEventListener('change', () => { group = filter.value as Group; renderList(); });
  el.addEventListener('click', e => {
    if ((e.target as HTMLElement).closest('.council-skip')) {
      e.preventDefault();
      show(undefined, true);
      return;
    }
    const button = (e.target as HTMLElement).closest<HTMLButtonElement>('[data-council]');
    if (!button) return;
    show(button.dataset.council, true);
    history.replaceState(null, '', `#councils=${active}`);
  });
  show();
  return { show };
}
