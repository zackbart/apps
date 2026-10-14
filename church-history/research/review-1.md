# Review 1

Reviewed on October 14, 2026. Scope covers Jesus through 1516, including the present-day descriptions attached to these traditions.

Reviewed all 28 records in `era1.json` and all 29 records in `era2.json`. Both files contain `chalcedonian`, so this covers 56 distinct nodes. Checked dates, council decisions, names, numbers, tradition relationships, sacramental descriptions, and the relevant communion categories in `layout.ts`.

One issue fixed in `era2.json`. No corrections needed in `era1.json`. No nodes or IDs added, removed, or renamed. No changes made to files owned by other agents.

## Fix made

1. `photian-schism.facts` and `photian-schism.sources`, `era2.json`.

   The facts jumped from the conflict in 867 to the later council, leaving the node's 867 endpoint unexplained. The old sentence, "The 879 to 880 council later restores communion with Photius," could suggest that the rupture continued until then.

   Replaced it with two facts:

   - "Ignatius's restoration ends the rupture in 867."
   - "The 879 to 880 council later recognizes Photius as patriarch."

   Added [Timothy Ware's account on an Orthodox parish website](https://churchmotherofgod.org/histories/great-schism/) to the node's sources. Its account distinguishes the reconciliation under Ignatius from Photius's later recognition. The existing [OCA history of Photius](https://www.oca.org/orthodoxy/the-orthodox-faith/church-history/ninth-century/saint-photius-patriarch-of-constantinople) also supports this distinction. Kept the existing dates and the warning about differing Catholic and Orthodox interpretations.

## Checks that required no correction

- Nicaea I in 325, Constantinople I in 381, Ephesus in 431, and Chalcedon in 451 have the right dates and distinguish their teachings. The expanded creed's attribution to 381 already includes the needed historical qualification.
- `church-of-east-separation` already distinguishes independence in 424 from Ephesus in 431 and later doctrinal separation. Its 431 map branch explicitly simplifies a gradual process. The [WCC dictionary's Assyrian Church entry, PDF page 94](https://www.oikoumene.org/sites/default/files/2022-11/Dictionary%20of%20the%20Ecumenical%20Movement_Web.pdf#page=94) supports the 424 prohibition on appeals to western churches. Kept this defensible branch date.
- Oriental Orthodox nodes distinguish their teaching from Eutyches' teaching and describe separation after Chalcedon as gradual. The [WCC family profile](https://www.oikoumene.org/church-families/orthodox-churches-oriental) supports the six traditions and the approximate 60 million figure.
- Constantinople II in 553, Constantinople III in 680 to 681, and Nicaea II in 787 correctly describe the Three Chapters, Christ's two wills, and icon veneration. Honorius's condemnation belongs in the Constantinople III account.
- The Filioque node correctly distinguishes western adoption after Toledo in 589 from its first use at a papal Mass in 1014. The [joint Orthodox-Catholic consultation](https://www.assemblyofbishops.org/ministries/ecumenical-and-interfaith-dialogues/orthodox-catholic/filioque-a-church-dividing-issue) supports this sequence.
- The Great Schism node already treats 1054 as a conventional marker, limits the excommunications to the leaders involved, and says the 1965 gesture did not restore full communion. The [1965 joint declaration](https://www.vatican.va/content/paul-vi/en/speeches/1965/documents/hf_p-vi_spe_19651207_common-declaration.html) supports this framing.
- Lateran IV in 1215 correctly covers transubstantiation, annual confession, Easter Communion, and confession's secrecy. [Canons 1 and 21](https://sourcebooks.web.fordham.edu/basis/lateran4.asp) support these claims.
- Lyon II's 1274 profession lists seven sacraments and affirms transubstantiation. Florence's 1439 Armenian decree gives the fuller sacramental account. The [Fordham source](https://sourcebooks.web.fordham.edu/source/1438sacraments.asp) contains both documents. Neither node claims these councils invented the rites.
- Constance in 1414 to 1418 correctly covers the papal settlement, Hus's condemnation and execution in 1415, Wycliffe, and the lay Communion cup. [The council's decrees](https://www.papalencyclicals.net/councils/ecum16.htm) support these claims.
- The Waldensian node distinguishes medieval preaching from later Reformed beliefs. Its broad date in the 1170s is defensible. The [WCC profile](https://www.oikoumene.org/member-churches/waldensian-church) supports its medieval origin, unauthorized preaching, later connections, locations, and broad membership scale.
- The Unity of the Brethren node correctly places its organization at Kunvald in 1457 and its connection to the renewed Moravian church. The [Moravian church's history](https://www.moravian.org/2018/07/a-brief-history-of-the-moravian-church/) supports this account.
- The Catholic population of 1.422 billion for 2024 matches [Vatican News's 2026 report](https://www.vaticannews.va/en/vatican-city/news/2026-03/new-data-from-annuario-pontificio-2026-shows-catholics-growing.html). The Eastern Orthodox estimate already identifies its older data and excludes Oriental Orthodox Christians.
- The relevant `EUCHARIST_OF` assignments are defensible descriptions of the traditions' communion beliefs. The ancient eastern churches affirm Christ's body and blood. Catholic teaching affirms transubstantiation. The Waldensian description identifies its modern Reformed belief.

## For the lead

Three chapter corrections are needed. The proposed text below is report only.

1. `layout.ts`, `CHAPTERS`, "One church", `text`.

   "For three centuries it was one fellowship" overstates early unity. Rival groups and schisms existed before 313, including the Novatian schism in 251. The era data already acknowledges this.

   Suggested replacement: "Jesus' followers carried the faith from Jerusalem across the Roman Empire. Christians gathered around baptism and the Lord's Supper, often under persecution. The shared line simplifies a history that already included rival groups and schisms."

   Source: [Catholic Encyclopedia's historical account of schisms](https://www.newadvent.org/cathen/13529a.htm), including the Novatian split.

2. `layout.ts`, `CHAPTERS`, "The creeds", `text`.

   The sentence about Ephesus sending the Church of the East its own way omits Persian independence in 424. The paragraph also fails to distinguish Nicaea's original creed from the expanded creed associated with Constantinople I. Chalcedon did not produce a complete institutional split overnight.

   Suggested replacement: "Councils defined Christian teaching about Christ and the Trinity. Nicaea met in 325 and Constantinople in 381. Persian churches declared independence in 424. Disputes over Ephesus in 431 and Chalcedon in 451 deepened divisions."

   Sources: [WCC dictionary, Assyrian Church entry, PDF page 94](https://www.oikoumene.org/sites/default/files/2022-11/Dictionary%20of%20the%20Ecumenical%20Movement_Web.pdf#page=94), [joint consultation's creed history](https://www.assemblyofbishops.org/ministries/ecumenical-and-interfaith-dialogues/orthodox-catholic/filioque-a-church-dividing-issue), and [CNEWA's Oriental Orthodox history](https://cnewa.org/eastern-christian-churches/oriental-orthodox-churches/).

3. `layout.ts`, `CHAPTERS`, "East and West", `text`.

   "In 1054 the break became formal" conflicts with the joint consultation's account. "The East became Eastern Orthodox and the West became Catholic" suggests that either church began then. Their separation developed over centuries.

   Suggested replacement: "The Greek East and Latin West drifted apart over language, politics, papal authority, and the Filioque. The excommunications of 1054 mark a gradual separation. Catholic and Eastern Orthodox churches both claim continuity with the apostolic church."

   Source: [Joint Orthodox-Catholic consultation](https://www.assemblyofbishops.org/ministries/ecumenical-and-interfaith-dialogues/orthodox-catholic/filioque-a-church-dividing-issue), especially its historical discussion of 1054 and 1204.

The emblem comments are accurate symbol names. These three optional clarifications would make their provenance clearer without changing the drawings:

4. `emblems.ts`, `apostolic` comment.

   The ichthys is an early Christian symbol, but its association with an AD 30 to 100 node should not imply documented use by Jesus or the apostles. Suggested comment: "Ichthys, an early Christian symbol attested in the second century."

   Source: [Symbolism of the Fish](https://www.newadvent.org/cathen/06083a.htm).

5. `emblems.ts`, `church-of-east` comment.

   The Saint Thomas cross over a lotus belongs to the Indian Syriac heritage shared by several denominations. It is a defensible representative symbol, but does not uniquely identify the Assyrian church. Suggested comment: "Saint Thomas cross over a lotus, from the Indian Syriac heritage."

   Source: [Vanderbilt's Saint Thomas cross description](https://gallery.library.vanderbilt.edu/exhibits/show/syriaca/item/2572).

6. `emblems.ts`, `eastern-orthodox` comment.

   The slanted three-bar design is particularly associated with Russian and Slavic Orthodoxy. The current name is defensible, but regional attribution would be clearer. Suggested comment: "Three-bar cross associated with Russian and Slavic Orthodoxy."

   Source: [OCA's explanation of the Russian Orthodox cross](https://www.oca.org/questions/liturgicarts/the-russian-orthodox-cross).

No correction needed for the `oriental-orthodox` comment naming a Coptic cross. It represents one church within the family. No correction needed for `catholic` and its crossed keys of Peter. The [Holy See's heraldic explanation](https://press.vatican.va/roman_curia/secretariat_state/documents/insigne/sp_ss_scv_stemma-bandiera-sigillo_en.html) supports that identification.

Checked the `overrides.json` patches for `chalcedonian-separation.facts` and `catholic.why`. Both are defensible. The former preserves the gradual separation and later Armenian rejection. The latter rounds the Catholic membership figure to about 1.4 billion and describes the historical line from which Protestant traditions developed. Neither overwrites the Photian correction. The added Eastern Catholic node's pre-1517 Maronite fact also agrees with [CNEWA's 1182 account](https://cnewa.org/eastern-christian-churches/the-catholic-eastern-churches/churches-with-no-orthodox-counterpart/the-maronite-catholic-church/).

## Validation

- Both owned JSON files parse with Python's `json.load`.
- All node IDs match the original files. All text fields meet the brief's word limits and punctuation rules.
- Ran `scripts/merge-data.mjs` with Node. A read-only preload suppressed its three generated-file writes to honor exclusive file ownership. The script completed with 127 nodes from four era files, 12 sacrament rows, and 15 lineage steps. It reported no broken references. No retry was needed.
- Other agents' files and generated `src/data` files were not edited.
