// Line-art emblems drawn from representative symbols used within each tradition.
// All share a 24x24 box and take the line's color through currentColor.

const svg = (body: string) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`;

export const EMBLEMS: Record<string, string> = {
  // Ichthys, the fish Christians used as a sign of Jesus from the second century.
  apostolic: svg('<path d="M2.5 12c4-6.5 11.5-6.5 17 3M2.5 12c4 6.5 11.5 6.5 17-3"/><circle cx="7.2" cy="11" r=".6" fill="currentColor"/>'),
  // Saint Thomas cross over a lotus, from the Syriac churches of India.
  'church-of-east': svg(
    '<path d="M12 3.5v11M7.5 8h9"/><circle cx="12" cy="3.2" r="1"/><circle cx="7" cy="8" r="1"/><circle cx="17" cy="8" r="1"/><path d="M5 19.5c2.3-3.3 4.7-3.3 7 0 2.3-3.3 4.7-3.3 7 0M12 14.5v5"/>',
  ),
  // Coptic cross.
  'oriental-orthodox': svg(
    '<circle cx="12" cy="12" r="3.2"/><path d="M12 3v5.8M12 15.2V21M3 12h5.8M15.2 12H21"/><circle cx="12" cy="2.6" r="1.1"/><circle cx="12" cy="21.4" r="1.1"/><circle cx="2.6" cy="12" r="1.1"/><circle cx="21.4" cy="12" r="1.1"/>',
  ),
  // Three-bar cross, used most widely in Russian and Slavic Orthodoxy.
  'eastern-orthodox': svg('<path d="M12 2.5v19M9.3 5.5h5.4M6.5 9.5h11M8.6 17.4l6.8-2.6"/>'),
  // Crossed keys of Peter.
  catholic: svg(
    '<circle cx="6" cy="18" r="2.4"/><path d="M7.7 16.3 19.5 4.5M17.4 6.6l2 2M15.4 8.6l1.6 1.6"/><circle cx="18" cy="18" r="2.4"/><path d="M16.3 16.3 4.5 4.5M6.6 6.6l-2 2M8.6 8.6 7 10.2"/>',
  ),
  // Simplified Luther seal: the heart and cross inside a ring, without the rose petals.
  lutheran: svg(
    '<circle cx="12" cy="12" r="9.5"/><path d="M12 17.5c-3.8-2.6-5.6-4.6-5.6-7a2.8 2.8 0 0 1 5.6-.6 2.8 2.8 0 0 1 5.6.6c0 2.4-1.8 4.4-5.6 7z"/><path d="M12 9.3v5.4M10.1 11h3.8"/>',
  ),
  // Burning bush, "burning but not consumed", used most by Presbyterian and Reformed churches.
  reformed: svg('<path d="M12 2.8c.8 3.6 4.6 4.8 4.6 9a4.6 4.6 0 0 1-9.2 0c0-2.6 1.6-3.8 2-5.8 1.3 1 1.8 2 1.8 3 1-1.8 1-3.6.8-6.2z"/><path d="M12 16.4v4.8M12 19l-4-2.6M12 19l4-2.6"/>'),
  // Dove with an olive branch, a peace motif used by Mennonite groups.
  anabaptist: svg('<path d="M2.8 12.5c3 .3 5.2-1.4 7-4.6.7 2.6 2.6 4 5.6 3.9l4.8-2.6-1.6 3.6c-1 3-3.8 4.8-7.6 4.8-3.4 0-6.2-1.7-8.2-5.1z"/><path d="M15.5 16.8l3 3.2M17 18.4l1.8-.6M16.2 17.6l-.4 1.8"/>'),
  // Compass rose of the Anglican Communion.
  anglican: svg('<path d="M12 2l2 7.8 7.8 2.2-7.8 2.2L12 22l-2-7.8L2.2 12 10 9.8z"/><circle cx="12" cy="12" r="2.2"/>'),
  // Cross and flame, the United Methodist insignia since 1968, standing in for the Methodist family.
  methodist: svg('<path d="M9 3v18M5.2 8h7.6"/><path d="M14 20.5c-2.6-2.4-.6-5.4.6-8.4 1.2 2 4.4 3.4 4.4 6.2a3 3 0 0 1-5 2.2z"/>'),
  // Tongues of fire from Pentecost.
  pentecostal: svg('<path d="M12 2.5c1 4.2 6 6 6 11.5a6 6 0 0 1-12 0c0-3.2 2-5.2 3-7.4 1.2 1.6 2 3 2 4.2 1.2-2.8 1.4-5.4 1-8.3z"/><path d="M12 20c-1.6 0-2.6-1.2-2.6-2.6 0-1.6 1.4-2.6 2.6-4.2 1.2 1.6 2.6 2.6 2.6 4.2 0 1.4-1 2.6-2.6 2.6z"/>'),
  // Water of believers' baptism.
  baptist: svg('<path d="M12 3c3.2 4.2 5 6.6 5 9.2a5 5 0 0 1-10 0c0-2.6 1.8-5 5-9.2z"/><path d="M2.5 20c1.6-1.3 3.2-1.3 4.8 0s3.2 1.3 4.8 0 3.2-1.3 4.8 0 3.2 1.3 4.8 0"/>'),
  // Open Bible.
  'evangelical-nondenom': svg('<path d="M12 6.2c-2.2-1.6-5.2-2-9-1.6v13.2c3.8-.4 6.8 0 9 1.6 2.2-1.6 5.2-2 9-1.6V4.6c-3.8-.4-6.8 0-9 1.6zM12 6.2v13.2"/>'),
};
