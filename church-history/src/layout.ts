// Hand-tuned layout for the map. Data lives in data/nodes.json; this file
// decides where each tradition sits and how it is colored.

/** The shared line from the apostles to 1054. Catholic and Orthodox both fork from it. */
export const TRUNK = ['apostolic', 'early-church', 'chalcedonian'];

/**
 * Lane order from top to bottom. Families stay together, and most later branches
 * sit closer to their parent than earlier ones, so few lines cross. Traditions
 * missing from this list are placed right after their first parent.
 */
export const LANE_ORDER = [
  'church-of-east',
  'oriental-orthodox',
  'old-believers',
  'orthodox-church-ukraine',
  'eastern-orthodox',
  '__trunk__',
  'waldensians',
  'moravian',
  'eastern-catholic',
  'catholic',
  'old-catholic',
  'lutheran',
  'reformed',
  'anabaptist',
  'restorationist',
  'congregationalist',
  'anglican',
  'acna',
  'methodist',
  'global-methodist',
  'salvation-army',
  'holiness',
  'pentecostal',
  'charismatic',
  'oneness-pentecostal',
  'latter-day-saints',
  'african-methodist-episcopal',
  'quaker',
  'baptist',
  'evangelical-nondenom',
  'national-baptist-convention',
  'southern-baptist',
  'adventist',
  'jehovahs-witnesses',
];

export interface Swatch {
  name: string;
  note?: string;
  color: string;
}

export const FAMILIES: Record<string, Swatch> = {
  early: { name: 'Shared early church', color: '#3d3d3d' },
  east: { name: 'Church of the East', color: '#0e8a80' },
  oriental: { name: 'Oriental Orthodox', color: '#d17a1e' },
  orthodox: { name: 'Eastern Orthodox', color: '#7a4fcf' },
  catholic: { name: 'Catholic', color: '#b88a00' },
  magisterial: { name: 'Lutheran, Reformed, Anglican', color: '#2c6cd4' },
  free: { name: 'Anabaptist, Baptist, Quaker', color: '#2f9447' },
  revival: { name: 'Methodist, Holiness, Pentecostal', color: '#d1405a' },
  restoration: { name: 'Restorationist, Adventist', color: '#1593a6' },
  outside: { name: 'Outside the historic creeds', color: '#8a8f9c' },
};

export const FAMILY_OF: Record<string, string> = {
  apostolic: 'early',
  'early-church': 'early',
  chalcedonian: 'early',
  'church-of-east': 'east',
  'oriental-orthodox': 'oriental',
  'eastern-orthodox': 'orthodox',
  'old-believers': 'orthodox',
  catholic: 'catholic',
  'eastern-catholic': 'catholic',
  'old-catholic': 'catholic',
  waldensians: 'magisterial',
  hussites: 'magisterial',
  lutheran: 'magisterial',
  reformed: 'magisterial',
  presbyterian: 'magisterial',
  anglican: 'magisterial',
  congregationalist: 'magisterial',
  anabaptist: 'free',
  baptist: 'free',
  quaker: 'free',
  moravian: 'revival',
  methodist: 'revival',
  holiness: 'revival',
  pentecostal: 'revival',
  charismatic: 'revival',
  'evangelical-nondenom': 'revival',
  restorationist: 'restoration',
  adventist: 'restoration',
};

/** How each tradition understands communion (the Lord's Supper, the Eucharist). */
export const EUCHARIST: Record<string, Swatch> = {
  early: { name: 'Christ\'s body and blood', note: 'Confessed by the early church before later disputes defined how', color: '#3d3d3d' },
  mystery: { name: 'Truly his body and blood, a mystery', note: 'Orthodox, other ancient Eastern churches, and Old Catholics. Some Eastern confessions also say transubstantiation. Priestless Old Believers cannot celebrate the Eucharist', color: '#7a4fcf' },
  transub: { name: 'Transubstantiation', note: 'The bread and wine become Christ\'s body and blood. Their outward appearances remain', color: '#b88a00' },
  union: { name: 'Real presence: in, with, and under', note: 'Lutheran. Bread and wine remain, and Christ is truly there', color: '#2c6cd4' },
  varied: { name: 'Views of presence vary', note: 'Anglican and Moravian affirm real presence without one fixed explanation. Charismatics follow their own church\'s teaching', color: '#c2408a' },
  spiritual: { name: 'Real spiritual presence', note: 'Reformed and Methodist. Through the Spirit, Christ is truly present, and faith receives him', color: '#2f9447' },
  memorial: { name: 'Memorial', note: 'An act of remembrance, often called an ordinance. Some also teach Christ\'s spiritual presence or his presence in the gathered church', color: '#1593a6' },
  none: { name: 'No outward sacraments', note: 'Most Quakers and the Salvation Army. Some evangelical Friends do use outward baptism and communion', color: '#9a8466' },
  outside: { name: 'Outside the historic creeds', color: '#8a8f9c' },
};

export const EUCHARIST_OF: Record<string, string> = {
  apostolic: 'early',
  'early-church': 'early',
  chalcedonian: 'early',
  'church-of-east': 'mystery',
  'oriental-orthodox': 'mystery',
  'eastern-orthodox': 'mystery',
  'old-believers': 'mystery',
  catholic: 'transub',
  'eastern-catholic': 'transub',
  'old-catholic': 'mystery',
  waldensians: 'spiritual',
  hussites: 'varied',
  moravian: 'varied',
  lutheran: 'union',
  anglican: 'varied',
  reformed: 'spiritual',
  presbyterian: 'spiritual',
  congregationalist: 'spiritual',
  methodist: 'spiritual',
  holiness: 'spiritual',
  anabaptist: 'memorial',
  baptist: 'memorial',
  restorationist: 'memorial',
  adventist: 'memorial',
  pentecostal: 'memorial',
  charismatic: 'varied',
  'evangelical-nondenom': 'memorial',
  quaker: 'none',
  'salvation-army': 'none',
};

