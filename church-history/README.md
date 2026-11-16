# Church History Map

A map of the Christian church from Jesus to today. Built with TypeScript, SVG, and Vite.

Four views:

- **Story.** Read the history in chapters. A pinned map zooms to each chapter's years and draws the lines as you scroll.
- **Map.** The full map. Drag to move through time, scroll or pinch to zoom, or jump to an era. "More detail" adds the minor branches and events.
- **My church.** Pick a tradition and follow its line back to Jesus. Add a second church to see where the two part ways and how their sacraments compare.
- **Sacraments.** Twelve traditions against seven rites, with a note for every cell.

## Use

- On the map, "Family", "Communion", and "Claims" color every line. "Communion" shows what each tradition believes happens at the Lord's Supper. "Claims" shows how each tradition describes its own relation to the apostolic church: continuing it, reforming it, renewing it, or restoring it. The map shows these claims side by side and does not judge between them. Each tradition's panel and the compare table carry its sentence, "How it sees itself".
- From about 600 the shared line runs as two strands, Greek East and Latin West, that drift apart and run straight on into the Eastern Orthodox and Catholic lines, so neither bends away at 1054. The Church of the East and the Oriental Orthodox also drift off gradually. The years and their Pelikan citations are in `DRIFT` and `EAST_WEST` in `src/layout.ts`.
- `/` opens search. `Esc` clears the selection. On the map, the arrow keys move through time and `+` and `-` zoom. In the story, the left and right arrow keys move between chapters.
- Links like `/#baptist` open the map on a tradition. `/#compare=baptist,catholic` opens a comparison. `/#map`, `/#church`, and `/#sacraments` open a view.
- On a first visit, a picker asks which church the reader goes to, with familiar names for each family. They can skip it. The church they pick, here or in "My church", is remembered and drawn in red on the maps. Links to a view or a tradition skip the picker. `/?start` starts fresh: it forgets the saved church and opens the picker at the top of the story.

## Data

`research/era1.json` to `era4.json` hold the researched nodes, one file per era, and `research/overrides.json` holds hand fixes on top of them. `research/sacraments.json` and `research/lineage-steps.json` feed the Sacraments and My church views. `research/claims-*.json` hold each tradition's "How it sees itself" sentence and claim category (see `research/CLAIMS_BRIEF.md`). Rebuild the app data after editing any of them:

```sh
node scripts/merge-data.mjs
```

The script writes `src/data/nodes.json` and lists any broken references. Lane order, colors, and the story chapters live in `src/layout.ts`.

`research/pelikan-basis-*.md` hold the review of how Pelikan's *The Christian Tradition* could serve as the basis for the map's structure.

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
