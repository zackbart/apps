// The first-visit screen: pick your church to follow its line through the story, or skip.

import { EMBLEMS } from './emblems';
import { EXAMPLES } from './layout';
import { byId, CHOICES, esc, hueOf, markWelcomed, nameOf, rememberChurch } from './model';

/** Show the picker. Calls done with the chosen church, or null if the reader skipped. */
export function showWelcome(done: (id: string | null) => void) {
  const root = document.createElement('div');
  root.className = 'welcome';
  root.setAttribute('role', 'dialog');
  root.setAttribute('aria-modal', 'true');
  root.setAttribute('aria-labelledby', 'welcome-title');
  const cards = CHOICES.map((id) => {
    const n = byId.get(id)!;
    return `<button type="button" class="church-card" data-church="${id}" style="--c:${hueOf(n)}">
      <i class="emb">${EMBLEMS[id] ?? ''}</i>
      <span><b>${esc(nameOf(n))}</b><small>${esc(EXAMPLES[id] ?? '')}</small></span>
    </button>`;
  }).join('');
  root.innerHTML = `<div class="welcome-inner">
    <p class="welcome-kicker">Two thousand years of Christian history</p>
    <h2 id="welcome-title">Where do you go to church?</h2>
    <p class="welcome-lede">Pick your church and we will trace its line back to Jesus as you read. You can change it any time.</p>
    <div class="church-cards">${cards}</div>
    <div class="welcome-skip">
      <button type="button" class="skip" data-church="">Skip, just show me the history</button>
      <span>Not sure, or not listed? Skip for now, or pick the closest family.</span>
    </div>
  </div>`;
  document.body.appendChild(root);
  // Focus the dialog itself, so no card looks chosen before the reader picks one.
  root.tabIndex = -1;
  root.focus({ preventScroll: true });

  const finish = (id: string | null) => {
    markWelcomed();
    if (id) rememberChurch(id);
    removeEventListener('keydown', onKey, true);
    root.classList.add('leaving');
    setTimeout(() => root.remove(), matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 260);
    done(id);
  };
  const onKey = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      finish(null);
    } else if (e.key === 'Tab') {
      // Keep focus inside the picker while it is open.
      const items = [...root.querySelectorAll<HTMLElement>('button')];
      const i = items.indexOf(document.activeElement as HTMLElement);
      if (i < 0) {
        e.preventDefault();
        items[e.shiftKey ? items.length - 1 : 0].focus();
      } else if (e.shiftKey && i === 0) {
        e.preventDefault();
        items[items.length - 1].focus();
      } else if (!e.shiftKey && i === items.length - 1) {
        e.preventDefault();
        items[0].focus();
      }
    } else {
      // The app's own shortcuts wait until the picker closes.
      e.stopPropagation();
    }
  };
  addEventListener('keydown', onKey, true);
  root.addEventListener('click', (e) => {
    const b = (e.target as HTMLElement).closest<HTMLElement>('[data-church]');
    if (b) finish(b.dataset.church || null);
  });
}
