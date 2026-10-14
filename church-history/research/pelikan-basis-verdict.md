# Verdict on making Pelikan the entire basis

Reviewed October 14, 2026.

Choose **b, the hybrid**. Let Pelikan guide the historical narrative and the explanation of doctrine. Keep the denomination lines, modern history, and current sacramental teaching on other sources. Reject c for this project's present audience and scope. Keep a if the team cannot fund a bounded narrative revision.

The full rebuild has a defensible case. It would produce a more coherent history of doctrine. It would also change the product's subject. A Protestant reader asking where their church came from would lose some of the very churches they came to find.

## What I checked

I read REVIEW_BRIEF.md in full. I skimmed all five rebase logs, all eight verify logs, all four Damick logs, and both final logs. I inspected the generated nodes, schema, merge script, sacrament rows, lineage sources, chapter narration, and the code that follows parent links.

I searched the local text of all five Pelikan volumes. I read relevant passages in volumes 1, 2, 4, and 5, with most coverage work in volume 5. I checked printed running headers. All book page citations below refer to printed pages. Preface citations use the book's printed Roman numerals. I include no quotation from Pelikan.

I also checked the linked texts of later agreements and Sebastian Brock's 1996 article. I did not conduct a new audit of every map claim, membership figure, or live interaction. This is a decision review, not another complete fact-check.

"Verified" means I checked the file or source. "Inference" means my judgment about audience, emphasis, or implementation. "Search finding" means no supporting treatment surfaced in the supplied OCR text. Search findings are weaker than proof of absence.

## Pelikan already does substantial work

Verified count from src/data/nodes.json, counting sources strings that start with "Pelikan":

- 127 nodes in total.
- 85 nodes carry at least one Pelikan citation, or 66.9 percent.
- Those nodes carry 147 citation entries, representing 128 distinct citation strings.
- Citation entries by volume are 40, 31, 7, 42, and 27 respectively.
- 42 nodes carry no Pelikan citation.
- Of 41 nodes whose start year is 1700 or later, 12 carry a Pelikan citation. The other 29 do not.

These are exact node and citation counts. They are not an exact count of supported claims. The schema attaches sources to a whole node. It does not attach a citation to each date, sentence, or relationship. One citation can support several claims, or only one clause. Calling the 147 entries "147 verified claims" would invent precision the data does not contain.

The generated sacrament grid adds 12 Pelikan entries across nine of its 12 rows. The lineage file adds 16 entries in a shared source list. These also lack claim-level assignments. A citation on a row does not certify all seven cells. A shared lineage citation does not certify every step.

The logs show what the previous work bought. Rebase 1 changed one node text field. Rebases 2, 3, and 4 changed no displayed node text. They mainly added citations and improved sources. Rebase 5 changed two cell notes, qualified a Catholic teaching claim, and dated figures. The verification passes then narrowed ranges and removed citations that only mentioned a related topic. Verify 3 removed five such citations. The next review did not restore them.

One useful example is restorationist. Its present Pelikan citation supports Campbell's unity program. It does not establish the 1832 union or later denominational separations. Another is methodist. Its citations support Wesley's doctrine, not the full institutional path to separate Methodist churches. These limits appear in verify-r4-4.md and verify-r4-3.md.

The Damick and final passes also protected the map from imported denominational judgments. They retained official Methodist teaching about Christ's presence, Lutheran absolution, and qualifications about Baptist and independent evangelical Communion. Those decisions are logged in damick-2.md, damick-3.md, damick-4.md, and final-B.md.

Inference: this is already a source hybrid. Its remaining weakness is the narrative and the meaning readers assign to the lines. Replacing all its sources would discard safeguards that the reviews deliberately added.

## The honest case for a Pelikan rebuild

Pelikan asks a question that fits sacramental learning well: how Christians came to teach what they teach. His account separates the early development of individual rites from the later general theory and count of sacraments. He also explains early Eucharistic language that combines presence and symbolism. Verified in vol. 1, ch. 3, printed pp. 163 and 168.

