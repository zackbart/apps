# Pelikan as the basis for a doctrine map

Research proposal only. No implementation changes.

## Recommendation and scope

Build the historical story from dated doctrinal developments. Treat churches, councils, people, and confessions as participants in that story. Keep church ancestry as a separate relation.

This is an inference about product design. Pelikan does not supply a database schema or a fixed list of doctrine threads. He does distinguish the church's doctrine from the private ideas of its theologians. He also distinguishes belief expressed in worship, teaching, and formal confession. Verified in volume 1, introductory "Some Definitions", printed pages 3-4, `Pelikan 1:3-4`.

His treatment of the Trinity expressly follows doctrinal questions, positions, and creedal settlements rather than a strict sequence of events. Verified in volume 1, chapter 4, "The Mystery of the Trinity", printed pages 172-173, `Pelikan 1:172-173`. That gives a sound basis for this change of unit.

Define "Pelikan as basis" before building. I recommend that Pelikan determine the historical questions, the developments chosen to answer them, and the account of those developments. Primary texts can identify documents and check their wording. They should not quietly introduce a second historical narrative.

A literal claim that Pelikan supplies every fact would require a narrower product. He begins his doctrinal investigation with the second century. He explicitly distinguishes the church's understanding of apostolic teaching from a reconstruction of what Jesus and the apostles taught. Verified in volume 1, "Some Definitions", printed page 6, `Pelikan 1:6`. A map starting with Jesus needs a clearly labeled biblical introduction.

The 2026 endpoint also needs a separate extension. Recent events and current teaching cannot be verified from these books. If the extension appears, describe the product as "Doctrinal history based on Pelikan, with current church profiles and later developments." Do not describe the whole timeline as exclusively sourced from Pelikan.

This report does not propose chapters, period boundaries, or a replacement node list. The separate structure review owns those decisions.

## What I verified

I read `research/REVIEW_BRIEF.md` in full. I inspected the schema, merge script, four era files, overrides, sacrament grid, lineage steps, and relevant view code. I consulted the rebase and verification logs for earlier source limits and the final logs for review scope.

I read the Pelikan passages cited below in the local text. I checked printed numbers against running headers and adjacent pages. All citations refer to printed pages. There are no quotations from the books in this report.

"Verified" means the cited passage supports the stated historical claim. It does not mean that Pelikan's account settles a dispute between churches. "Inferred" means an editorial grouping, comparison, relation, estimate, or display choice that I propose. A failed text search is a coverage finding, not proof that a topic never appears under another spelling.

The existing review brief treats Pelikan as a historical baseline but lets current church documents govern present teaching. It also permits historical claims absent from Pelikan. A rebuild needs a stricter distinction between the historical core and those additions. This is a policy proposal, not a claim that the current reviewers broke their rules.

## Proposed doctrine threads

The following thread names and boundaries are inferred. Their source anchors are verified. The ranges identify passages I read, not every page that a full thread would need.

1. **Trinity and the Holy Spirit.** Ask who the Son and Spirit are, how the three relate, and what procession means. Pelikan gives the Trinity its own chapter. He later treats the Filioque within the encounter between East and West. Volume 1, chapter 4, "The Mystery of the Trinity", pages 172-173, `Pelikan 1:172-173`. Volume 2, chapter 4, "The Challenge of the Latin Church", section "The Filioque", page 183, `Pelikan 2:183`.

2. **Christology.** Ask how Christ is divine and human, and how those claims relate to salvation. Pelikan distinguishes the identity of the divine Son from the union of divine and human in the incarnate Christ. Volume 1, chapter 5, "The Person of the God-Man", pages 226-227, `Pelikan 1:226-227`. This thread needs its own questions. It should not become a single tag for whether a church accepts Chalcedon.

3. **Salvation, grace, and human response.** Include sin, freedom, justification, sanctification, and deification as separate questions. Pelikan turns from Trinity and incarnation to human nature, sin, and grace. He treats justification within the Lutheran account of the gospel. He also treats perfection within modern spirituality. Volume 1, chapter 6, "Nature and Grace", pages 278-279, `Pelikan 1:278-279`. Volume 4, chapter 3, "The Gospel as the Treasure of the Church", section "Justification by Faith", pages 138-139, `Pelikan 4:138-139`. Volume 5, chapter 3, "The Theology of the Heart", section "Evangelical Perfection", page 146, `Pelikan 5:146`. Deification belongs here without treating it as another name for Protestant justification. Volume 2, chapter 6, "The Last Flowering of Byzantine Orthodoxy", section "The Definition of Eastern Particularity", page 286, `Pelikan 2:286`.

4. **Eucharist.** Ask about presence, Christ's historical body, reception, consecration, and sacrifice. Pelikan treats early Eucharistic teaching within the means of grace. He treats medieval presence within the communication of grace. He treats Eastern consecration within the later encounter with Western doctrine. Volume 1, chapter 3, "The Faith of the Church Catholic", section "The Church and the Means of Grace", pages 166-168, `Pelikan 1:166-168`. Volume 3, chapter 2, "Beyond the Augustinian Synthesis", section "The Rule of Prayer", pages 74-79, `Pelikan 3:74-79`. Volume 3, chapter 4, "The Communication of Grace", section "The Real Presence", pages 203-204, `Pelikan 3:203-204`. Volume 2, chapter 6, section "The Final Break with Western Doctrine", pages 277-278, `Pelikan 2:277-278`.

