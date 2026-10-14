# Sacraments review

Reviewed all 84 statuses and cell notes, all 12 row summaries, all seven rite definitions, the Eastern Catholic node, and every override patch. Made 25 corrections. Source additions do not count as separate corrections.

## Corrections

### 1. rites.baptism.what

Calling baptism only a marker understates traditions that teach new birth through baptism.

Before: Washing with water to mark entry into Christian life and the church.

After: Washing with water as Christian initiation. Churches differ over how baptism gives or signifies new life.

Sources: [Source 1](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_one/article_1/iii_how_is_the_sacrament_of_baptism_celebrated.index.html), [Source 2](https://bfm.sbc.net/bfm2000/).

### 2. rites.communion.what

The general definition gave remembrance alone and left out resurrection and differences over presence.

Before: Sharing bread and wine, or grape juice, in remembrance of Jesus' death.

After: Sharing bread and wine, or grape juice, to celebrate Christ's death and resurrection. Churches differ over his presence.

Sources: [Source 1](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_one/article_3/v_the_sacramental_sacrifice_thanksgiving_memorial_presence.index.html), [Source 2](https://www.umc.org/-/media/umc-media/2013/12/19/01/24/this-holy-mystery-communion.pdf).

### 3. rites.confirmation.what

Affirming baptism does not describe infant chrismation or its teaching about the gift of the Spirit.

Before: Prayer, laying on hands, or anointing to affirm baptism and invoke the Holy Spirit.

After: Prayer, laying on hands, or anointing linked to baptism and the gift of the Holy Spirit.

Sources: [Source 1](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_one/article_2/iii_the_effects_of_confirmation.index.html), [Source 2](https://www.oca.org/orthodoxy/the-orthodox-faith/worship/the-sacraments/chrismation).

### 4. rites.marriage.what

Marriage vows are not part of every tradition's rite. Orthodox crowning does not require an exchange of vows.

Before: A church celebration of marriage vows, with prayer and blessing.

After: A church celebration of marriage, with prayer and blessing. Some traditions include vows or crowning.

Sources: [Source 1](https://www.oca.org/orthodoxy/the-orthodox-faith/worship/the-sacraments/marriage), [Source 2](https://ecphilippines.org/catechism/).

### 5. church-of-east.summary

The tradition has more than one historic list of seven. Name the list represented by the grid.

Before: Holy mysteries convey grace. Their traditional seven include baptismal oil, holy leaven, and the sign of the cross.

After: Holy mysteries convey grace. Abdisho's traditional seven include baptismal oil, holy leaven, and the sign of the cross.

Sources: [Source 1](https://news.assyrianchurch.org/wp-content/uploads/2017/11/Common-Statement-on-Sacramental-Life-FINAL-VERSION-18-NOV.pdf), [Source 2](https://www.assyrianchurch.org/sacraments/).

### 6. church-of-east.marriage

The claim that traditional lists omit marriage was too broad. Timothy II included marriage.

Before: {"status": "rite", "note": "Priests bless marriages. Traditional lists omit marriage, though modern dialogue affirms its sacramental character."}

After: {"status": "rite", "note": "Priests bless marriages. Abdisho's seven omit marriage, though modern dialogue affirms its sacramental character."}

Sources: [Source 1](https://news.assyrianchurch.org/wp-content/uploads/2017/11/Common-Statement-on-Sacramental-Life-FINAL-VERSION-18-NOV.pdf).

### 7. church-of-east.anointing

The note generalized from one list. Identify Abdisho's list and preserve the distinction from its sacramental character.

Before: {"status": "rite", "note": "Priests anoint the sick. Traditional lists omit this rite, though dialogue affirms its sacramental character."}

After: {"status": "rite", "note": "Priests anoint the sick. Abdisho's seven omit it, though dialogue affirms its sacramental character."}

Sources: [Source 1](https://news.assyrianchurch.org/wp-content/uploads/2017/11/Common-Statement-on-Sacramental-Life-FINAL-VERSION-18-NOV.pdf).

### 8. lutheran.confession

The Apology counts absolution, while the ELCA explicitly counts two sacraments. A single counted-sacrament status hid that difference.

Before: {"status": "sacrament", "note": "Retains private confession and absolution. The Apology explicitly calls absolution a sacrament."}

After: {"status": "varies", "note": "Retains confession and absolution. The Apology calls absolution a sacrament, but many churches count two."}

Sources: [Source 1](https://bookofconcord.org/defense/of-the-number-and-use-of-sacraments/), [Source 2](https://download.elca.org/ELCA%20Resource%20Repository/What_is_a_sacrament_for_Lutherans.pdf).

### 9. anabaptist.summary

The summary described human commitment alone. Mennonite confessions also describe God's action and continuing grace.

Before: Baptism and communion express faith, obedience, and shared discipleship. Some communities also observe foot washing and other ordinances.

After: Baptism and communion are usually signs or ordinances of God's work and believers' commitment. Some communities observe foot washing, anointing, and other ordinances.

Sources: [Source 1](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/baptism/), [Source 2](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/the-lords-supper/), [Source 3](https://www.brethren.org/about/practices/).

### 10. anabaptist.communion

The note omitted the risen Christ's presence described in Mennonite Confession Article 12.

Before: {"status": "ordinance", "note": "Shares bread and wine or juice to remember Christ and renew believers' covenant together."}

After: {"status": "ordinance", "note": "Shares bread and wine or juice, remembering Christ, sharing his presence, and renewing community."}

Sources: [Source 1](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/the-lords-supper/).

### 11. anabaptist.confirmation

Some Brethren explicitly practice confirmation as an ordinance, so none was not accurate for the whole family.

Before: {"status": "none", "note": "Believers profess faith at baptism. No separate confirmation rite normally follows."}

After: {"status": "varies", "note": "Mennonites usually have no separate rite. Some Brethren confirm believers through laying on hands."}

Sources: [Source 1](https://brethrenchurch.org/contextual-brethren-live/).

### 12. anabaptist.marriage

The note admitted ordinance language, but the status said rite for the whole family.

Before: {"status": "rite", "note": "The congregation witnesses marriage vows and prays for the spouses. Some call marriage an ordinance."}

After: {"status": "varies", "note": "The church witnesses marriage vows and prays. Some Mennonites count marriage as an ordinance."}

Sources: [Source 1](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/marriage/), [Source 2](https://biblicalmennonite.com/wp-content/uploads/2021/08/Ministers-Manual-2016-2018-2021.pdf).

### 13. anglican.summary

Make the difference in counted sacraments explicit and consistent with the cells.

Before: Article 25 names two Gospel sacraments and five other rites. Anglicans differ over calling those five sacraments.

After: Article 25 names two Gospel sacraments. Some Anglicans count seven sacraments, while others call the remaining five sacramental rites.

Sources: [Source 1](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Source 2](https://ecphilippines.org/catechism/), [Source 3](https://www.anglicancatholic.org.uk/history/).

### 14. anglican.confirmation

The rite status hid a real split. Article 25 distinguishes Gospel sacraments, the Prayer Book names sacramental rites, and Anglican Catholics count seven sacraments.

Before: {"status": "rite", "note": "Bishops lay hands on baptized believers. Article 25 distinguishes this from Gospel sacraments."}

After: {"status": "varies", "note": "Bishops lay hands on believers. Some count confirmation as a sacrament, others a rite."}

Sources: [Source 1](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Source 2](https://ecphilippines.org/catechism/), [Source 3](https://www.anglicancatholic.org.uk/history/).

### 15. anglican.confession

The rite status hid a real split. Article 25 distinguishes Gospel sacraments, the Prayer Book names sacramental rites, and Anglican Catholics count seven sacraments.

Before: {"status": "rite", "note": "Offers communal confession and optional private absolution. Article 25 distinguishes penance from Gospel sacraments."}

After: {"status": "varies", "note": "Offers confession and optional private absolution. Some count penance as a sacrament, others a rite."}

Sources: [Source 1](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Source 2](https://ecphilippines.org/catechism/), [Source 3](https://www.anglicancatholic.org.uk/history/).

### 16. anglican.marriage

The rite status hid a real split. Article 25 distinguishes Gospel sacraments, the Prayer Book names sacramental rites, and Anglican Catholics count seven sacraments.

Before: {"status": "rite", "note": "Blesses marriage vows. Article 25 distinguishes matrimony from Gospel sacraments."}

After: {"status": "varies", "note": "Blesses marriage vows. Some count matrimony as a sacrament, others as a church rite."}

Sources: [Source 1](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Source 2](https://ecphilippines.org/catechism/), [Source 3](https://www.anglicancatholic.org.uk/history/).

### 17. anglican.ordination

The rite status hid a real split. Article 25 distinguishes Gospel sacraments, the Prayer Book names sacramental rites, and Anglican Catholics count seven sacraments.

Before: {"status": "rite", "note": "Bishops ordain deacons, priests, and bishops. Article 25 distinguishes orders from Gospel sacraments."}

After: {"status": "varies", "note": "Bishops ordain deacons, priests, and bishops. Some count orders as a sacrament, others a rite."}

Sources: [Source 1](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Source 2](https://ecphilippines.org/catechism/), [Source 3](https://www.anglicancatholic.org.uk/history/).

### 18. anglican.anointing

The rite status hid a real split. Article 25 distinguishes Gospel sacraments, the Prayer Book names sacramental rites, and Anglican Catholics count seven sacraments.

Before: {"status": "rite", "note": "Anoints the sick and prays for healing. Article 25 distinguishes unction from Gospel sacraments."}

After: {"status": "varies", "note": "Anoints the sick. Some count unction as a sacrament, others as a church rite."}

Sources: [Source 1](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Source 2](https://ecphilippines.org/catechism/), [Source 3](https://www.anglicancatholic.org.uk/history/).

### 19. evangelical-nondenom.communion

The cited Grace Community statement teaches actual communion with the risen Christ as well as representative elements.

Before: {"status": "ordinance", "note": "Usually shares bread and wine or juice to remember Jesus' death. Frequency differs by church."}

After: {"status": "ordinance", "note": "Usually shares bread and wine or juice in remembrance. Some also emphasize communion with Christ."}

Sources: [Source 1](https://www.gracechurch.org/about/doctrinal-statement).

### 20. eastern-catholic.parents

The group represents more than Byzantine reunions. Put its present Catholic communion first and include the other Eastern families represented.

Before: ["eastern-orthodox", "catholic"]

After: ["catholic", "eastern-orthodox", "oriental-orthodox", "church-of-east"]

Sources: [Source 1](https://cnewa.org/eastern-christian-churches/the-catholic-eastern-churches/), [Source 2](https://www.usccb.org/resources/who-are-catholics-middle-east).

### 21. eastern-catholic.summary

The 1596 date describes one reunion, not the origin of all 23 churches. The existing summary also exceeded 30 words.

Before: Eastern churches in full communion with the pope that keep their own liturgies, clergy, and church law. The largest, the Ukrainian Greek Catholic Church, came out of the Union of Brest in 1596.

After: Eastern churches in communion with Rome, preserving their own worship and law. Brest in 1596 marks one reunion, not the beginning of all Eastern Catholic churches.

Sources: [Source 1](https://cnewa.org/eastern-christian-churches/the-catholic-eastern-churches/), [Source 2](https://www.britannica.com/event/Union-of-Brest-Litovsk).

### 22. eastern-catholic.facts[1]

The 1182 claim needed context about the Maronite claim of continuous communion. Replace it with the tradition's own account.

Before: The Maronites of Lebanon confirmed their ties with Rome in 1182.

After: Maronites trace continuous communion with Rome. Other Eastern Catholic churches arose through reunions at different dates.

Sources: [Source 1](https://www.usccb.org/resources/who-are-catholics-middle-east), [Source 2](https://cnewa.org/eastern-christian-churches/the-catholic-eastern-churches/).

### 23. eastern-catholic.sacraments

The blanket statement about every infant receiving all three together omitted differences between churches and restored Eastern practice.

Before: Seven sacraments, often called holy mysteries. Infants receive baptism, chrismation, and first communion together. The Byzantine rite uses leavened bread.

After: Seven sacraments, often called holy mysteries. Eastern tradition joins baptism, chrismation, and communion, including for infants. Practices differ across churches. Byzantine churches use leavened Eucharistic bread.

Sources: [Source 1](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_one/article_1/iii_how_is_the_sacrament_of_baptism_celebrated.index.html), [Source 2](https://www.vatican.va/content/catechism/en/part_two/section_two.html), [Source 3](https://www.vatican.va/archive/hist_councils/ii_vatican_council/documents/vat-ii_decree_19641121_orientalium-ecclesiarum_en.html).

### 24. eastern-catholic.disputed

The text gave only the rejection of uniatism and omitted the same document's recognition of Eastern Catholic churches. It also exceeded 25 words.

Before: Orthodox critics call these unions uniatism. The 1993 Balamand statement, signed by Catholic and Orthodox theologians, rejected it as a path to reunion.

After: The 1993 Balamand dialogue rejected uniatism as a model for reunion, while affirming Eastern Catholic churches' right to exist.

Sources: [Source 1](https://www.christianunity.va/content/unitacristiani/en/dialoghi/sezione-orientale/chiese-ortodosse-di-tradizione-bizantina/commissione-mista-internazionale-per-il-dialogo-teologico-tra-la/documenti-di-dialogo/testo-in-lingua-inglese.html).

### 25. patch.catholic.why

The old override flattened indirect Protestant ancestry into a direct break and would restore an older count over the era correction.

Before: It is the largest Christian church, about 1.4 billion people, and the line most Protestant churches broke from in the 1500s.

After: The largest Christian church, with about 1.42 billion baptized members. Most Protestant traditions trace their separation from Rome to the Reformation.

Sources: [Source 1](https://www.vaticannews.va/en/vatican-city/news/2026-03/new-data-from-annuario-pontificio-2026-shows-catholics-growing.html), [Source 2](https://2017.lutheranworld.org/sites/default/files/documents/From%20Conflict%20to%20Communion%20EN_0.pdf).


## Coverage and retained judgments

Each row's summary and all seven cell statuses and notes were checked. The cell order below is baptism, communion, confirmation, confession, marriage, ordination, and anointing. The correction entries above identify every changed cell. All other cells were retained.

- church-of-east: sacrament, sacrament, sacrament, sacrament, rite, sacrament, rite. Holy oil completes baptism and corresponds to chrismation. The marriage and sick-anointing statuses follow Abdisho's counted seven, while their notes retain the sacramental character affirmed in modern dialogue. This is a difference in enumeration, not a claim that these rites lack grace. Sources: [Assyrian sacrament teaching](https://www.assyrianchurch.org/sacraments/) and the [2017 common statement](https://news.assyrianchurch.org/wp-content/uploads/2017/11/Common-Statement-on-Sacramental-Life-FINAL-VERSION-18-NOV.pdf), especially pages 3, 7, 11, and 13.
- oriental-orthodox: seven sacrament cells. Checked the Coptic account against Armenian teaching. Armenian practice can omit sick-anointing oil without denying the sacrament, so this does not require varies. Infant communion and immediate chrismation remain accurate. Sources: [Coptic sacramental teaching](https://www.copticchurch.net/introduction-to-the-coptic-church/sacraments/index), [Armenian diocesan teaching](https://armenianchurch.us/sacraments/), and [Armenian prayers for the sick](https://www.stmaryaac.org/anointing-the-sick).
- eastern-orthodox: seven sacrament cells. Retained the distinction between seven commonly named mysteries and a sacramental life that extends beyond them. Triple immersion, infant communion, priestly chrismation, confession, crowning, episcopal ordination, and healing unction agree with the [OCA's sacrament chapters](https://www.oca.org/orthodoxy/the-orthodox-faith/worship/the-sacraments/the-sacraments).
- catholic: seven sacrament cells. Checked infant baptism, conversion of the Eucharistic elements with their appearances remaining, Eastern confirmation at baptism, absolution and penance, marriage between baptized spouses, the three ordained ranks, and illness or age as grounds for anointing. Sources: [Catechism paragraphs 1210 onward](https://www.vatican.va/content/catechism/en/part_two/section_two.html), [baptismal grace](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_one/article_1/vii_the_grace_of_baptism.index.html), [Eucharistic presence](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_one/article_3/v_the_sacramental_sacrifice_thanksgiving_memorial_presence.index.html), and [anointing provisions](https://www.vatican.va/content/paul-vi/en/apost_constitutions/documents/hf_p-vi_apc_19721130_sacram-unctionem.html).
- lutheran: sacrament, sacrament, rite, varies, rite, rite, rite. Absolution remains a means of forgiveness regardless of how many sacraments a church counts. The Apology permits sacramental language for ordination understood as the ministry of the Word. The retained ordination note says this, while rite reflects ordinary enumeration. Healing oil remains an optional church rite. Sources: [Augsburg Confession Articles IX to XIV and XXV](https://bookofconcord.org/augsburg-confession/), [Apology XIII](https://bookofconcord.org/defense/of-the-number-and-use-of-sacraments/), [Small Catechism](https://bookofconcord.org/small-catechism/), [ELCA enumeration](https://download.elca.org/ELCA%20Resource%20Repository/What_is_a_sacrament_for_Lutherans.pdf), and [ELCA use of oil](https://download.elca.org/ELCA%20Resource%20Repository/How_is_oil_used_in_worship.pdf).
- reformed: sacrament, sacrament, rite, rite, rite, rite, varies. Signs and seals and real spiritual feeding agree with Heidelberg Questions 65 to 79 and Westminster Chapters 27 to 29. Public profession, confession and pardon, marriage, and ordination are church rites. The grid correctly allows different anointing practices. Added both requested confessional sources to the row. Sources: [Heidelberg Catechism](https://www.crcna.org/welcome/beliefs/confessions/heidelberg-catechism), [Westminster Confession](https://www.opc.org/wcf.html), and [Presbyterian Directory for Worship](https://centernet.pcusa.org/ministries/worship/directory-for-worship/rdfw-chapter-four/).
- anabaptist: ordinance, ordinance, varies, rite, varies, rite, varies. Retained believers' baptism with different water modes, confession and reconciliation before communion, and ordination with prayer and hands. Brethren confirmation and Mennonite marriage show actual differences in practice or classification. Brethren anointing is explicitly an ordinance. Sources: Mennonite Confession Articles [11](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/baptism/), [12](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/the-lords-supper/), [14](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/discipline-in-the-church/), [15](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/ministry-and-leadership/), and [19](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/marriage/), [Church of the Brethren practices](https://www.brethren.org/about/practices/), [Brethren Church ordinances](https://brethrenchurch.org/contextual-brethren-live/), and [Biblical Mennonite Alliance marriage liturgy](https://biblicalmennonite.com/wp-content/uploads/2021/08/Ministers-Manual-2016-2018-2021.pdf), pages 62 and 70 in the PDF.
- anglican: sacrament, sacrament, then five varies cells. Water with the Trinitarian name, infant baptism, and Eucharistic communion are sound. The other five remain formal rites, but their counted sacramental status differs. Sources: [Article 25 and Article 28](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Prayer Book catechism on a province's official site](https://ecphilippines.org/catechism/), and [Anglican Catholic teaching](https://www.anglicancatholic.org.uk/history/).
- methodist: sacrament, sacrament, then five rite cells. Checked grace through baptism, infant baptism and the three water modes, Christ's true presence in communion, confirmation with the Spirit's strengthening, communal confession, marriage, ordained deacons and elders, and optional healing oil. Sources: [By Water and the Spirit](https://www.umc.org/en/content/by-water-and-the-spirit-a-united-methodist-understanding-of-baptism), [This Holy Mystery](https://www.umc.org/-/media/umc-media/2013/12/19/01/24/this-holy-mystery-communion.pdf), [United Methodist rites](https://www.umc.org/en/content/united-methodist-sacraments-rites-and-rituals), and [healing liturgy](https://www.umcdiscipleship.org/book-of-worship/a-service-of-healing-i).
- pentecostal: ordinance, ordinance, none, none, rite, rite, rite. The Assemblies of God names water baptism and communion as ordinances and distinguishes Spirit baptism from new birth. The baptism note correctly includes the Oneness difference. The confirmation and confession cells describe the absence of a standard separate rite, not an absence of the Spirit or repentance. Sources: [Fundamental Truths 6, 7, and 12](https://ag.org/Beliefs/Statement-of-Fundamental-truths), [divine healing](https://ag.org/beliefs/position-papers/divine-healing), and [UPCI New Zealand teaching](https://www.upci.co.nz/about-1).
- baptist: ordinance, ordinance, none, none, rite, rite, varies. The immersion and memorial account matches Baptist Faith and Message Articles VI and VII. The row already preserves Reformed Baptist spiritual nourishment and different practices of healing oil. None here means no standard separate confirmation or priestly absolution rite, not no profession or confession. Sources: [Baptist Faith and Message](https://bfm.sbc.net/bfm2000/), [Reformed Baptist treatment](https://founders.org/articles/baptism-and-lords-supper/), and the cited [Baptist anointing discussion](https://www.sgbcsv.org/literature/PrayerAndAnointingWithOil.pdf).
- evangelical-nondenom: ordinance, ordinance, none, none, rite, varies, varies. The qualifiers usually and most are necessary because this family has no common confession. The revised communion note now reflects the cited church's actual teaching as well as symbolic elements. Sources: [Grace Community doctrinal statement](https://www.gracechurch.org/about/doctrinal-statement) and [Calvary Chapel beliefs](https://calvarychapel.com/beliefs/).

The confession, ordination, and anointing what texts were retained. They describe common actions without assigning all churches the same theology. Four other rite definitions were corrected above.

The six unchanged patches remain defensible. The Chalcedonian-separation facts correctly distinguish the council from the gradual institutional division. The five on-null patches remove artificial branch attachments from broad events involving several families. The Catholic why patch was corrected above. Patch sources preserve the underlying era node's current sources because merge-data replaces source arrays rather than appending them.

## For the lead

Seven issues remain in files outside my ownership. I have not edited those files.

### 1. src/layout.ts, EUCHARIST.spiritual.name and the relationship to varied

Spiritual presence is a form of real presence in Reformed and Methodist teaching. The separate label Real presence, views vary can make their placement under Spiritual presence look like a denial of real presence. Rename spiritual to Real spiritual presence, or otherwise say explicitly that these are different accounts of real presence. Keep Reformed and Methodist in this category. This Holy Mystery also says Christ's presence does not depend on an individual's recognition.

Sources: [Westminster 29.7](https://www.opc.org/wcf.html), [Heidelberg 76](https://www.crcna.org/welcome/beliefs/confessions/heidelberg-catechism), and [This Holy Mystery, PDF pages 11 to 13](https://www.umc.org/-/media/umc-media/2013/12/19/01/24/this-holy-mystery-communion.pdf).

### 2. src/layout.ts, EUCHARIST.transub.note

The substance becomes Christ is too imprecise. Bread and wine only appear to remain can also sound as if their outward properties are an illusion. Suggested note: "The bread and wine become Christ's body and blood. Their outward appearances remain." Keep catholic and eastern-catholic assigned to transub. Eastern Catholic terminology and liturgical traditions do not imply a different Catholic doctrine of Eucharistic conversion.

Source: [Catechism 1374 to 1377](https://www.vatican.va/content/catechism/en/part_two/section_two/chapter_one/article_3/v_the_sacramental_sacrifice_thanksgiving_memorial_presence.index.html).

### 3. src/layout.ts, EUCHARIST.mystery.note

The note names only ancient Eastern churches, but EUCHARIST_OF also assigns old-catholic to this category. The Old Catholic assignment is defensible. The Union of Utrecht affirms receiving Christ's body and blood under bread and wine. Widen the note to include Old Catholics. Do not silently imply that Old Catholics are an ancient Eastern communion.

Source: [Declaration of Utrecht, paragraph 6](https://www.utrechter-union.org/en/about-us/what-is-the-union-of-utrecht/the-declaration-of-utrecht/).

### 4. src/layout.ts, EUCHARIST.none.note and EUCHARIST_OF.quaker

No outward sacraments describes the historic Quaker position, but it is not universal among current Friends. Evangelical Friends in Mid-America explicitly permit individuals and congregations to use physical elements in baptism and communion. Qualify the note and Quaker detail, or provide a category that can show this split. Suggested note: "Most Quakers and the Salvation Army. Some evangelical Friends also use outward baptism and communion."

Sources: [Quaker faith and practice](https://qfp.quaker.org.uk/passage/27-38/) and [Evangelical Friends Faith and Practice 2022, PDF page 15](https://efcmaym.org/wp-content/uploads/2023/03/Current-FP-with-corrected-language-22.pdf).

### 5. src/screens.ts, sacrament grid introductory text at line 178

The definition of ordinance as a sign rather than a means of grace imposes one theological distinction on all traditions. It clashes with the Mennonite confession's language about God's action and continuing grace and with Grace Community's actual communion with the risen Christ. Ordinance names obedience to Christ, and churches differ over what happens in the rite. Suggested replacement: "An ordinance is a practice observed in obedience to Christ. Churches differ over how it relates to grace."

Sources: [Mennonite Confession Article 12](https://www.mennoniteusa.org/who-are-mennonites/what-we-believe/confession-of-faith/the-lords-supper/) and [Grace Community doctrinal statement](https://www.gracechurch.org/about/doctrinal-statement).

### 6. research/era3.json, anglican.sacraments

Five other rites are commonly called sacraments is too broad for a family whose Prayer Book catechism calls them sacramental rites and whose Anglo-Catholic churches count seven. The contrast between Reformed spiritual presence and Anglo-Catholic real presence also implies that spiritual presence is not real. Suggested text, 24 words: "Two Gospel sacraments, baptism and Eucharist. Baptism includes infants. Anglicans differ over counting five other rites and explain Christ's real presence in several ways."

Sources: [Article 25 and Article 28](https://www.churchofengland.org/prayer-and-worship/worship-texts-and-resources/book-common-prayer/articles-religion), [Prayer Book catechism](https://ecphilippines.org/catechism/), and [Anglican Catholic teaching](https://www.anglicancatholic.org.uk/history/).

### 7. research/era4.json, pentecostal.sacraments

The unqualified description of Spirit baptism as a distinct experience of spiritual power gives only the classical Pentecostal account. If this node includes Oneness churches, as the grid does, mention their teaching that water and Spirit baptism belong to new birth. Suggested text, 27 words: "Usually two ordinances, believers' baptism and communion. Many distinguish Spirit baptism from conversion. Oneness churches link water and Spirit baptism to new birth. Some practice foot washing."

Sources: [Assemblies of God Fundamental Truth 7](https://ag.org/Beliefs/Statement-of-Fundamental-truths) and [UPCI New Zealand teaching](https://www.upci.co.nz/about-1).

### Other communion assignments and main-node fields

Reviewed every EUCHARIST category name and note and every EUCHARIST_OF assignment. The Lutheran sacramental-union label, Anglican and Moravian varied explanations, Eastern mystery groups, and the predominant memorial accounts remain defensible at this scale. Keep Moravian under varied. Its own account affirms Christ's presence without defining the exact relation to the elements. Memorial should describe remembrance and representative elements, not rule out every spiritual encounter with Christ. Sources: [Moravian communion teaching](https://www.moravian.org/what-we-believe/rites-and-sacraments-of-the-moravian-church/), [Small Catechism on the altar](https://bookofconcord.org/small-catechism/), and [Assemblies of God Fundamental Truth 6](https://ag.org/Beliefs/Statement-of-Fundamental-truths).

The sacraments fields of church-of-east, oriental-orthodox, eastern-orthodox, catholic, lutheran, reformed, anabaptist, methodist, baptist, and evangelical-nondenom contain no further material errors at this scale. Their current texts fit the 30-word limit. Anglican and Pentecostal qualifications are reported above. The Methodist real spiritual presence wording is sound. The Reformed text correctly distinguishes Calvin and Zwingli. The Lutheran text already acknowledges absolution alongside the common count of two.

## Validation

Both owned JSON files parse. The grid has 12 unique tradition rows, seven unique rites, and exactly 84 cells. All statuses use the permitted values. Every cell note is at most 15 words and every row summary is at most 30 words. The Eastern Catholic text meets the stated limits. No ids were renamed and no nodes were added or removed.

Ran node scripts/merge-data.mjs with an in-memory filesystem hook that suppresses its generated-file writes and parses each generated JSON value. This preserves the edit-only-assigned-files rule. The actual merge and reference checks completed successfully: 127 nodes from four era files, 12 sacrament rows, and 15 lineage steps. No broken references were reported. The lead should run the normal merge after combining the agents' edits to update src/data.
