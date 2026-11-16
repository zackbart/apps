# "How it sees itself" brief

The map draws every tradition as a line that leaves the shared early church. Readers ask "which branch is the one that did not change?" The map must not answer that itself, because it is the question the traditions disagree on. Instead, each tradition gets one sourced sentence on how it understands its own relation to the apostolic church, plus a claim category. The map then shows the claims side by side.

Project: /Users/zackbart/Dev/apps/apps/church-history. Read `research/REVIEW_BRIEF.md` in full first. Its source rules, neutrality rule, and writing rules apply here, and so does `/Users/zackbart/.agents/skills/unslop/SKILL.md`.

## Sources, in this order

1. **Pelikan**, *The Christian Tradition*, full text in `research/books/pelikan/text/` (one file per volume, `=== PDF page N ===` markers, printed page in the running header). Cite as `Pelikan <vol>:<page>` or `Pelikan <vol>:<first>-<last>` with printed pages, the same format the map already uses. Pelikan often states how a confession understood itself, for example how the Reformers saw themselves in relation to the catholic church, or how the East saw its fidelity to the fathers.
2. **Damick**, *Orthodoxy and Heterodoxy*, full text in `research/books/damick/text/` (one file per chapter). Cite as `Damick ch<N>: <SECTION HEADING>` exactly as the heading appears, the format the map already uses. Damick writes as an Orthodox priest. Use him for how a tradition describes itself only where he reports that tradition's own view, never for his assessment of it.
3. **The tradition's own documents** (confessions, catechisms, official statements), only where Pelikan and Damick are silent or to confirm a self-description. Give a URL.

Every claim needs at least one source from 1 or 2 where the books cover the tradition. Traditions after 1700 that the books do not cover may rest on tier 3 alone. Say so in your log. Never invent a page, a heading, or a quotation. Quote at most one short sentence from either book in your log, and never in the JSON.

## What to write for each tradition

- `self`: one sentence, at most 25 words, in the tradition's own terms, framed as its claim: "Sees itself as ...", "Holds that ...". Not the map's verdict. Plain words, no dashes, no semicolons, straight quotes.
- `claim`: one of
  - `continuity`: claims to be the church Christ founded, continuing without a break (for example through apostolic succession and unchanged faith).
  - `reform`: claims to be the catholic or apostolic church reformed, keeping continuity while correcting errors.
  - `renewal`: began as a renewal movement inside another church and does not claim to replace it.
  - `restoration`: claims to recover the New Testament church or apostolic faith that others lost or obscured.
  - `other`: none of these fits cleanly. Explain in the log.
- `sources`: 1 to 3 citations in the formats above.

Several traditions will legitimately share a category. Several will claim `continuity` at once. That is the point. Pick the category the tradition itself would use. Where its members disagree, pick the official or majority self-description and note the disagreement in your log.

## Output

Write a JSON file with this exact shape and nothing else in it:

```json
{
  "claims": {
    "<tradition id>": { "self": "...", "claim": "continuity", "sources": ["Pelikan 2:280-295", "https://..."] }
  }
}
```

Use the ids exactly as in `src/data/nodes.json`. Validate with `python3 -c "import json;json.load(open(PATH))"`.

Also write a log (path given in your task): one entry per tradition with the category, why, what you read (volume and printed pages, or chapter and section), and anything you could not verify.

Edit only your two files. Do not commit.