That offers a real gain over a sequence of founding dates. A reader can learn why Christians disagree about grace, the church, and material rites. The tree can otherwise suggest that every split created a new sacramental position. The current family and Communion colors overlap, and the code already acknowledges some variation, but a reader can still mistake a visual branch for a doctrinal break. That is an inference about the presentation, not a finding from user testing.

Pelikan also challenges the old Western habit of treating Eastern theology as finished after the early councils. He explicitly sets out to recover its continuing history. Verified in vol. 2, introduction, printed pp. 1-3. That is valuable for a Protestant audience which may know little about Eastern traditions.

A single sustained account can reduce contradictions between agents. It can keep a disputed question in context instead of joining unrelated encyclopedia summaries. A full rebuild would give the team freedom to stop treating councils, people, churches, and movements as if they all belonged in one institutional family tree.

The strongest case for c therefore assumes a different promise: an interactive companion to Pelikan's history of doctrine. That could be a good product. It would need an openly narrower scope. It could not honestly promise a complete church family map through 2026.

## What the target reader loses

Pelikan defines his subject as church doctrine and recognizes that church life exceeds doctrine. Verified in vol. 1, introduction, printed pp. 1-2. He explicitly limits institutional, political, and military history to what bears on doctrine. Verified in vol. 2, introduction, printed pp. 4-5.

That boundary matters. "Where did my church come from?" can require migration, revival networks, racial exclusion, legal organization, mergers, and local independence. A doctrine history need not explain those things. No amount of extra citation searching changes its chosen subject.

The present map gives readers recognizable church names, a "My church" path, and a current sacrament comparison. Its source rules give a tradition's own documents priority for what it teaches today. A sole historical survey cannot replace that evidence. This is a verified description of the project, followed by an inference about fit.

The loss would be sharpest for readers from Pentecostal, Adventist, and independent evangelical churches. Their church could become a footnote to an older doctrinal dispute. Alternatively, the team could retain the church label and infer its history from a general discussion of experience or authority. The first choice reduces usefulness. The second reduces accuracy.

Pelikan is not equally thin across all modern Protestant subjects. The next section makes that distinction.

## Modern coverage checked in the text

### Baptists

Verified: volume 5 discusses German Baptists in Pennsylvania and their private assemblies. It later mentions Baptist insistence on immersion. See vol. 5, ch. 1, printed pp. 9-10 and 46. In ch. 5, printed p. 258, he discusses Baptist and other critics of baptismal practice, with a Campbell debate among the references.

Search finding: I found no account establishing Smyth and Helwys, the 1609 and 1612 congregations, General and Particular Baptist origins, or the later American convention histories. The previous reviews reached the same limit. A reference to German Baptists does not establish the history of English Baptist churches. Baptism by immersion also does not establish a family's whole Communion doctrine.

### Methodists and Holiness churches

Verified: this is meaningful coverage. Pelikan places Methodism within Anglicanism in vol. 5, ch. 1, printed p. 37. He discusses Wesley's relation to creeds and personal faith in ch. 3, printed p. 124. He gives sustained attention to Wesley's account of perfection in that chapter, printed pp. 148-149, and connects Methodist and Eastern appeals to imitation of God on printed p. 154.

Search finding: those passages do not establish the 1784 denominational organization, AME's origins, or the later Holiness institutions. Searches found no Phoebe Palmer. The volume's Palmer reference names William Palmer. General Wesleyan perfection cannot source the Nazarene unions or every later doctrine of a second blessing. The existing Methodist and Holiness citations remain useful within these limits.

### Restorationists

Verified: Campbell is not absent. Pelikan discusses his Scripture and church argument in vol. 5, ch. 5, printed pp. 241 and 260, his opposition to creeds on printed pp. 269-270, and his unity program in ch. 6, printed p. 313.

Search finding: I found no adequate account of Stone's movement, the 1832 union, the 1906 census distinction, or the 1968 Disciples structure. The volume's Stone match is ordinary biblical language. Campbell's theology is coverage of one founder's arguments. It is not a full history of all Restorationist bodies or their sacramental differences.

