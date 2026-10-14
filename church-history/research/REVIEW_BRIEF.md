# Correctness review brief

You are fact-checking an interactive church-history map for a Protestant layperson who is learning about the sacraments. It is live at https://church-history.onemany.workers.dev. Accuracy matters more than anything else. Be neutral between traditions.

Project: /Users/zackbart/Dev/apps/apps/church-history
- `research/era1.json` ... `era4.json`: researched nodes (traditions, councils, splits, events, people). Schema is in `src/types.ts`.
- `research/overrides.json`: hand fixes applied on top of the era files (it can add nodes and patch fields).
- `research/sacraments.json`: the sacraments grid (12 traditions x 7 rites, each cell has a status and a note).
- `research/lineage-steps.json`: one sentence per tradition for the "My church" path.
- `src/layout.ts`: chapter narration (CHAPTERS), short display names, which tradition sits under which communion view (EUCHARIST, EUCHARIST_OF), lane order.
- `src/emblems.ts`: the symbol shown for each tradition, with a comment naming it.
- `src/screens.ts` and `src/main.ts`: how the data is shown. In the simple view, a tradition's parent is its first `parents` entry that is one of the 12 main traditions, so for example Pentecostal shows as coming from Methodist and Baptist from Anglican.

Check every claim you own: dates, names, numbers, who did what, parent/child relationships between traditions, which council or split produced which branch, sacrament statuses, and the communion-view category each tradition is placed in. Verify against good sources (official church documents and catechisms, Britannica, academic or encyclopedic references). Do not "fix" things that are defensible simplifications for a 30,000 ft view. Fix things that are wrong or misleading.

Rules:
1. Edit ONLY the files listed as yours in your task. Do not touch any other file.
2. Keep valid JSON and the existing schema. Do not rename ids. Do not add or remove nodes unless your task says you may.
3. For every change, add a supporting source URL to that node's `sources` (or row's `sources`).
4. Any new or changed text must follow /Users/zackbart/.agents/skills/unslop/SKILL.md (read it first): plain words, short sentences, active voice, no em or en dashes, no semicolons, straight quotes. Keep the existing length limits: summary 30 words, why 25, each fact 18, sacraments 30, today 12, disputed 25, sacrament cell notes 15.
5. Write a log to the review file named in your task. One entry per issue: the id and field, what was wrong, what you changed it to, and the source. Also list issues in files you do not own (layout.ts, emblems.ts, other agents' files) under a heading "For the lead" without editing them.
6. Validate your JSON files parse (python3 -c "import json;json.load(open(PATH))") and run `node scripts/merge-data.mjs` at the end to confirm no broken references.

Final reply: a short summary with the count of fixes and the "For the lead" items.

## Source standard (applies to every round from round 2 on)

**Baseline: Jaroslav Pelikan.** The reference baseline for this map is Jaroslav Pelikan, *The Christian Tradition: A History of the Development of Doctrine* (5 vols., University of Chicago Press, 1971 to 1989), together with Pelikan and Valerie Hotchkiss, eds., *Creeds and Confessions of Faith in the Christian Tradition* (Yale University Press, 2003) for the texts of creeds and confessions. The five volumes map onto this timeline:
1. *The Emergence of the Catholic Tradition (100 to 600)*
2. *The Spirit of Eastern Christendom (600 to 1700)*
3. *The Growth of Medieval Theology (600 to 1300)*
4. *Reformation of Church and Dogma (1300 to 1700)*
5. *Christian Doctrine and Modern Culture (since 1700)*

Check the map's framing of doctrine, councils, schisms, and sacramental theology against Pelikan. Where the map's story departs from Pelikan's account, prefer Pelikan's account unless a tradition's own documents or more recent scholarship clearly correct it, and log the decision. Cite Pelikan by volume and chapter (and page only when you have actually seen it). Link the publisher page or a Google Books page as the URL. **Never invent a page number, quotation, or chapter title.** If you cannot see the text, say in your log what you could and could not verify.

Every claim should rest on the best available source. Use this order, with Pelikan as the first scholarly reference in tier 2:

1. **The tradition's own voice.** Official sites and documents of the church body, council texts, creeds, confessions, catechisms, and church orders (for example the Catechism of the Catholic Church, the Book of Concord, the Westminster Standards, the Thirty-Nine Articles, the Baptist Faith and Message, the Assemblies of God fundamental truths, statements from the Ecumenical Patriarchate or the Assyrian Church of the East). For "what X teaches", X's own statement wins.
2. **Scholarly reference.** Pelikan first (see above), then the Oxford Dictionary of the Christian Church, the Cambridge History of Christianity, Britannica, the Stanford Encyclopedia of Philosophy, university press books, and peer-reviewed articles.
3. **Membership numbers.** Pew Research Center, the World Christian Database (Gordon-Conwell), and the church body's own reported figures. Say which source and year.
4. **Recent events (2018 to 2026).** The church body's own announcements first, then major outlets (AP, Reuters).

**Second cross-check: Damick.** Use Fr. Andrew Stephen Damick, *Orthodoxy and Heterodoxy: Finding the Way to Christ in a Complex Religious Landscape* (Ancient Faith Publishing, 2nd ed. 2017), and the Ancient Faith Radio podcast series it grew from, as a comparative cross-check. It surveys the traditions in this map and how they differ on the church, salvation, and the sacraments. Note that it is written from an Eastern Orthodox perspective. Where Damick's description of another tradition differs from that tradition's own documents, follow the tradition's own documents for the main text, and consider whether the difference belongs in the `disputed` field. Cite Damick (book or podcast episode URL) where it supports a claim. Record in your log any place where Damick and the map disagree, and how you resolved it.

**Replace weak sources.** Remove or replace tourism sites, single parish or congregation pages, personal blogs, popular ministry sites, aggregators such as encyclopedia.com when a primary or scholarly source exists, and general news for anything older than a few years. Never use Wikipedia as a cited source. Every node and grid row should end with at least one Tier 1 or Tier 2 source. Keep 2 to 4 sources per item.