5. **Baptism and sacramental life.** Keep individual rites and the definition and number of sacraments separate. Pelikan distinguishes early teaching about particular rites from the later general sacramental system. His medieval account discusses unstable definitions and counts. His Reformation account preserves the ambiguity of confession's technical status in Luther. Volume 1, chapter 3, section "The Church and the Means of Grace", pages 163-166, `Pelikan 1:163-166`. Volume 3, chapter 4, section "The Grace of the Sacraments", pages 206-207 and 209, `Pelikan 3:206-207`, `Pelikan 3:209`. Volume 4, chapter 3, section "The Centrality of the Gospel", pages 179-180, `Pelikan 4:179-180`. Give baptism, confirmation or chrismation, penance, marriage, ministry, and anointing their own question groups.

6. **Church, ministry, and authority.** Ask what constitutes the church, who teaches for it, and how ministry and unity relate. Pelikan treats the church's marks and ministry within Luther's account of the gospel. His modern volume explicitly reviews the uneven history of ecclesiology. Volume 4, chapter 3, section "The Centrality of the Gospel", pages 173-175, `Pelikan 4:173-175`. Volume 5, chapter 6, "The Sobornost of the Body of Christ", section "The Renewal of Ecclesiology", page 288, `Pelikan 5:288`. Institutional descent is related evidence, not the definition of this thread.

7. **Scripture, tradition, and revelation.** Ask what has authority, how Scripture is read, and how churches understand inspiration and doctrinal continuity. Pelikan treats Eastern scriptural authority and interpretation under the norms of traditional doctrine. He later treats inspiration, infallibility, and tradition together. Volume 2, chapter 1, "The Authority of the Fathers", section "The Norms of Traditional Doctrine", pages 16-17, `Pelikan 2:16-17`. Volume 5, chapter 5, "The Definition of Doctrine", sections "Inspiration and Infallibility" and "The Consensus of Christian Tradition", pages 241 and 253, `Pelikan 5:241`, `Pelikan 5:253`.

8. **Worship, images, Mary, and the saints.** Ask how material worship, holy persons, and intercession relate to Christ and salvation. This grouping follows Pelikan's attention to doctrine expressed in worship. It should preserve distinct questions about icons, Mary, and saints. Volume 2, chapter 3, "Images of the Invisible", section "Images as Icons", pages 121-125, `Pelikan 2:121-125`. Volume 3, chapter 4, sections "Mary as Mediatrix" and "The Communion of Saints", pages 160 and 174, `Pelikan 3:160`, `Pelikan 3:174`. Do not reduce this to a Protestant checklist of permitted devotions.

9. **Creation, providence, and final hope.** Ask about creation and redemption, the human place in creation, resurrection, judgment, and the kingdom. Pelikan treats early doctrine in its apocalyptic setting. He later treats creation and the kingdom within the Christian world view. Volume 1, chapter 3, section "The Apocalyptic Vision and Its Transformation", page 123, `Pelikan 1:123`. Volume 5, chapter 4, "Foundations of the Christian World View", sections "Maker of Heaven and Earth" and "The Progress of the Kingdom", pages 190-191 and 215, `Pelikan 5:190-191`, `Pelikan 5:215`. This is a broad navigation group. Split its questions when readers compare positions.

10. **Faith, spiritual experience, and modern knowledge.** Ask how experience, reason, historical inquiry, and modern culture affect doctrinal claims. Pelikan treats modern challenges to inherited authority and the relation of the Holy Spirit to spiritual experience. Volume 5, introductory "Alas, Theology, Too", pages 1 and 8, `Pelikan 5:1`, `Pelikan 5:8`. Volume 5, chapter 3, section "The Experience of the Holy Spirit", pages 162-165, `Pelikan 5:162-165`. This grouping prevents volume 5 from becoming only a list of new denominations. It overlaps with salvation, revelation, and Trinity by design.

Start readers on Eucharist and sacramental life. Offer the other threads when a question needs them. Developments may belong to several threads. None of these ten groups is a mandatory lane or a chapter proposal.

## The data model

Keep four kinds of records separate.

- A community identifies a historical church, communion, movement, or specific church body. It records which kind it is. It does not imply a uniform doctrine.
- A development records a dated teaching, dispute, confession, reception, or revision. It links to its participants and documents. It contains individual sourced claims.
- A position records an answer to a doctrinal question, who held it, and when the evidence supports it. A theologian's answer does not automatically become a church's confession.
- A relation records institutional ancestry, documented doctrinal influence, reception, rejection, or an editorial comparison. Each relation states which kind it is.

The main historical object is the development. Positions let the UI compare doctrines. Relations explain how developments connect. Communities let users enter through "My church".

Use a graph with several possible relations, not a doctrine tree. Two churches can share one doctrinal answer and differ on another. A doctrinal disagreement need not create a new church. An institutional separation need not change every doctrine. These are modeling rules, not new historical claims.

