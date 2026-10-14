// Merge the per-era research files into src/data/nodes.json and report
// broken references. Usage: node scripts/merge-data.mjs
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';

const dir = new URL('../research/', import.meta.url);
const files = readdirSync(dir).filter((f) => /^era\d+\.json$/.test(f)).sort();
const byId = new Map();
for (const f of files) {
  const { nodes } = JSON.parse(readFileSync(new URL(f, dir), 'utf8'));
  for (const n of nodes) {
    const prev = byId.get(n.id);
    // Keep the richer record when two eras describe the same node, and the sources of both.
    if (!prev || JSON.stringify(n).length > JSON.stringify(prev).length) byId.set(n.id, { ...prev, ...n });
    if (prev) byId.get(n.id).sources = [...new Set([...(byId.get(n.id).sources ?? []), ...(prev.sources ?? []), ...(n.sources ?? [])])];
  }
}
const overrides = JSON.parse(readFileSync(new URL('overrides.json', dir), 'utf8'));
for (const n of overrides.add ?? []) byId.set(n.id, n);
for (const [id, patch] of Object.entries(overrides.patch ?? {})) {
  if (!byId.has(id)) throw new Error(`override for unknown node ${id}`);
  const n = byId.get(id);
  for (const [k, v] of Object.entries(patch)) {
    if (v === null) delete n[k];
    // Patched sources add to the researched ones rather than replacing them.
    else if (k === 'sources') n[k] = [...new Set([...v, ...(n[k] ?? [])])];
    else n[k] = v;
  }
}
const nodes = [...byId.values()].sort((a, b) => a.start - b.start);
// Book citations first, then the other sources in their researched order.
for (const n of nodes) if (n.sources) n.sources.sort((a, b) => /^Pelikan /.test(b) - /^Pelikan /.test(a));
const problems = [];
for (const n of nodes) {
  for (const p of n.parents ?? []) if (!byId.has(p)) problems.push(`${n.id}: missing parent ${p}`);
  if (n.on && !byId.has(n.on)) problems.push(`${n.id}: missing branch ${n.on}`);
  for (const s of n.splits ?? []) if (!byId.has(s)) problems.push(`${n.id}: missing split ${s}`);
  if (n.type === 'tradition' && !n.parents?.length && n.id !== 'apostolic') problems.push(`${n.id}: tradition without parent`);
}
writeFileSync(new URL('../src/data/nodes.json', import.meta.url), JSON.stringify(nodes, null, 1) + '\n');
console.log(`${nodes.length} nodes from ${files.length} files`);

// The sacraments grid and the "My church" step text are used as researched.
const sacraments = JSON.parse(readFileSync(new URL('sacraments.json', dir), 'utf8'));
writeFileSync(new URL('../src/data/sacraments.json', import.meta.url), JSON.stringify(sacraments, null, 1) + '\n');
const steps = JSON.parse(readFileSync(new URL('lineage-steps.json', dir), 'utf8'));
writeFileSync(new URL('../src/data/steps.json', import.meta.url), JSON.stringify(steps, null, 1) + '\n');
console.log(`${sacraments.rows.length} sacrament rows, ${Object.keys(steps.steps).length} steps`);
if (problems.length) console.log(problems.join('\n'));
