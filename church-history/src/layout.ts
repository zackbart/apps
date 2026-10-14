// Hand-tuned layout for the map. Data lives in data/nodes.json; this file
// decides where each tradition sits and how it is colored.

/** The shared line from the apostles to 1054. Catholic and Orthodox both fork from it. */
export const TRUNK = ['apostolic', 'early-church', 'chalcedonian'];

/**
 * Lane order from back (far from the camera) to front. Traditions missing from
 * this list are placed right after their first parent.
 */
export const LANE_ORDER = [
  'church-of-east',
  'oriental-orthodox',
  'old-believers',
  'eastern-orthodox',
  '__trunk__',
  'eastern-catholic',
  'catholic',
  'old-catholic',
  'waldensians',
  'hussites',
  'moravian',
  'lutheran',
  'anglican',
  'methodist',
  'holiness',
  'pentecostal',
  'charismatic',
  'evangelical-nondenom',
  'baptist',
  'adventist',
  'restorationist',
  'congregationalist',
  'quaker',
  'reformed',
  'anabaptist',
];

export interface Swatch {
  name: string;
  note?: string;
  color: string;
}

export const FAMILIES: Record<string, Swatch> = {
  early: { name: 'Shared early church', color: '#eee4c8' },
  east: { name: 'Church of the East', color: '#4fbdae' },
  oriental: { name: 'Oriental Orthodox', color: '#e7a052' },
  orthodox: { name: 'Eastern Orthodox', color: '#a48df0' },
  catholic: { name: 'Catholic', color: '#f0cb63' },
  magisterial: { name: 'Lutheran, Reformed, Anglican', color: '#62a9f5' },
  free: { name: 'Anabaptist, Baptist, Quaker', color: '#6fd08f' },
  revival: { name: 'Methodist, Holiness, Pentecostal', color: '#f58ea6' },
  restoration: { name: 'Restorationist, Adventist', color: '#58d3e0' },
  outside: { name: 'Outside the historic creeds', color: '#8891a8' },
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
  early: { name: 'Christ\'s body and blood', note: 'Held by the early church before anyone defined how', color: '#eee4c8' },
  mystery: { name: 'Truly his body and blood, a mystery', note: 'Orthodox and other ancient Eastern churches', color: '#a48df0' },
  transub: { name: 'Transubstantiation', note: 'The substance becomes Christ. Bread and wine only appear to remain', color: '#f0cb63' },
  union: { name: 'Real presence: in, with, and under', note: 'Lutheran. Bread and wine remain, and Christ is truly there', color: '#62a9f5' },
  varied: { name: 'Real presence, views vary', note: 'Anglican and Moravian. Affirmed without one fixed explanation', color: '#f58ea6' },
  spiritual: { name: 'Spiritual presence', note: 'Reformed and Methodist. Christ is received by faith through the Spirit', color: '#6fd08f' },
  memorial: { name: 'Memorial', note: 'An act of remembrance and obedience, often called an ordinance', color: '#58d3e0' },
  none: { name: 'No outward sacraments', note: 'Quakers and the Salvation Army', color: '#c9b6a0' },
  outside: { name: 'Outside the historic creeds', color: '#8891a8' },
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

/** Lane order for the simple view, back to front. Branches sit beside the line they came from. */
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

export interface Chapter {
  title: string;
  from: number;
  to: number;
  text: string;
  /** Used instead of text on tall screens, where time runs down the page. */
  tallText?: string;
  /** The year the timeline view centers on for this chapter. */
  focus: number;
}

export const CHAPTERS: Chapter[] = [
  {
    title: 'Two thousand years in one picture',
    focus: 30,
    from: 30,
    to: 2026,
    text: 'Every line is a church tradition. They all start with Jesus on the left and run to today on the right. Gold halos are councils. Red rings are splits.',
    tallText: 'Every line is a church tradition. They all start with Jesus at the top and run down to today. Gold halos are councils. Red rings are splits.',
  },
  {
    title: 'One church',
    focus: 60,
    from: 30,
    to: 320,
    text: "Jesus' followers carried the faith from Jerusalem across the Roman Empire. For three centuries it was one fellowship, often persecuted, gathered around baptism and the Lord's Supper.",
  },
  {
    title: 'The creeds',
    focus: 400,
    from: 300,
    to: 480,
    text: 'Once Rome legalized Christianity in 313, bishops met in councils to settle who Jesus is. Nicaea gave us the Nicene Creed. Fights at Ephesus in 431 and Chalcedon in 451 sent the Church of the East and the Oriental Orthodox their own way.',
  },
  {
    title: 'East and West',
    focus: 1054,
    from: 450,
    to: 1120,
    text: "The Greek East and the Latin West drifted apart over language, politics, and the pope's authority. In 1054 the break became formal. The East became Eastern Orthodox and the West became Catholic.",
  },
  {
    title: 'The Reformation',
    focus: 1540,
    from: 1480,
    to: 1620,
    text: 'In 1517 Martin Luther challenged the sale of indulgences. Within twenty years the Lutheran, Reformed, Anabaptist, and Anglican churches had formed. Rome answered at the Council of Trent.',
  },
  {
    title: 'New branches',
    focus: 1760,
    from: 1580,
    to: 1980,
    text: 'Protestant churches kept renewing and dividing. Baptists began in 1609. Methodists grew out of the Church of England in the 1700s. Pentecostals came from a 1906 revival in Los Angeles.',
  },
  {
    title: 'Today',
    focus: 1960,
    from: 1880,
    to: 2026,
    text: 'More than 2.5 billion people are Christians. Just over half are Catholic, about two in five are Protestant or independent, and about one in ten is Orthodox.',
  },
];

export const FIRST_YEAR = 30;
export const NOW = 2026;