```ts
type Id = string;
type NonEmpty<T> = readonly [T, ...T[]];
type ThreadId =
  | "trinity" | "christology" | "salvation" | "eucharist"
  | "sacramental-life" | "church-authority" | "revelation"
  | "worship-saints" | "creation-hope" | "faith-experience";

interface PelikanRef {
  kind: "pelikan";
  volume: 1 | 2 | 3 | 4 | 5;
  chapter: string;
  section?: string;
  printedFrom: number;
  printedTo: number;
  citation: string; // For example, Pelikan 3:75-76
}

interface OtherRef {
  kind: "primary" | "scholarship" | "statistics" | "announcement";
  title: string;
  url: string;
  locator: string; // Article, paragraph, table, or printed page
  sourceDate?: string;
  checkedAt: string;
}

type Fact<T> =
  | { value: T; basis: "pelikan"; review: "text-verified";
      refs: NonEmpty<PelikanRef> }
  | { value: T; basis: "supplement"; review: "source-verified";
      refs: NonEmpty<OtherRef> };

interface Inference<T> {
  value: T;
  review: "inferred";
  reason: string;
  basedOnClaimIds: NonEmpty<Id>;
}

interface DatePlacement {
  described: Fact<string>;
  plot: readonly [number, number];
  precision: "year" | "approximate" | "century";
  plotBasis: "source-year" | "editorial-window";
}

interface DoctrineThread {
  id: ThreadId;
  title: string; // Editorial navigation label
  questionIds: Id[];
  grounding: NonEmpty<PelikanRef>;
}

interface DoctrineQuestion {
  id: Id;
  threadIds: NonEmpty<ThreadId>;
  prompt: string; // Editorial question
  facets: { id: Id; label: string }[]; // May overlap
}

interface Entity {
  id: Id;
  kind: "community" | "council" | "person" | "document" | "event";
  name: Fact<string>;
  communityKind?: "communion" | "movement" | "church-body";
  legacyNodeId?: Id;
}

interface Claim {
  id: Id;
  assertion: Fact<string>;
  scope: "development" | "wider-context";
}

interface Development {
  id: Id;
  title: string;
  layer: "pelikan-core" | "biblical-introduction" | "extension";
  when: DatePlacement;
  threads: NonEmpty<ThreadId>;
  kind: "teaching" | "dispute" | "confession" | "reception" | "revision";
  entityIds: Id[]; // Each link must identify its supporting claim
  claims: NonEmpty<Claim>;
  links: { entityId: Id; claimIds: NonEmpty<Id> }[];
}

interface Position {
  id: Id;
  questionId: Id;
  answer: Fact<string>;
  facetIds: Inference<Id[]>; // Reviewed display tags, not parsed prose
  holderId: Id;
  voice: "individual" | "worship" | "teaching" | "confession";
  adoption?: Fact<string>; // Needed to claim church reception
  attestedWhen: DatePlacement;
  developmentIds: NonEmpty<Id>;
  validity: "dated-attestation" | "documented-interval";
}

type Relation =
  | { id: Id; from: Id; to: Id;
      kind: "institutional-descent" | "influences" | "receives" | "rejects";
      claim: Fact<string> }
  | { id: Id; from: Id; to: Id;
      kind: "compare" | "context";
      claim: Inference<string> };

interface Difference {
  questionId: Id;
  positionIds: NonEmpty<Id>;
  relation: "different" | "compatible" | "contested" | "unknown";
  explanation: Fact<string> | Inference<string>;
}

interface RiteProfile {
  communityId: Id;
  riteId: Id;
  asOf: string;
  counted: Fact<"yes" | "no" | "varies">;
  term: Fact<string>; // Preserve the church's own term
  practice: Fact<"observed" | "not-observed" | "varies">;
  note: Fact<string>;
  positionIds: Id[];
  historicalDevelopmentIds: Id[];
}
```

The sketch omits draft records. Keep them in the research workspace. Publish only reviewed facts and clearly marked inferences. An unresolved claim needs an explicit research status and no projected doctrinal value.

The same claim can have several references. Do not cap citations per whole node. Instead, cap a claim's references at the best evidence needed to support it. Keep section locators for primary texts. Continue rendering Pelikan citations in the existing `Pelikan volume:pages` form.

Do not store PDF page numbers in public citations. A private evidence index can map printed pages to local text segments. Never copy book text into generated JSON to prove a citation. Store a paraphrase, its exact locator, and review status.

Do not equate `dated-attestation` with an interval that continues to 2026. Do not extend a position backward to a community's founding date. Do not fill gaps from its institutional parent. A missing answer is unknown.

For Eucharist comparisons, define separate question IDs for presence, relation to Christ's historical body, the elements, consecration, reception, sacrifice, and participation. These are inferred question labels. The examples below verify why several are needed. Assign display facets by review. Do not generate doctrinal classifications by searching prose for words such as "symbol" or "spiritual". Allow overlapping facets and preserve the sourced answer beside them.

## Nine worked development records

These records demonstrate research content for the proposed model. Each historical assertion and source-described date has its own citation. The title, thread assignment, and proposed entity IDs are editorial choices. They are not replacements for the other agent's node list.

