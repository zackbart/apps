# Church History Map

A 3D branching timeline of the Christian church from Jesus to today. Built with Three.js, TypeScript, and Vite.

Four views:

- **Timeline.** Scroll or swipe to move through time. The story chapters change as you go.
- **Explore.** The free 3D map. Drag to turn, scroll to zoom.
- **My church.** Pick a tradition and follow its line back to Jesus.
- **Sacraments.** Twelve traditions against seven rites, with a note for every cell.

## Use

- Left and right arrow keys move between chapters. `/` opens search. `Esc` clears the selection.
- "View of communion" recolors every line by what that tradition believes happens at the Lord's Supper.
- "More detail" adds the minor branches and events.
- Links like `/#baptist` open straight to a tradition.

## Data

`research/era1.json` to `era4.json` hold the researched nodes, one file per era, and `research/overrides.json` holds hand fixes on top of them. `research/sacraments.json` and `research/lineage-steps.json` feed the Sacraments and My church views. Rebuild the app data after editing any of them:

```sh
node scripts/merge-data.mjs
```

The script writes `src/data/nodes.json` and lists any broken references. Lane order and colors live in `src/layout.ts`.

## Develop

```sh
npm install
npm run dev
```

Run the checks with `npm run build`.

## Deploy

The app uses Cloudflare Workers Static Assets.

```sh
npm run deploy
```
