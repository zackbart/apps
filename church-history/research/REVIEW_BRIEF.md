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

## Pelikan rebase (round 2 onward)

We now have the full text of all five Pelikan volumes. This replaces the "cite by volume and chapter" fallback above. Every historical claim on the map gets checked against the book itself and cited to the page.

**The text.** `research/books/pelikan/text/` holds one plain-text file per volume (vol1 to vol5). Each page starts with a `=== PDF page N ===` marker. The printed book page number is in the running header on the next line (for example `The Orthodoxy of Old Rome    153`). Cite the printed page, never the PDF page. The source PDF is `research/books/pelikan/pelikan-christian-tradition-vols1-5.pdf` if a page's text looks garbled. This folder is not in git. Never copy more than a short quote from it into any tracked file.

Search it with `grep -n -i` (try several spellings and synonyms, since this is scanned text: "Filioque", "procession", "transubstantiation", "Chalcedon", and so on). Then read the surrounding pages before you rely on a passage. Use the margin notes (primary-source references in the left column) only as context.

**What counts as a historical claim.** Dates, names, councils and what they decided, schisms and their causes, who taught what, where a tradition came from, and how doctrine developed (especially sacramental doctrine). Present-day facts are not historical claims: membership numbers, 2018 to 2026 events, and current church structures keep their current sources and standard.

**The process for each claim you own:**
1. Find what Pelikan says about it. Read the relevant pages, not just one matching line.
2. If the map agrees with Pelikan, add the citation.
3. If the map departs from Pelikan, rewrite it to follow Pelikan, unless the tradition's own documents (for "what X teaches today") or clearly newer scholarship contradict him. In that case keep the map's version and log why.
4. If Pelikan does not cover the claim, keep its current sources and log it as "not in Pelikan". Do not stretch a loosely related passage to cover it.
5. Pelikan is a history of doctrine. Do not add claims just because he discusses them. Fix and source what the map already says, keeping the 30,000 ft view.

**Citation format (strict).** Add Pelikan citations to `sources` as plain strings in exactly this form: `Pelikan 1:172` or `Pelikan 4:183-189` (volume:printed pages, at most 30 pages, hyphen not dash). The app shows them as book citations. Put the most specific range you actually read. Keep 2 to 5 sources per item: the Pelikan citation(s) first, then the best tier 1 source. Drop weak sources (see above) when Pelikan or a primary source covers the claim.

**Proof in the log.** For every Pelikan citation you add, the log entry gives the node id and field, the citation, and a short exact quote from that page (25 words at most) that supports the claim. The lead will check the quotes against the text, so copy them exactly as they appear in the text file, including any scan errors. Never invent a quote or a page.

**Damick** is not available locally yet. Do not cite it in this round.

**Validate** at the end: your JSON parses, `node scripts/merge-data.mjs` reports no broken references, and `node scripts/check-pelikan.mjs` reports no problems.

## Verification rounds (round 3 onward)

Round 2 added Pelikan citations and logged a quote for each in `research/rebase-1.md` to `rebase-5.md`. The lead has confirmed that every logged quote really is on its cited page. What has not been checked is whether each cited passage supports the specific claim it is attached to. That is the job now. You are a skeptical second reader.

For every item you own:
1. **Support.** For each Pelikan citation, read the cited pages in full. Decide whether they support what the item's text actually says, field by field. A passage that only mentions the topic is not support. If a citation does not support anything in the item, remove it. If the range is wider than needed, narrow it. If Pelikan on those pages contradicts the item's text, fix the text to follow him (same rules as round 2).
2. **Missed coverage.** For items or claims logged as "not in Pelikan", search again. Each volume ends with an index of names and subjects (search the last 20 or so pages of each text file), and terms can be spelled differently in a scan. Add a citation only if you find a passage that directly supports the claim.
3. **Text.** Read every text field with fresh eyes against Pelikan. Fix anything wrong or misleading at the 30,000 ft level. Do not polish wording that is already accurate.
4. **Present-day facts** (membership, current structures, 2018 to 2026 events) stay outside the Pelikan check. Flag one only if it is plainly wrong.

**Log format (strict, one line per quote):** `- <id>.<field>: <what you did>. `Pelikan 2:183-187`, printed page 183: "exact quote"`. Quotes must be copied exactly from the text file, 25 words at most. Also list every citation you removed or narrowed, and why.

**Clean round.** End your log with a line `Result: CLEAN` if you made no text changes and removed no citations (narrowing a range or adding a well-supported citation still counts as clean), otherwise `Result: CHANGES` and a count.

Validate as in round 2: your JSON parses, `node scripts/merge-data.mjs` shows no broken references, `node scripts/check-pelikan.mjs` and `node scripts/check-pelikan-quotes.mjs <your log>` report no problems.