A century window is a display interval, not an asserted publication date. The two Carolingian records overlap deliberately. All proposed position records would cite the claim that supplies their answer and distinguish personal teaching from church confession.

### 1. Early Eucharistic confession

```ts
{
  id: "eucharist-early-confession",
  layer: "pelikan-core",
  kind: "teaching",
  threads: ["eucharist", "christology", "creation-hope"],
  title: "The early church's Eucharistic confession",
  when: {
    described: "Second and third centuries",
    cite: "Pelikan 1:166-167",
    plot: [100, 299], precision: "century",
    plotBasis: "editorial-window"
  },
  entities: ["irenaeus", "ignatius", "justin", "early-church"],
  claims: [
    { id: "early-presence",
      text: "Pelikan describes real presence in early teaching without a later precise account of substantial change.",
      cites: ["Pelikan 1:166-168"] },
    { id: "irenaeus-creation",
      text: "Irenaeus uses the Eucharist to oppose the rejection of material creation and to affirm bodily resurrection.",
      cites: ["Pelikan 1:167"] },
    { id: "early-incarnation",
      text: "Justin links remembrance to incarnation and suffering. Ignatius links Eucharistic flesh to Christ's suffering against docetism.",
      cites: ["Pelikan 1:167-168"] }
  ]
}
```

Verified locator: volume 1, chapter 3, "The Faith of the Church Catholic", section "The Church and the Means of Grace", pages 166-168.

Inferred use: leave the later question of transubstantiation unclassified here. Pelikan warns against assigning second- and third-century fathers positions in much later controversies, `Pelikan 1:167`. The historical claim is verified. The display rule is inferred.

### 2. Paschasius Radbertus on presence and identity

```ts
{
  id: "eucharist-radbertus",
  layer: "pelikan-core", kind: "teaching",
  threads: ["eucharist", "christology"],
  title: "Paschasius Radbertus on Christ's Eucharistic body",
  when: {
    described: "The ninth-century Eucharistic controversy",
    cites: ["Pelikan 3:184-185"],
    plot: [800, 899], precision: "century",
    plotBasis: "editorial-window"
  },
  entities: ["paschasius-radbertus"],
  claims: [
    { id: "radbertus-identity",
      text: "Radbertus identifies the Eucharistic body with the body born of Mary, crucified, and raised.",
      cites: ["Pelikan 3:75"] },
    { id: "radbertus-elements",
      text: "Radbertus says the appearance remains bread and wine while the reality is Christ's body and blood.",
      cites: ["Pelikan 3:76"] },
    { id: "radbertus-reception",
      text: "Radbertus holds that an unworthy recipient still receives the true body and blood.",
      cites: ["Pelikan 3:76"] }
  ]
}
```

Verified locators: volume 3, chapter 2, "Beyond the Augustinian Synthesis", section "The Rule of Prayer", pages 75-76. The dating context is chapter 4, "The Communication of Grace", section "The Real Presence", pages 184-185.

Inferred use: create a personal teaching position. Do not mark every ninth-century Western community as holding it. Do not assign the later formal label "transubstantiation" to this record.

### 3. Ratramnus on figure and sacramental reception

```ts
{
  id: "eucharist-ratramnus",
  layer: "pelikan-core", kind: "dispute",
  threads: ["eucharist"],
  title: "Ratramnus distinguishes sacramental and historical body",
  when: {
    described: "The ninth-century Eucharistic controversy",
    cites: ["Pelikan 3:184-186"],
    plot: [800, 899], precision: "century",
    plotBasis: "editorial-window"
  },
  entities: ["ratramnus", "paschasius-radbertus"],
  claims: [
    { id: "ratramnus-shared-confession",
      text: "Ratramnus and his opponents both confess Christ's body and blood. They differ over figure and reality.",
      cites: ["Pelikan 3:74-75"] },
    { id: "ratramnus-elements",
      text: "Ratramnus says bread and wine remain in outward appearance but become Christ's body and blood in divine power.",
      cites: ["Pelikan 3:76-77"] },
    { id: "ratramnus-identity",
      text: "Ratramnus distinguishes the sacramental body from Christ's historical body while affirming that faithful recipients receive body and blood.",
      cites: ["Pelikan 3:77"] }
  ]
}
```

Verified locators: volume 3, chapter 2, section "The Rule of Prayer", pages 74-77. Dating context: chapter 4, section "The Real Presence", pages 184-186.

Inferred use: compare this with Radbertus by question. A single "real" versus "symbolic" switch would hide their shared confession and their different uses of those terms. Do not make Ratramnus the founder of a denominational branch.

### 4. Lateran IV defines transubstantiation

```ts
{
  id: "eucharist-lateran-iv",
  layer: "pelikan-core", kind: "confession",
  threads: ["eucharist", "church-authority"],
  title: "Lateran IV defines the Eucharistic change",
  when: {
    described: "1215", cites: ["Pelikan 3:203"],
    plot: [1215, 1215], precision: "year", plotBasis: "source-year"
  },
  entities: ["lateran-iv", "lateran-iv-constitution-1"],
  claims: [
    { id: "lateran-change",
      text: "Lateran IV confesses Christ's body and blood under the appearances of bread and wine and describes the change as transubstantiation.",
      cites: ["Pelikan 3:203-204"] },
    { id: "lateran-content",
      text: "Pelikan distinguishes the dogma's affirmation of real presence from a particular philosophical definition of substance and accidents.",
      cites: ["Pelikan 3:204"] }
  ]
}
```

