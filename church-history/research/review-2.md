# Review 2

Scope: 1517 through October 2026. Reviewed all 70 nodes in era3.json and era4.json, the Reformation and later lineage sentences, the assigned chapter narration, override patches, Eastern Catholic node, and eight emblem comments.

6 field fixes across 4 nodes. No ids, nodes, dates, or parent relationships changed. The accurate lineage sentences remain unchanged.

## Fixes

1. `baptist.today` in `era3.json`. The BWA publishes a rounded count. "At least" presented that rounded figure as a firm lower bound.
   - Before: "At least 53 million baptized believers in Baptist World Alliance member churches."
   - After: "About 53 million baptized believers in Baptist World Alliance member churches."
   - Source: https://baptistworld.org/. The URL is in the node sources. Existing supporting URLs remain when already present.

2. `old-believers.today` in `era3.json`. The undated estimate looked current. The cited academic entry dates the estimate to 2018 and warns about counting difficulties.
   - Before: "Estimated two million in Russia, eastern Europe, and diaspora communities."
   - After: "About two million worldwide, a 2018 estimate. Current total uncertain."
   - Source: https://www.cdamm.org/articles/old-believers. The URL is in the node sources. Existing supporting URLs remain when already present.

3. `global-methodist.facts` in `era4.json`. The size note supplied no usable count and the history stopped at 2024. The September 2026 church report gives 7,250 congregations and confirms its Johannesburg conference.
   - Before: ["The denomination launched on May 1, 2022.", "Its convening General Conference met in Costa Rica in September 2024. Confidence high.", "Its doctrine retains infant baptism and two sacraments as means of grace.", "Reviewed official sources provide no verified global adherent total. Current-size confidence low."]
   - After: ["The denomination launched on May 1, 2022.", "Its convening General Conference met in Costa Rica in September 2024.", "Its doctrine retains infant baptism and two sacraments as means of grace.", "The church reported 7,250 congregations in September 2026. No global adherent total accompanies that report.", "Its next General Conference met in Johannesburg, South Africa, in 2026."]
   - Source: https://www.globalmethodist.org/global-methodist-church-concludes-historic-2026-general-conference-in-johannesburg. The URL is in the node sources. Existing supporting URLs remain when already present.

4. `global-methodist.today` in `era4.json`. An unverified adherent total concealed an available official congregation count. The replacement identifies the unit and reporting date.
   - Before: "Adherent total unverified. Congregations in Americas, Africa, Europe, and Asia."
   - After: "7,250 congregations reported in September 2026. Global adherent total unverified."
   - Source: https://www.globalmethodist.org/global-methodist-church-concludes-historic-2026-general-conference-in-johannesburg. The URL is in the node sources. Existing supporting URLs remain when already present.

5. `christianity-today.facts` in `era4.json`. The Eastern Orthodox range lacked a directly supporting count. Internal confidence labels also obscured the source definitions. Use the published combined Orthodox figure and identify WCD.
   - Before: ["The Vatican reports 1.422B baptized Catholics for 2024. Confidence is high for its reported count.", "2026 Protestant and independent estimates total 1.06B, including Pentecostal churches. Confidence is medium.", "Eastern Orthodox estimates range between 220M and 260M. Oriental Orthodox estimates approach 60M. Confidence is medium.", "Pentecostal and charismatic counts overlap denominations. These totals use different sources and cannot form a consistent global sum."]
   - After: ["The Vatican reports 1.422B baptized Catholics for 2024.", "WCD estimates 1.06B Protestants and independents in 2026, including Pentecostal churches.", "WCD estimates 293M Orthodox Christians in 2026, combining Eastern and Oriental churches.", "Pentecostal and charismatic counts overlap denominations. These totals use different sources and cannot form a consistent global sum."]
   - Source: https://www.worldchristiandatabase.org/static/downloads/Status-of-Global-Christianity-2026.2b54be19fc0c.pdf. The URL is in the node sources. Existing supporting URLs remain when already present.

6. `christianity-today.disputed` in `era4.json`. Subtracting an undated WCC Oriental Orthodox estimate from WCD created an unsupported Eastern Orthodox figure.
   - Before: "WCD counts 293M Eastern and Oriental Orthodox combined. Subtracting about 60M Oriental Orthodox gives an inferred 233M Eastern Orthodox. Counting methods differ."
   - After: "The Vatican counts baptized Catholics. WCD uses different definitions. Subtracting totals from different sources cannot reliably count Eastern Orthodox."
   - Source: https://www.worldchristiandatabase.org/static/downloads/Status-of-Global-Christianity-2026.2b54be19fc0c.pdf. The URL is in the node sources. Existing supporting URLs remain when already present.

## Checks retained without changes