### Pentecostal and charismatic churches

Verified: the section on experience of the Holy Spirit discusses earlier spirituality, revival experience, and discernment. Examples include vol. 5, ch. 3, printed pp. 162-163, 167, and 169. Page 169 includes Swedenborg and Quakers. It does not narrate Azusa Street.

Search finding: searches across all five files returned no matches for Pentecostal, Azusa, Parham, or Seymour. I also found no direct treatment of Oneness origins or the modern charismatic movement. References to biblical Pentecost do not establish modern Pentecostal history. This is a major coverage gap for the audience, not a minor missing date.

### Adventists and independent evangelicals

Search finding: I found no Adventist treatment, Ellen White, Mormon treatment, Jehovah's Witnesses, nondenominational grouping, or Salvation Army treatment in the five files using those names and common variants. Volume 5's many Miller references mostly identify editions of Edwards, not William Miller. Its Advent references concern the liturgical season. Its Nazarene language concerns early Christianity, not the modern Church of the Nazarene.

Verified context: Pelikan does discuss American evangelical reactions to modernism and The Fundamentals in vol. 5, ch. 6, printed p. 326. That narrow treatment cannot establish the origins or contemporary sacramental range of independent evangelical congregations.

These absence findings carry no invented page citation. I checked matching context and the volume 5 index, not just a search count. OCR can miss a name. Still, the combination of sparse positive treatment and repeated independent review findings strongly supports the coverage verdict.

### The actual endpoint

Verified: Pelikan says he chose Vatican II as the endpoint. See vol. 5, Preface, printed p. vii. The final chapter reaches its conclusion through Vatican II. See vol. 5, ch. 6, printed pp. 325-326 and 336.

Inference: publishing the volume in 1989 does not make it a history through 1989, much less through 2026. Even an otherwise complete doctrinal rebuild would need later sources.

## Neutrality and perspective