Verified locator: volume 3, chapter 4, "The Communication of Grace", section "The Real Presence", pages 203-204. Constitution 1 appears in the source annotation on page 204.

Inferred use: link the council and its document to the definition. Keep any claimed doctrinal influence from Radbertus as a separate relation requiring its own evidence.

### 5. Eastern and Western consecration at Florence

```ts
{
  id: "eucharist-florence-consecration",
  layer: "pelikan-core", kind: "dispute",
  threads: ["eucharist", "trinity", "worship-saints"],
  title: "Consecration and the invocation of the Holy Spirit",
  when: {
    described: "Florence, 1439", cites: ["Pelikan 2:277-278"],
    plot: [1439, 1439], precision: "year", plotBasis: "source-year"
  },
  entities: ["florence", "mark-of-ephesus", "florence-decree-armenians"],
  claims: [
    { id: "florence-western-formula",
      text: "Florence attributes conversion of the elements to the power of Christ's words.",
      cites: ["Pelikan 2:278"] },
    { id: "eastern-epiclesis",
      text: "Pelikan contrasts Latin emphasis on the words of institution with Greek emphasis on invoking the Holy Spirit.",
      cites: ["Pelikan 2:277-278"] },
    { id: "mark-spirit",
      text: "Mark of Ephesus attributes the change of the elements to the coming of the Holy Spirit.",
      cites: ["Pelikan 2:278"] }
  ]
}
```

Verified locator: volume 2, chapter 6, "The Last Flowering of Byzantine Orthodoxy", section "The Final Break with Western Doctrine", pages 277-278. The Decree for the Armenians appears in the source annotation on page 278.

Inferred use: mark the broad Greek and Latin descriptions as wider context. The year anchors the conciliar comparison, not the origin of the epiclesis. Compare consecration separately from presence.

### 6. Marburg and a doctrinal boundary within Protestant agreement

```ts
{
  id: "eucharist-marburg-context",
  layer: "pelikan-core", kind: "dispute",
  threads: ["eucharist", "salvation", "revelation"],
  title: "Marburg within the Protestant Eucharistic dispute",
  when: {
    described: "Marburg Colloquy, 1529", cites: ["Pelikan 4:151"],
    plot: [1529, 1529], precision: "year", plotBasis: "source-year"
  },
  entities: ["marburg-colloquy", "marburg-articles", "luther", "zwingli"],
  claims: [
    { id: "marburg-agreement", scope: "development",
      text: "Pelikan reports consensus on most major doctrines, especially justification, in the Marburg articles.",
      cites: ["Pelikan 4:151"] },
    { id: "luther-sacramental-boundary", scope: "wider-context",
      text: "Luther treats sacramental error as a reason to avoid the teacher and defends the real presence of body and blood in bread and wine.",
      cites: ["Pelikan 4:178", "Pelikan 4:181"] },
    { id: "zwingli-reception", scope: "wider-context",
      text: "Zwingli interprets receiving bread and wine as a public confession of belief in Christ.",
      cites: ["Pelikan 4:197"] }
  ]
}
```

Verified locators: volume 4, chapter 3, "The Gospel as the Treasure of the Church", sections "Justification by Faith", page 151, and "The Centrality of the Gospel", pages 178 and 181. Zwingli's account appears in chapter 4, "The Word and the Will of God", section "Word and Spirit", page 197.

Inferred use: connect Marburg to the wider Eucharistic disagreement. These pages support the meeting's year and shared doctrines directly. They do not give a complete account of its negotiations or explicitly narrate the failed union in the passages read. Do not publish that causal account as text-verified from these citations. The earlier verification logs make the same distinction between direct support and a broader inference. Philip's invitation and the October date are outside this example.

### 7. Trent reaffirms transubstantiation

```ts
{
  id: "eucharist-trent-presence",
  layer: "pelikan-core", kind: "confession",
  threads: ["eucharist", "church-authority"],
  title: "Trent reaffirms the Eucharistic change",
  when: {
    described: "11 October 1551", cites: ["Pelikan 4:299"],
    plot: [1551, 1551], precision: "year", plotBasis: "source-year"
  },
  entities: ["council-of-trent", "trent-session-13"],
  claims: [
    { id: "trent-change",
      text: "Trent affirms the change of the entire substance of bread and wine into Christ's body and blood and retains the term transubstantiation.",
      cites: ["Pelikan 4:299"] },
    { id: "trent-deliberation",
      text: "Pelikan records disagreement within the council about the antiquity and force of the term before the final wording.",
      cites: ["Pelikan 4:298-299"] }
  ]
}
```

Verified locator: volume 4, chapter 5, "The Definition of Roman Catholic Particularity", section "Reaffirmation of Church and Dogma", pages 298-299. Session 13 appears in the source annotation on page 299.

