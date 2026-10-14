// The detail panel for one tradition, council, split, event, or person.

import type { HistoryNode } from './types';
import { EMBLEMS } from './emblems';
import { EUCHARIST } from './layout';
import {
  byId,
  damickCite,
  esc,
  eucharistKey,
  isTradId,
  KIND_TEXT,
  lineageIn,
  nameOf,
  nodeColor,
  nodes,
  parentIn,
  pelikanCite,
  yearText,
  type Mode,
} from './model';

export interface PanelContext {
  visible: Set<string>;
  children: Map<string, string[]>;
  mode: Mode;
}

function chip(id: string, ctx: PanelContext) {
  const n = byId.get(id);
  if (!n) return '';
  return `<button type="button" data-go="${n.id}" style="--c:${nodeColor(n, ctx.mode)}"><span class="yr">${n.start}</span><i></i>${esc(nameOf(n))}</button>`;
}

function sourceLinks(sources: string[]) {
  return sources
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
}

export function panelHtml(n: HistoryNode, ctx: PanelContext) {
  const parts: string[] = [];
  const emblem = EMBLEMS[n.id];
  const color = nodeColor(n, ctx.mode);
  parts.push(
    `<div class="head" style="--c:${color}">${emblem ? `<i class="emb big">${emblem}</i>` : ''}<div><div class="kind">${KIND_TEXT[n.type]}, ${yearText(n)}</div><h2>${esc(nameOf(n))}</h2></div></div>`,
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
    const line = lineageIn(n.id, ctx.visible);
    if (line.length > 1) {
      parts.push(
        `<h3>Family line</h3><ol class="lineage">${line
          .map((id) => {
            const a = byId.get(id)!;
            const here = id === n.id ? ' class="here"' : '';
            return `<li${here}><button type="button" data-go="${id}">${esc(nameOf(a))}<small>${a.start}</small></button></li>`;
          })
          .join('')}</ol>`,
      );
    }
    const kids = (ctx.children.get(n.id) ?? []).slice().sort((a, b) => byId.get(a)!.start - byId.get(b)!.start);
    if (kids.length) parts.push(`<h3>Branches that grew from it</h3><div class="chips">${kids.map((k) => chip(k, ctx)).join('')}</div>`);
  } else {
    const splits = (n.splits ?? []).filter((s) => ctx.visible.has(s));
    if (splits.length) parts.push(`<h3>What came out of it</h3><div class="chips">${splits.map((k) => chip(k, ctx)).join('')}</div>`);
  }

  // Everything below is for digging deeper, folded away by default.
  const more: string[] = [];
  if (n.facts?.length) more.push(`<h3>Key facts</h3><ul class="facts">${n.facts.map((f) => `<li>${esc(f)}</li>`).join('')}</ul>`);
  if (n.type === 'tradition') {
    const also = (n.parents ?? []).filter(isTradId).filter((p) => p !== parentIn(n, ctx.visible));
    if (also.length) more.push(`<h3>Also shaped by</h3><div class="chips">${also.map((k) => chip(k, ctx)).join('')}</div>`);
    const onLine = nodes.filter((m) => m.type !== 'tradition' && m.on === n.id).sort((a, b) => a.start - b.start);
    if (onLine.length) more.push(`<h3>On this line</h3><div class="chips">${onLine.map((m) => chip(m.id, ctx)).join('')}</div>`);
  } else if (n.on && byId.has(n.on)) {
    more.push(`<h3>Happened within</h3><div class="chips">${chip(n.on, ctx)}</div>`);
  }
  if (n.disputed) more.push(`<h3>Seen differently</h3><p class="disputed">${esc(n.disputed)}</p>`);
  if (n.sources?.length) more.push(`<div class="sources">Sources: ${sourceLinks(n.sources)}</div>`);
  if (more.length) parts.push(`<details class="more"><summary>More about ${esc(nameOf(n))}</summary>${more.join('')}</details>`);
  return parts.join('');
}