Pelikan served as a Lutheran minister and entered the Orthodox Church in 1998. The [Orthodox Church in America's obituary](https://www.oca.org/news/archived/in-memoriam-dr.-jaroslav-pelikan) confirms both. His later conversion does not prove bias in books written earlier. Nor does his Lutheran identity make every interpretation Lutheran advocacy.

There are concrete choices of emphasis to assess.

First, he deliberately corrects Western neglect of the East. His criticism is explicit in vol. 2, introduction, printed pp. 1-3. This improves the map's balance. Yet his treatment of the East is a doctrinal account, not a complete account of every Eastern church. Its selective scope is explicit on printed pp. 4-5.

Second, he does give the Church of the East and Oriental Orthodox theology serious space. The volume 2 contents locate the former discussion at printed pp. 39-49 and the latter at printed pp. 49-61. These sections share a boundary page. In ch. 2, printed pp. 50-52 and 57, he explains Syriac authorities, liturgy, and a union without confusion. It would be false to say he simply ignores these traditions or equates their teaching with Eutyches.

But his framing retains a Chalcedonian center. In vol. 2, ch. 2, printed p. 39, he distinguishes orthodoxy from Nestorian and Monophysite positions. On printed p. 49, he judges that the former authors preferred duality of hypostases and accepted unity of person under pressure. Those are interpretive judgments. A neutral lay map should not silently turn them into the current churches' self-description.

Third, he gives modern free churches much less attention than their importance to this audience warrants. The volume 5 index's Baptist entry points to printed pp. 9-10 and 46. Those chapter 1 passages are narrow compared with the sustained cross-tradition treatment of doctrine elsewhere. Campbell receives selected attention as a critic of creeds. In vol. 5, ch. 5, printed p. 260, Pelikan also judges other Protestants' Scripture and church account more sophisticated than Campbell's sharp division. That is an evaluative voice, not a neutral transcription.

Fourth, the endpoint gives Vatican II unusual weight. In vol. 5, ch. 6, printed p. 326, Pelikan ranks it above the earlier twentieth-century Catholic, Orthodox, evangelical, and Anglican declarations in historical importance. This is clear evidence of emphasis. It also cuts against the simplistic charge that his narrative merely promotes Lutheranism.

Inference: the measurable imbalance is chiefly in selection, vocabulary, and the importance assigned to events. I cannot turn it into a numerical score for confessional bias. Exclusive use would make the map inherit those choices without correction. Neutrality requires attribution, the churches' own accounts, and scholarship that challenges the inherited labels.

## What later evidence changes

Later agreements do not erase the history of disagreement. They change claims about what still divides particular churches. A map needs both dates and both contexts.

1. **Church of the East Christology.** Pelikan's vol. 2, ch. 2, printed pp. 39 and 49, uses the Nestorian classification and a hypostasis-based account of the division. The [1994 Catholic and Assyrian declaration](https://www.vatican.va/content/john-paul-ii/en/speeches/1994/november/documents/hf_jp-ii_spe_19941111_dichiarazione-cristologica.html) confesses one person, full divinity and humanity, and recognizes the legitimacy of the churches' different Marian expressions. It says past division involved substantial misunderstanding. Update any implication that the present Assyrian Church teaches two persons. Do not claim the agreement restored full communion.

2. **Syriac terminology and inherited labels.** Sebastian Brock's [1996 article](https://cdn.bookswithsyro.co.uk/1750372899168-371ri6zuir1.pdf), Bulletin of the John Rylands Library 78.3, printed pp. 23-28, explains why "Nestorian Church" misleads and why Syriac qnoma does not map neatly onto Greek hypostasis or person. This directly complicates Pelikan's vol. 2, ch. 2, printed p. 49 framing. Brock also distinguishes Oriental Orthodox teaching from Eutyches. Pelikan already records important qualifications on printed p. 57. The correction is to the shorthand and interpretive framework, not a claim that his entire account is wrong.

3. **Lutheran and Catholic justification.** Pelikan describes justification as a principal Reformation divide in vol. 4, ch. 3, printed pp. 138-139. That historical claim stands. The [1999 Official Common Statement](https://www.christianunity.va/content/unitacristiani/en/dialoghi/sezione-occidentale/luterani/dialogo/documenti-di-dialogo/1999-dichiarazione-congiunta-sulla-dottrina-della-giustificazion/en3.html) records consensus in basic truths and says the relevant condemnations do not apply to the teaching presented by the dialogue partners. A current map cannot present the sixteenth-century dispute as unchanged for those partners. It must also avoid applying the agreement to every Lutheran body or treating it as full communion. The map already has a separately sourced 1999 node.

4. **Eastern and Oriental Orthodox dialogue.** Pelikan describes the distinct Christological traditions in vol. 2, ch. 2, printed pp. 49-57. The [1990 Second Agreed Statement](https://orthodoxjointcommission.wordpress.com/2013/12/14/second-agreed-statement-1990/), especially paragraphs 7-10, recognizes the compatibility of the participating families' formulas and recommends lifting anathemas. This updates the account of dialogue and present disagreement. It is a commission statement submitted to churches for action. It does not establish universal reception or restored communion.

5. **A concrete Eucharistic update.** The [2001 admission guidelines](https://cnewa.org/eastern-christian-churches/ecumenical-relations/relations-between-the-catholic-church-and-the-assyrian-church-of-the-east/2001-guidelines/) recognize the validity of the Addai and Mari anaphora without a single recited institution narrative and permit reciprocal reception under specified conditions. This matters directly to this sacrament project. It is an addition beyond Pelikan's endpoint, not a demonstrated error in his discussion. Earlier liturgical theology cannot source the later ruling.

6. **A specific chronological correction already encountered.** Pelikan places what he considers the earliest documentation of the Western Nicene recension in 796. See vol. 2, ch. 4, printed p. 184. The [2003 Orthodox-Catholic Filioque statement](https://www.usccb.org/resources/filioque-a-church-dividing-issue.pdf), section II, identifies creedal use at Toledo in 589 and Roman liturgical adoption in 1014. Distinguish creedal language, the precise recension, and liturgical adoption rather than declaring the two sources identical in scope. Rebase-2.md already logged this reason to retain later evidence.

These examples alone defeat the sole-source rule. Several directly affect sacramental comparison or how readers understand a branch. They are not optional modern decoration.

## Cost and what breaks

These are rough estimates, not measured engineering bids. One research round means a project-wide pass with defined review scopes. It can contain several agent tasks. Estimates include independent verification and integration. They assume the local books remain available and exclude deployment. I did not inspect the other agents' proposals.

### A. Keep the structure and the present source policy

Allow roughly **one or two further research rounds**. Focus on unsupported claims, source scope, and how the narrative explains ancestry and Communion categories. Do not repeat the finished citation search without a new reason.

Code work should be small. It may be only text and source edits in research files and src/layout.ts, followed by generated data. The schema, Three.js renderer, and existing navigation can stay. Required validation would cover the merge, citations, build, and any changed display.

What breaks: little technically. What stays weak: a parent line can still look like clean institutional descent. The simple view follows the first eligible tradition parent. Multiple influences can disappear. The narration still gives denomination growth more attention than changes in sacramental belief.

A is defensible. It protects recognizable paths and makes best use of the existing review investment. Its disadvantage is that it may leave the central teaching problem untouched.

### B. Revise the framing while retaining church history and current authorities

Allow roughly **three or four research rounds**. Establish the narrative's scope, check the new doctrinal framing against the books and the retained modern sources, then have a skeptical reader verify it and review the integration. Existing node-level work should carry forward where the wording and meaning remain the same.

Code work is moderate if the scope stays bounded. Expect changes to chapter narration and navigation in src/layout.ts and src/main.ts, selected research text, and generated data. Any new explanatory content needs a way to display its sources. The existing denomination model and "My church" path can survive. A new doctrine browsing mode would add work in src/types.ts and src/screens.ts, but that is a separate product choice, not a prerequisite for this recommendation.

What breaks if handled badly: the chapters and the selected church path can tell different stories. Doctrinal influence can look like institutional ancestry. The five books cannot simply become five consecutive time blocks. Volumes 2, 3, and 4 overlap in time and cover different regions. Verified in vol. 1, Preface, printed p. ix.

B also has a real cost: two kinds of historical organization must agree. The gain is worth that cost because the target reader needs both. Stop the revision if it starts deleting modern churches merely to fit the book's coverage.

### C. Rebuild with Pelikan as the sole basis

Allow roughly **five to seven research rounds** for a genuinely new interpretation and content set. The work includes selecting material, tracking each new claim, checking the translations and terminology used in the explanation, independently reviewing every new relation, and reviewing the final presentation. Many of the existing 147 citation assignments would need rechecking against new claims.

Code work is large. A doctrine-centered model would affect src/types.ts, research and merge conventions, layout, rendering, source display, church paths, and comparison screens. The current code uses tradition IDs and parent chains throughout. It does not become a doctrine graph just because the content changes.

What breaks: the promise of a church family map from Jesus to 2026. The post-Vatican II events lose their source basis. Several modern church families lose direct historical coverage. The current sacrament grid loses authorities for present teaching. Existing tree relationships cannot simply become doctrinal relationships.

Those coverage failures are not temporary research debt. Strict exclusivity gives the agents no permissible source with which to fill them. If the team keeps other sources for these gaps, it has chosen b regardless of what it calls the rebuild.

## Final decision

B wins because it improves the explanation of sacraments while keeping the reader's church identifiable. The current source policy already contains the right exceptions. Preserve them.

The strongest objection to b is complexity. A cheaper a may outperform an ambitious hybrid that never ships. Bound b to the narrative and doctrinal explanation first. Do not approve a wholesale schema replacement simply as the price of using Pelikan.

The biggest risk is giving unsupported connections more authority through a polished new story. A doctrinal resemblance does not prove a church's ancestry. A historical theologian's view does not prove a whole family's present teaching. Review every changed connection and every changed current teaching against sources that actually establish it.

Reject c for this map. Consider it only as a separately scoped companion to Pelikan, with a shorter historical promise and clear coverage limits.