Inferred use: show the formal confession and its debate separately. This record is about presence. Do not attach the council's later definition of sacrifice to the 1551 date. Pelikan distinguishes the two stages, `Pelikan 4:299-300`.

### 8. Reformed spiritual reception in the Second Helvetic Confession

```ts
{
  id: "eucharist-second-helvetic",
  layer: "pelikan-core", kind: "confession",
  threads: ["eucharist", "trinity", "revelation"],
  title: "Christ's body and blood communicated through the Spirit",
  when: {
    described: "Second Helvetic Confession, 1566",
    cites: ["Pelikan 4:197"],
    plot: [1566, 1566], precision: "year", plotBasis: "source-year"
  },
  entities: ["second-helvetic-confession", "bullinger"],
  claims: [
    { id: "helvetic-spiritual-reception",
      text: "The confession describes Christ's body and blood as communicated spiritually through the Holy Spirit, who confers forgiveness and eternal life.",
      cites: ["Pelikan 4:203"] },
    { id: "helvetic-eating-beyond-rite",
      text: "The confession also speaks of spiritual eating and drinking wherever someone believes in Christ, apart from the Supper.",
      cites: ["Pelikan 4:197"] }
  ]
}
```

Verified locator: volume 4, chapter 4, "The Word and the Will of God", section "Word and Spirit", pages 197 and 202 to the opening of 203. The source annotation identifies chapter 21 of the confession.

Inferred use: give "spiritual" an affirmative answer about reception. Do not interpret it as "Christ is absent". Do not merge all Reformed formulations into Zwingli's account. Pelikan reports Calvin's criticism of Zwingli's treatment of signs and reality, `Pelikan 4:186`.

### 9. Jerusalem and seventeenth-century Eastern confessions

```ts
{
  id: "eucharist-eastern-confessional-definition",
  layer: "pelikan-core", kind: "confession",
  threads: ["eucharist", "sacramental-life", "church-authority"],
  title: "Eastern confessions define presence while reserving its manner",
  when: {
    described: "Synod of Jerusalem, 1672", cites: ["Pelikan 2:286"],
    plot: [1672, 1672], precision: "year", plotBasis: "source-year"
  },
  entities: ["jerusalem-1672", "confession-dositheus",
    "confession-peter-mogila", "metrophanes-critopoulos"],
  claims: [
    { id: "eastern-confessional-status", scope: "development",
      text: "Pelikan identifies official sanction for the Jerusalem synod and normative status for the confessions of Mogila and Dositheus.",
      cites: ["Pelikan 2:286"] },
    { id: "eastern-seven", scope: "wider-context",
      text: "Seventeenth-century Eastern confessions adopt the technical enumeration of seven sacraments.",
      cites: ["Pelikan 2:291"] },
    { id: "eastern-transubstantiation", scope: "wider-context",
      text: "Pelikan describes transubstantiation becoming a technical term in Eastern theology. Dositheus says the manner of change exceeds human perception.",
      cites: ["Pelikan 2:292"] },
    { id: "critopoulos-status", scope: "wider-context",
      text: "Pelikan distinguishes Critopoulos's private confession from documents with official or normative standing.",
      cites: ["Pelikan 2:286"] }
  ]
}
```

Verified locator: volume 2, chapter 6, "The Last Flowering of Byzantine Orthodoxy", section "The Definition of Eastern Particularity", pages 286 and 291-292. The annotation on page 292 identifies article 17 of Dositheus's confession.

Inferred use: Jerusalem supplies the dated anchor for a wider confessional comparison. Do not assign every sentence to that synod or every position to all Eastern churches. Keep the private confession distinct. Presence, terminology, and reserve about explanation are separate questions. "Mystery" and "transubstantiation" need not be mutually exclusive display categories.

### How to turn these examples into typed records

The example blocks use short citation strings so a researcher can read them. They are record sketches, not compilable instances of the TypeScript interfaces. On entry, expand each citation into `PelikanRef` with the verified chapter and section given below its block. Expand each assertion into a `Fact<string>` and `Claim`. Default scope to `development` except where the notes explicitly require `wider-context`.

Each participant link must name the claim that supports its involvement. Each new entity's name needs a sourced record. Add positions by extracting only the relevant answer from a claim. An attestation date must fit that answer's evidence. Do not date every contextual statement to the record's plotted year. If the text supplies only a century, use a century placement for that position.

A concrete comparison joins `radbertus-identity` and `ratramnus-identity` on the question "How does the Eucharistic body relate to Christ's historical body?" Their differing answers are verified in `Pelikan 3:75-77`. The comparison relation and its question label are inferred. It creates no institutional split.

## How the views use the model

### Sacraments grid

Keep the familiar 12 by 7 opening view. Treat it as a projection of dated rite profiles, not as the historical database.

Separate three things in each cell. Does the body count the action among its sacraments? What term does it use? Does it practice the action? Add a short sourced account of grace or meaning. A rite outside a counted list can still have a theological role. An unknown answer must remain unknown rather than becoming "none".

A click should open the current profile and its historical developments. A date selector should show only positions attested for that period. Disable a historical cell when the evidence is insufficient. Never project a modern row back to the early church.