/** The 30,000 ft view: the big families and the moments that shaped them. */
export const SIMPLE_TRADITIONS = [
  'apostolic',
  'early-church',
  'chalcedonian',
  'church-of-east',
  'oriental-orthodox',
  'eastern-orthodox',
  'catholic',
  'lutheran',
  'reformed',
  'anabaptist',
  'anglican',
  'baptist',
  'methodist',
  'pentecostal',
  'evangelical-nondenom',
];

export const SIMPLE_MARKERS = [
  'nicaea-i',
  'constantinople-i',
  'ephesus',
  'chalcedon',
  'nicaea-ii',
  'great-schism-1054',
  'ninety-five-theses',
  'council-of-trent',
  'vatican-ii',
];

/** Lane order for the simple view, top to bottom. Branches sit beside the line they came from. */
export const SIMPLE_ORDER = [
  'church-of-east',
  'oriental-orthodox',
  'eastern-orthodox',
  '__trunk__',
  'catholic',
  'lutheran',
  'reformed',
  'anabaptist',
  'anglican',
  'methodist',
  'pentecostal',
  'baptist',
  'evangelical-nondenom',
];

/** Shorter names for the map labels. */
export const SHORT_NAME: Record<string, string> = {
  apostolic: 'Jesus and the apostles',
  'eastern-orthodox': 'Eastern Orthodox',
  catholic: 'Catholic',
  pentecostal: 'Pentecostal',
  'evangelical-nondenom': 'Nondenominational',
  'nicaea-i': 'Nicaea',
  'constantinople-i': 'Constantinople',
  ephesus: 'Ephesus',
  chalcedon: 'Chalcedon',
  'nicaea-ii': 'Nicaea II',
  'ninety-five-theses': 'The Reformation',
  'council-of-trent': 'Trent',
};

/** Familiar names inside each family, so readers can find their own church. */
export const EXAMPLES: Record<string, string> = {
  'church-of-east': 'Assyrian Church of the East',
  'oriental-orthodox': 'Coptic, Armenian, Ethiopian, Syriac',
  'eastern-orthodox': 'Greek, Russian, Antiochian, OCA',
  catholic: 'Roman Catholic and Eastern Catholic',
  lutheran: 'ELCA, Missouri Synod',
  reformed: 'Presbyterian and Reformed',
  anabaptist: 'Mennonite, Amish, Hutterite',
  anglican: 'Episcopal, Church of England, ACNA',
  methodist: 'United Methodist, Wesleyan, AME',
  pentecostal: 'Assemblies of God, Foursquare, COGIC',
  baptist: 'Southern Baptist, American Baptist',
  'evangelical-nondenom': 'Independent Bible and community churches',
};

export interface Chapter {
  title: string;
  from: number;
  to: number;
  text: string;
  /** The year that stands for the chapter, shown beside its title. */
  focus: number;
}

export const CHAPTERS: Chapter[] = [
  {
    title: 'Two thousand years in one picture',
    focus: 30,
    from: 30,
    to: 2026,
    text: 'Every line is a church tradition. Time runs left to right, from Jesus to today. Filled dots are councils. Open rings are splits.',
  },
  {
    title: 'One church',
    focus: 60,
    from: 30,
    to: 320,
    text: "Jesus' followers carried the faith from Jerusalem across the Roman Empire. Often persecuted, they gathered around baptism and the Lord's Supper. Rival groups and local splits already existed, but most churches still saw themselves as one body.",
  },
  {
    title: 'The creeds',
    focus: 400,
    from: 300,
    to: 480,
    text: 'After Rome legalized Christianity in 313, emperors backed councils of bishops on Christ and the Trinity. Nicaea in 325 adopted a creed. Constantinople in 381 affirmed the Spirit\'s divinity, and tradition credits it with the Nicene Creed said today. The Persian church declared independence in 424. Ephesus in 431 and Chalcedon in 451 slowly set the Church of the East and the Oriental Orthodox on their own paths.',
  },
  {
    title: 'East and West',
    focus: 1054,
    from: 450,
    to: 1120,
    text: "The Greek East and the Latin West drifted apart over language, politics, the pope's authority, and the Filioque. The excommunications of 1054 became the marker of a split that took centuries to harden. Eastern Orthodox and Catholic churches both claim unbroken continuity with the apostles.",
  },
  {
    title: 'The Reformation',
    focus: 1540,
    from: 1480,
    to: 1620,
    text: 'In 1517 Martin Luther challenged the sale of indulgences. Over the next decades the Lutheran, Reformed, Anabaptist, and Anglican churches took shape. Catholics defined their teaching at the Council of Trent.',
  },
  {
    title: 'New branches',
    focus: 1760,
    from: 1580,
    to: 1980,
    text: 'Protestant churches kept renewing and dividing. Baptists began in 1609. Methodists grew out of the Church of England in the 1700s. Pentecostalism grew from Holiness revivals around 1900 and spread from Los Angeles in 1906.',
  },
  {
    title: 'Today',
    focus: 1960,
    from: 1880,
    to: 2026,
    text: 'The World Christian Database estimates about 2.7 billion Christians in 2026. Roughly half are Catholic, two in five are Protestant or independent, and one in ten is Eastern or Oriental Orthodox.',
  },
];

export const FIRST_YEAR = 30;
export const NOW = 2026;