- Founding dates and leaders remain defensible. Lutheran 1517, Reformed 1519, Anabaptist 1525, Anglican 1534, Baptist 1609, and Methodist 1729 mark movements or ruptures, not identical kinds of incorporation. The nodes explain later confessions and separations. Stone-Campbell 1832 marks the union of older movements. Adventist 1844 marks the broader movement, with SDA organization in 1863. LDS 1830, Russell's movement around 1870, and the Jehovah's Witnesses name in 1931 are distinguished.
- Parent relationships are defensible at this scale. Anabaptist follows Zurich Reformed origins, with other regional origins acknowledged. Baptist records Anglican and English Separatist roots. Methodist follows Anglican. Pentecostal follows Holiness, with Baptist influence. Stone-Campbell records Reformed and Baptist roots. Adventist records Baptist and Methodist influences. LDS parents describe Smith's religious environment, rather than an institutional secession. Jehovah's Witnesses follows broader Adventist influences, rather than descent from SDA.
- The renderer differs from the wording in REVIEW_BRIEF.md. `src/main.ts` follows the first tradition parent recursively until it reaches a visible tradition. Pentecostal therefore already follows Holiness to Methodist in the simple view. Adding a direct Methodist parent would be redundant.
- All Reformation and later "My church" sentences are accurate. Pentecostal's sentence gives the main Wesleyan Holiness ancestry, without claiming one founding split. The Baptist sentence correctly names an English Separatist congregation in 1609. The nondenominational sentence correctly describes several influences.
- Communion categories are defensible broad summaries for Lutheran, Reformed, Anglican, Methodist, Holiness, Moravian, Baptist, Anabaptist, Stone-Campbell, Pentecostal, charismatic, Quaker, Salvation Army, and independent evangelical nodes. The data already notes exceptions, varied Anglican beliefs, Reformed Baptist spiritual feeding, priestless Old Believers, and the different status of Spirit baptism. SDA's symbolic elements fit the memorial category, although its confession also affirms Christ's presence in the gathered Communion experience. Source: https://gc.adventist.org/beliefs/
- Current organization figures checked and retained: LWF over 78M, WCRC about 100M, BWA about 53M, World Methodist Council over 80M, Anabaptist family 2.13M, Anglican about 85M, ACNA over 130,000. These are organization or family estimates, not additive global denominational totals. Sources: https://lutheranworld.org/ , https://wcrc.eu/about/ , https://baptistworld.org/ , https://worldmethodistcouncil.org/about-us/ , https://mwc-cmm.org/en/about-mwc/ , https://anglican.org.au/about-us/anglican-communion/ , https://anglicanchurch.net/welcome/
- Dated organization reports checked and retained: 2025 LDS membership 17,887,212, SBC membership 12,331,954, Nazarene membership 2,764,205, JW peak publishers 9,205,326, Salvation Army senior soldiers 1,260,832, and the 2024 UPCI release's 5.75M constituents. The data distinguishes publishers, registered members, soldiers, and constituents. Sources: https://newsroom.churchofjesuschrist.org/article/2025-statistical-report , https://research.lifeway.com/wp-content/uploads/2026/05/2025_ACP_Summary.pdf , https://nazarene.org/news/general-secretary-releases-2025-statistics/ , https://www.jw.org/en/library/books/2025-Service-Year-Report-of-Jehovahs-Witnesses-Worldwide/2025-Grand-Totals/ , https://www.salvationarmy.org/sites/default/files/2025-12/Annual_Report-2025.pdf , https://upci.org/one-million-constituents/
- The SDA 23.68M figure is explicitly dated 2024 and supported by its cited church news report. A search surfaced a 2025 statistical atlas and an official archives update, but the official current summary returned HTTP 403 and the guessed advance-report path was unavailable. I retained the verified dated figure rather than replacing it with the atlas's unconfirmed figure. Source: https://news.eud.adventist.org/all-news/adventists-grow-worldwide-to-23.6-million-members
- AME and Old Catholic counts already acknowledge limited or undated census evidence. National Baptist, independent evangelical, Holiness, and Stone-Campbell family totals already avoid unsupported precision. Quaker over 400,000 is supported by the Quakers in Britain anniversary report. Source: https://www.quaker.org.uk/communities/news/5-take-aways-from-george-fox-400
- United Methodist facts are accurate. More than 7,600 US churches disaffiliated under the temporary policy, GMC launched on May 1, 2022, and the UMC removed the gay clergy and same-sex wedding bans in 2024. The event's 2019 to 2024 dates cover those decisions, rather than claiming that every later dispute ended. Source: https://www.umnews.org/news/may-1-wrap-up-gay-clergy-ban-lifted-new-retirement-plan-approved
- GAFCON's 2025 and 2026 developments are actual statements, not forecasts. The Abuja document distinguishes its own Communion claims from Canterbury's institutions. The node keeps that attribution and its disputed status. Source: https://gafcon.org/communique-updates/the-abuja-affirmation/
- Moscow's October 15, 2018 communion break and OCU's December 2018 organization and January 2019 tomos are correct. The 35% OCU figure measures survey identification, not enrolled members. Sources: https://old.mospat.ru/en/2018/10/15/news165263/ , https://www.ecupatria.org/2019/01/14/autocephaly-of-the-orthodox-church-in-ukraine/ , https://razumkov.org.ua/en/surveys/religiosity-trust-in-the-church-confessional-division-and-inter-church-relations-in-ukrainian-society-october-2024
- The November 28, 2025 Nicaea commemoration happened. Leo XIV and Bartholomew gathered at Iznik. Retained its completed-event language. Source: https://www.vaticannews.va/en/pope/news/2025-11/pope-leo-xiv-ecumenical-prayer-turkiye-iznik-nicaea.html