Pelikan's treatment of changing sacramental definitions and counts supports this separation. Verified in volume 3, chapter 4, section "The Grace of the Sacraments", pages 206-207 and 209, `Pelikan 3:206-207`, `Pelikan 3:209`. His account of Luther's confession and absolution also distinguishes technical classification from grace. Verified in volume 4, chapter 3, section "The Centrality of the Gospel", pages 179-180, `Pelikan 4:179-180`.

The seven columns are an editorial comparison set. Allow other rite IDs in the data. Do not claim those seven exhaust every community's sacramental vocabulary. The existing Church of the East row and its prior reviews already identify a mismatch between the displayed columns and its counted list. That current claim needs its own official sources in the extension. I have not reverified those documents for this proposal.

### "My church" lineage

Keep an institutional path and add a doctrinal path. Name them clearly. The first shows documented ancestry. The second shows developments received, rejected, revised, or debated in that church's evidence.

Replace selection of the first matching `parents` entry with an explicit path relation. Multiple origins or influences can remain visible. A user may select a specific body within a broad family. Do not let an arbitrary parent order decide its doctrine.

A doctrinal path can show shared earlier history without claiming exclusive possession of it. Require evidence before marking a later church as receiving a particular earlier formulation. Institutional ancestry alone is insufficient.

Keep the current 15 step strings only as draft summaries. Move their sources from one global list to each claim. Mark an institutional claim outside Pelikan as an extension. Rewrite the summaries after the development records exist. Do not use the current path as the outline for researching the book.

### Communion-view recolor

Resolve color from the selected question, body, and date. Stop inheriting communion color from the first parent. Remove the default assignment to "memorial" when research is missing.

Use one question per color key. "How is presence described?" can be the opening key. Offer a second key for consecration or sacrifice. Show terminology and qualifications in the detail panel. Use a neutral unknown color. Use stripes or a "varies" marker when documented positions coexist within the selected family.

The current category set mixes presence, mechanism, reserve about explanation, variation, and absence of an outward rite. The nine examples show why those need distinct fields. The earlier Eastern record compares consecration. The later Eastern record compares technical terminology and the limits of explanation. Neither needs a mutually exclusive "mystery" versus "transubstantiation" choice.

### Compare two churches

Choose two specific bodies and a date. Show shared institutional history where the ancestry evidence supports it. Then show doctrinal questions side by side, grouped by thread.

Do not promise a single point where all shared doctrine ends. Record institutional separation and doctrinal divergence separately. A shared confession may continue after separation. A doctrinal disagreement may precede it. Those are rules for how the comparison works, not assumptions about a particular pair.

For each question, show shared attested teaching, different answers, contested comparison, or insufficient evidence. The user should see the source dates and whether the explanation is verified or inferred. A church's self-description and another church's criticism belong in separate attributed claims.

The Marburg example illustrates the need. Pelikan records substantial agreement on doctrine, especially justification, in 1529, `Pelikan 4:151`. His wider account documents Eucharistic disagreement, `Pelikan 4:178`, `Pelikan 4:181`, `Pelikan 4:197`. The inferred product comparison can show both without drawing a new denomination from an existing line.

## Migration estimate

These are workspace counts, not historical claims. I reproduced the merge's duplicate and override handling in memory. I did not run the writing merge command.

- The merged set has 127 nodes. It contains 36 traditions, 55 events, 17 councils, 7 figures, and 12 schisms.
- 85 nodes have at least one Pelikan citation. The other 42 do not. A citation on a node does not establish support for all its fields.
- 86 nodes begin before 1700. Of those, 73 have a Pelikan citation. Of the 41 beginning in 1700 or later, 12 have one.
- The grid has 12 rows and 84 cells. The lineage has 15 steps. `EUCHARIST_OF` has 29 explicit assignments, with additional inherited assignments at runtime.

The following estimates are inferred planning ranges. They do not preapprove any existing claim.

**Keep identifiers and presentation code.** Keep all 127 legacy IDs as cross-reference keys. Reuse the 36 tradition identities as candidate community records after checking scope. Reuse council, figure, event, and schism identities where needed. Keep the Three.js renderer, camera controls, selection behavior, and much of the existing detail-panel code. Replace their data resolvers. Display decisions about chapters and node selection remain with the separate structure review.

**Keep researched content selectively.** Start with the 85 cited nodes. I estimate that 65 to 80 can supply at least one useful Pelikan-core claim after a field-level audit. This means reuse of a claim or an entity, not retention of its whole narration or its branch position. Treat the estimate as a research queue size. The nine examples are a pilot, not a sample broad enough to certify that range.

**Re-research every doctrinal summary and historical edge.** Audit all 127 nodes at claim level. Existing `parents`, `on`, and `splits` do not distinguish ancestry, influence, failed union, and presentation placement. None should migrate automatically. Turn useful text into dated claims, positions, and typed relations. Narrow citations to supporting passages. Review disagreements and attribution again.

**Rebuild all projections.** Review all 84 sacrament cells for body scope, source date, counted status, practice, and doctrine. Rebuild all 15 lineage summaries from sourced paths. Replace all 29 explicit communion assignments and their inherited results with dated positions. Preserve good wording only after the new record supports it.

**Research new doctrinal material from the book.** The present node inventory cannot supply the new model by conversion alone. The worked examples already require developments and documents that are not separate current nodes. Budget an initial core of roughly 80 to 120 development records across the ten proposed threads, with several claims per record. This is an estimate of research scale, not a proposed node list. The structure reviewer should help set the final count.

**Plan effort after a pilot.** Allow roughly 4 to 6 weeks for one researcher to read, extract, and review that initial core. Allow another 1 to 2 weeks for schema, adapters, and view integration after the pilot stabilizes the model. These estimates assume reuse of the renderer and do not include a full audit of every current church profile. Measure actual time on Eucharist and sacramental life before committing to a schedule.

## What stays outside the Pelikan core

Do not treat 1700 as a coverage cutoff. Volume 5 addresses modern doctrine. Its treatment of Wesley and spiritual experience is visible in pages 146 and 162-165. Its treatment of Alexander Campbell and infallibility is visible on page 241. Its treatment of modern ecclesiology and Vatican II is visible on pages 288 and 325. Verified in volume 5, chapters 3, 5, and 6, `Pelikan 5:146`, `Pelikan 5:162-165`, `Pelikan 5:241`, `Pelikan 5:288`, `Pelikan 5:325`.

At the same time, doctrinal discussion does not establish a denomination's founding year, institutional parent, or present sacramental practice. Those claims need separate evidence.

I searched all five text files for Pentecostal, Azusa, Parham, Seymour, Assemblies of God, Southern Baptist, Jehovah, Mormon, and Methodist. Those exact terms returned no hits. Wesley and Campbell did return hits, including the passages above. This is a limited search finding. OCR and alternate names prevent an absolute claim of absence. The earlier verification logs also record missing support for modern independent churches, Pentecostal specifics, Methodist sacramental specifics, and several Eastern union and rite claims.

Use the following coverage states during migration.

- **Covered by Pelikan.** The actual claim has a supporting passage. It can enter the core.
- **Partly covered.** A general doctrinal point is supported, but the date, body scope, or causal relation is not. Split the claim. Put only the supported portion in the core.
- **Not located after a documented search.** Keep the search terms and volume or index checks. Do not call a related discussion direct support.
- **Outside the book's scope or date.** Current membership totals, recent events, and current policy belong in the extension. A citation to the book's account of an earlier dispute cannot support them.

For claims needing other sources, use these rules.

1. Source present teaching from that body's official confession, catechism, church order, or approved statement. Store its date and paragraph or article. A family name is not enough to identify the speaker.
2. Source denominational origins and institutional ancestry from a scholarly history, with official histories as supporting evidence. Do not borrow a generic doctrinal passage for a specific foundation date.
3. Source membership from a dated statistical report. Record year, geography, unit, and method. Do not mix adherents, baptized members, attendees, and congregations into one number.
4. Source recent changes from official decisions or announcements, with independent reporting where useful. Keep event dates distinct from publication dates.
5. Tie an extension to a core development only when the connection has evidence. An editorial "related question" link must say it is inferred. Allow a profile to have no established historical link.
6. Put extensions behind a visible label and an optional filter. They may answer current questions, but they must not determine the selection or explanation of core developments.

Existing official-source URLs are useful candidates. This proposal does not certify their accessibility or current content. Recheck them when creating extension claims. Damick may supply an attributed comparative reading in the extension. He should not determine the historical core in a rebuild based entirely on Pelikan.

If newer scholarship changes a historical point, log the disagreement and display the correction as such. Do not quietly replace Pelikan's narrative and still claim exclusive dependence on him. If frequent corrections become necessary, change the product's source description.

## Migration sequence and completion checks

1. Freeze a read-only snapshot of the existing research and generated data. Preserve IDs and source strings for traceability.
2. Build the Eucharist and sacramental-life pilot from Pelikan, using the examples above. Add documents, positions, claim-level evidence, and uncertainty. Review those records before expanding the scope.
3. Agree with the structure reviewer on how developments attach to the proposed chapters and visible anchors. Keep thread questions separate from chapter order.
4. Audit the 85 cited nodes first. Split multi-claim text and classify each supported fact. Audit the 42 uncited nodes as potential context or extension records. Search before deciding coverage.
5. Add the remaining thread records from the books. Do not use the old denominational graph as the extraction checklist.
6. Build adapters that generate the current node cards, grid, path, and color inputs from the new records. Replace parent inheritance and global source lists. Keep old IDs only for references and navigation.
7. Add dated church profiles and later events as an optional extension. Make provenance visible in both timelines and comparisons.
8. Validate referenced IDs, source types, printed page ranges, claim support, date precision, and profile scope. A core historical fact must have a verified Pelikan reference. A supplemental fact must never appear as Pelikan-verified.
9. Review sample paths and church comparisons for neutrality. Check that missing research stays unknown, that individual teaching does not become collective doctrine, and that a shared earlier record does not imply identical later interpretations.

The decisive test is practical. A reader should be able to select the Eucharist and follow its questions and formulations without first choosing a denomination. A denomination should then show where its dated evidence joins that history.