## For the lead

1. `src/layout.ts`, CHAPTERS "New branches". "Pentecostals came from a 1906 revival in Los Angeles" makes Azusa Street the sole origin. Replace the last sentence with "Pentecostalism grew from Holiness revivals around 1900 and spread through Los Angeles in 1906." The existing Pentecostal node already records Topeka in 1901. Source: https://ifphc.org/About/AG-History

2. `src/layout.ts`, CHAPTERS "Today". "Just over half are Catholic" mixes the Vatican's baptized count with a different source's Christian total. Within WCD's 2026 definitions, Catholics are about 48% of all Christians. Protestant plus independent is about 40% and combined Orthodox about 11%. More than 2.5B is defensible as a current WCD estimate. Suggested narration: "Researchers estimate about 2.7 billion Christians in 2026. Roughly half are Catholic, two in five Protestant or independent, and one in ten Orthodox." Add a visible source or explanatory note. Do not add Pentecostal and charismatic counts again. Source: https://www.worldchristiandatabase.org/static/downloads/Status-of-Global-Christianity-2026.2b54be19fc0c.pdf

3. `research/overrides.json`, `eastern-catholic.why`. "Latin Mass" confuses a rite with a liturgical language. Use "Latin rite". Suggested why: "Catholic unity allows several Eastern rites. The history of partial unions with Rome remains disputed in Catholic-Orthodox dialogue." Source: https://www.vatican.va/archive/hist_councils/ii_vatican_council/documents/vat-ii_decree_19641121_orientalium-ecclesiarum_en.html

4. `research/overrides.json`, `eastern-catholic.today`. The roughly 18M population claim needs a reporting year or a source that supports a current estimate. The cited Britannica page could not be fetched in this review. The current node's other Eastern Catholic corrections are sound. Source for the church family and differing histories: https://cnewa.org/eastern-christian-churches/the-catholic-eastern-churches/

5. `src/emblems.ts`, `lutheran` comment. The drawing shows the seal's heart, cross, and outer ring but omits the rose. Call it a simplified Luther seal motif rather than the full Luther rose. Source: https://www.lcms.org/resources/post/the-luther-seal-summary-of-the-gospel-coloring-page

6. `src/emblems.ts`, `methodist` comment and file introduction. The Cross and Flame is specifically the United Methodist Church's insignia, introduced in 1968. It is a representative choice for the wider Methodist family. Identify that narrower source rather than implying a universal Methodist emblem. Source: https://www.umc.org/en/content/a-mark-known-the-world-over

7. `src/emblems.ts`, `reformed` and `anabaptist` comments and file introduction. The burning bush is a representative Reformed symbol, especially Presbyterian. The dove is a peace motif used by Mennonite organizations, not one official emblem for all Anabaptists. Suggested introduction: "Representative symbols and motifs used within these traditions." Sources: https://www.churchofscotland.org.uk/news-and-events/news/archive/2024/people-must-allow-themselves-to-be-led-by-the-holy-spirit , https://www.mennoniteusa.org/wp-content/uploads/2020/08/MCUSA20Visual20ID20Manual-1.pdf

No correction needed for "Two thousand years in one picture" or "The Reformation" at the stated map scale. The latter's twenty-year span covers the four named movements. The Anglican compass rose comment is correct. Pentecostal fire, Baptist water, and evangelical open Bible are appropriate representative motifs. Source for the compass rose: https://www.anglicannews.org/news/1997/01/aco-the-anglican-communion.aspx

Rechecked overrides after the simultaneous review. The other reviewer fixed the Eastern Catholic parent list, the Brest date qualification, the Maronite context, the infant initiation qualification, the Balamand balance, and the word limits. Those findings are resolved and do not appear as open lead items. The override patches that detach cross-tradition events from one branch are sound. The Catholic size patch matches the Vatican's current reported baptized count. I leave the Chalcedonian patch's detailed ancient history to the earlier-era reviewer.

## Validation

- era3.json, era4.json, and lineage-steps.json parse as JSON.
- All era3 and era4 fields satisfy the brief's word limits.
- Ran `node scripts/merge-data.mjs` in an isolated copy of the current research files and unchanged script. This checks the full merge without writing the generated src/data files, which belong to the lead. The merge passed with 127 nodes, 12 sacrament rows, 15 steps, and no broken references. The merged output retains both the GMC update and corrected combined Orthodox count.
- No changes to lineage-steps.json were necessary. Only era3.json, era4.json, and this log were edited.
