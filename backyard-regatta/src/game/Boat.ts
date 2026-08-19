import * as THREE from 'three';

interface HullStation {
  z: number;
  width: number;
  sheer: number;
  depth: number;
}

const HULL_STATIONS: HullStation[] = [
  { z: -1.78, width: 0.52, sheer: 0.34, depth: 0.56 },
  { z: -1.45, width: 0.7, sheer: 0.36, depth: 0.65 },
  { z: -0.75, width: 0.82, sheer: 0.39, depth: 0.72 },
  { z: 0.1, width: 0.84, sheer: 0.43, depth: 0.74 },
  { z: 0.92, width: 0.7, sheer: 0.47, depth: 0.66 },
  { z: 1.58, width: 0.47, sheer: 0.5, depth: 0.53 },
  { z: 2.05, width: 0.2, sheer: 0.48, depth: 0.35 },
  { z: 2.28, width: 0.025, sheer: 0.42, depth: 0.14 },
];

function createHullGeometry(): THREE.BufferGeometry {
  const geometry = new THREE.BufferGeometry();
  const crossSegments = 12;
  const positions: number[] = [];
  const uvs: number[] = [];
  const indices: number[] = [];

  HULL_STATIONS.forEach((station, stationIndex) => {
    for (let segment = 0; segment <= crossSegments; segment += 1) {
      const theta = Math.PI - (segment / crossSegments) * Math.PI;
      const breadth = Math.cos(theta) * station.width;
      const roundness = Math.pow(Math.sin(theta), 0.78);
      const chine = 0.055 * Math.sin(theta * 2) * Math.sin(theta);
      positions.push(breadth, station.sheer - station.depth * roundness + chine, station.z);
      uvs.push(segment / crossSegments, stationIndex / (HULL_STATIONS.length - 1));
    }
  });

  const row = crossSegments + 1;
  for (let station = 0; station < HULL_STATIONS.length - 1; station += 1) {
    for (let segment = 0; segment < crossSegments; segment += 1) {
      const a = station * row + segment;
      const b = (station + 1) * row + segment;
      const c = b + 1;
      const d = a + 1;
      indices.push(a, c, b, a, d, c);
    }
  }

  const sternCenter = positions.length / 3;
  positions.push(0, 0.04, HULL_STATIONS[0].z - 0.012);
  uvs.push(0.5, 0);
  for (let segment = 0; segment < crossSegments; segment += 1) {
    indices.push(sternCenter, segment + 1, segment);
  }

  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

function createDeckGeometry(): THREE.BufferGeometry {
  const geometry = new THREE.BufferGeometry();
  const positions: number[] = [];
  const uvs: number[] = [];
  const indices: number[] = [];

  HULL_STATIONS.forEach((station, index) => {
    const insetWidth = Math.max(0.018, station.width - 0.045);
    positions.push(-insetWidth, station.sheer + 0.012, station.z);
    positions.push(0, station.sheer + 0.075 - Math.abs(index - 3) * 0.004, station.z);
    positions.push(insetWidth, station.sheer + 0.012, station.z);
    uvs.push(0, index / (HULL_STATIONS.length - 1));
    uvs.push(0.5, index / (HULL_STATIONS.length - 1));
    uvs.push(1, index / (HULL_STATIONS.length - 1));
  });

  for (let station = 0; station < HULL_STATIONS.length - 1; station += 1) {
    for (let strip = 0; strip < 2; strip += 1) {
      const a = station * 3 + strip;
      const b = (station + 1) * 3 + strip;
      const c = b + 1;
      const d = a + 1;
      indices.push(a, b, c, a, c, d);
    }
  }

  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

function createMainSailGeometry(): THREE.BufferGeometry {
  const geometry = new THREE.BufferGeometry();
  const rows = 9;
  const columns = 7;
  const positions: number[] = [];
  const uvs: number[] = [];
  const indices: number[] = [];

  for (let row = 0; row <= rows; row += 1) {
    const v = row / rows;
    const chord = 0.045 + 2.18 * Math.pow(1 - v, 0.94);
    for (let column = 0; column <= columns; column += 1) {
      const u = column / columns;
      const camber = Math.sin(Math.PI * u) * Math.sin(Math.PI * v) * 0.075;
      positions.push(camber, 0.12 + v * 4.3, -0.03 - chord * u);
      uvs.push(u, v);
    }
  }

  const stride = columns + 1;
  for (let row = 0; row < rows; row += 1) {
    for (let column = 0; column < columns; column += 1) {
      const a = row * stride + column;
      const b = a + stride;
      const c = b + 1;
      const d = a + 1;
      indices.push(a, b, c, a, c, d);
    }
  }

  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

function createJibGeometry(): THREE.BufferGeometry {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute(
    'position',
    new THREE.Float32BufferAttribute([
      0, 0.77, 1.93,
      0, 4.35, 0.58,
      0, 1.02, 0.53,
      0.065, 2.05, 1.02,
    ], 3),
  );
  geometry.setAttribute(
    'uv',
    new THREE.Float32BufferAttribute([
      0, 0,
      0.16, 1,
      0.28, 0.08,
      0.14, 0.42,
    ], 2),
  );
  geometry.setIndex([0, 1, 3, 1, 2, 3, 2, 0, 3]);
  geometry.computeVertexNormals();
  return geometry;
}

function createFoilGeometry(width: number, height: number, depth: number): THREE.ExtrudeGeometry {
  const shape = new THREE.Shape();
  shape.moveTo(-width * 0.48, height * 0.48);
  shape.quadraticCurveTo(-width * 0.58, 0, -width * 0.28, -height * 0.5);
  shape.quadraticCurveTo(width * 0.35, -height * 0.47, width * 0.5, height * 0.42);
  shape.quadraticCurveTo(0, height * 0.52, -width * 0.48, height * 0.48);
  const geometry = new THREE.ExtrudeGeometry(shape, {
    depth,
    bevelEnabled: true,
    bevelSegments: 2,
    bevelSize: Math.min(depth * 0.3, 0.018),
    bevelThickness: Math.min(depth * 0.3, 0.018),
    curveSegments: 8,
  });
  geometry.center();
  geometry.rotateY(Math.PI / 2);
  return geometry;
}

function railGeometry(side: -1 | 1, waterline = false): THREE.TubeGeometry {
  const points = HULL_STATIONS.slice(0, -1).map((station) => {
    const x = station.width * side * (waterline ? 0.78 : 1);
    const y = waterline ? station.sheer - station.depth * 0.45 : station.sheer + 0.015;
    return new THREE.Vector3(x, y, station.z);
  });
  points.push(new THREE.Vector3(0, waterline ? 0.34 : 0.435, 2.27));
  return new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points), 30, waterline ? 0.014 : 0.022, 5, false);
}

function cockpitRingGeometry(): THREE.ShapeGeometry {
  const shape = new THREE.Shape();
  shape.absellipse(0, 0, 0.46, 0.73, 0, Math.PI * 2, false);
  const hole = new THREE.Path();
  hole.absellipse(0, 0, 0.365, 0.625, 0, Math.PI * 2, true);
  shape.holes.push(hole);
  return new THREE.ShapeGeometry(shape, 32);
}

function cylinderBetween(
  start: THREE.Vector3,
  end: THREE.Vector3,
  radius: number,
  material: THREE.Material,
  radialSegments = 6,
): THREE.Mesh {
  const direction = end.clone().sub(start);
  const mesh = new THREE.Mesh(new THREE.CylinderGeometry(radius, radius, 1, radialSegments), material);
  mesh.position.copy(start).add(end).multiplyScalar(0.5);
  mesh.scale.y = direction.length();
  mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), direction.normalize());
  return mesh;
}

function paintSail(canvas: HTMLCanvasElement, color: string, sailNumber: number): void {
  const context = canvas.getContext('2d');
  if (!context) return;
  const size = canvas.width;
  context.clearRect(0, 0, size, size);

  const cloth = context.createLinearGradient(0, 0, size, size);
  cloth.addColorStop(0, '#fffdf3');
  cloth.addColorStop(0.48, '#eee9d9');
  cloth.addColorStop(1, '#faf6e7');
  context.fillStyle = cloth;
  context.fillRect(0, 0, size, size);

  context.lineWidth = 1;
  for (let offset = 0; offset < size; offset += 8) {
    context.strokeStyle = offset % 32 === 0 ? 'rgba(87,99,98,.12)' : 'rgba(87,99,98,.045)';
    context.beginPath();
    context.moveTo(offset, 0);
    context.lineTo(offset, size);
    context.stroke();
    context.beginPath();
    context.moveTo(0, offset);
    context.lineTo(size, offset);
    context.stroke();
  }

  context.strokeStyle = 'rgba(72,84,85,.26)';
  context.lineWidth = 2;
  for (const y of [118, 215, 310, 402]) {
    context.beginPath();
    context.moveTo(0, y + 16);
    context.lineTo(size, y - 18);
    context.stroke();
  }

  for (let index = 0; index < 34; index += 1) {
    const x = (Math.sin(index * 91.7 + sailNumber * 3.1) * 0.5 + 0.5) * size;
    const y = (Math.sin(index * 47.3 + sailNumber * 8.4) * 0.5 + 0.5) * size;
    const radius = 2 + (index % 5) * 0.8;
    context.fillStyle = `rgba(78,82,72,${0.012 + (index % 4) * 0.006})`;
    context.beginPath();
    context.ellipse(x, y, radius * 1.8, radius, index * 0.7, 0, Math.PI * 2);
    context.fill();
  }

  context.fillStyle = color;
  context.fillRect(0, 423, size, 13);
  context.fillStyle = 'rgba(255,255,255,.94)';
  context.fillRect(0, 427, size, 2);

  context.fillStyle = '#233c43';
  context.textAlign = 'center';
  context.textBaseline = 'middle';
  context.font = '700 116px Arial Narrow, sans-serif';
  context.fillText(String(sailNumber), 270, 226);
  context.font = '700 18px Arial, sans-serif';
  context.letterSpacing = '3px';
  context.fillText('PUDDLE CUP', 273, 300);
}

function createSailBumpTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 128;
  const context = canvas.getContext('2d');
  if (context) {
    context.fillStyle = '#808080';
    context.fillRect(0, 0, 128, 128);
    context.lineWidth = 1;
    for (let offset = 0; offset < 128; offset += 4) {
      context.strokeStyle = offset % 16 === 0 ? '#9a9a9a' : '#898989';
      context.beginPath();
      context.moveTo(offset, 0);
      context.lineTo(offset, 128);
      context.stroke();
      context.strokeStyle = offset % 16 === 0 ? '#747474' : '#7c7c7c';
      context.beginPath();
      context.moveTo(0, offset);
      context.lineTo(128, offset);
      context.stroke();
    }
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.set(2.5, 2.5);
  texture.anisotropy = 4;
  return texture;
}

function createWakeTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 64;
  canvas.height = 512;
  const context = canvas.getContext('2d');
  if (context) {
    const fade = context.createLinearGradient(0, 0, 0, 512);
    fade.addColorStop(0, 'rgba(240,253,255,0)');
    fade.addColorStop(0.28, 'rgba(240,253,255,.16)');
    fade.addColorStop(0.72, 'rgba(240,253,255,.72)');
    fade.addColorStop(1, 'rgba(255,255,255,.96)');
    context.fillStyle = fade;
    context.fillRect(0, 0, 64, 512);

    for (let i = 0; i < 115; i += 1) {
      const y = 130 + ((i * 71) % 375);
      const x = 8 + ((i * 29) % 48);
      const alpha = 0.08 + ((i * 13) % 16) / 100;
      context.fillStyle = `rgba(255,255,255,${alpha})`;
      context.beginPath();
      context.ellipse(x, y, 1 + (i % 4), 2 + (i % 7), 0, 0, Math.PI * 2);
      context.fill();
    }

    context.globalCompositeOperation = 'destination-in';
    const feather = context.createLinearGradient(0, 0, 64, 0);
    feather.addColorStop(0, 'rgba(255,255,255,0)');
    feather.addColorStop(0.28, 'rgba(255,255,255,.14)');
    feather.addColorStop(0.5, 'rgba(255,255,255,.88)');
    feather.addColorStop(0.72, 'rgba(255,255,255,.14)');
    feather.addColorStop(1, 'rgba(255,255,255,0)');
    context.fillStyle = feather;
    context.fillRect(0, 0, 64, 512);
    context.globalCompositeOperation = 'source-over';
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapT = THREE.RepeatWrapping;
  texture.repeat.y = 1.35;
  return texture;
}

function createShadowTexture(): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  if (context) {
    const gradient = context.createRadialGradient(64, 128, 8, 64, 128, 105);
    gradient.addColorStop(0, 'rgba(10,35,43,.55)');
    gradient.addColorStop(0.48, 'rgba(10,35,43,.28)');
    gradient.addColorStop(1, 'rgba(10,35,43,0)');
    context.fillStyle = gradient;
    context.fillRect(0, 0, 128, 256);
  }
  return new THREE.CanvasTexture(canvas);
}

const sharedHullGeometry = createHullGeometry();
const sharedDeckGeometry = createDeckGeometry();
const sharedMainSailGeometry = createMainSailGeometry();
const sharedJibGeometry = createJibGeometry();
const sharedRudderGeometry = createFoilGeometry(0.48, 0.74, 0.065);
const sharedKeelGeometry = createFoilGeometry(0.66, 1.12, 0.075);
const sharedRubRails = [railGeometry(-1), railGeometry(1)];
const sharedWaterlines = [railGeometry(-1, true), railGeometry(1, true)];
const sharedCockpitRing = cockpitRingGeometry();
const sharedWakeTexture = createWakeTexture();
const sharedShadowTexture = createShadowTexture();
const sharedSailBumpTexture = createSailBumpTexture();

const deckMaterial = new THREE.MeshPhysicalMaterial({
  color: 0xf2eee2,
  roughness: 0.34,
  metalness: 0,
  clearcoat: 0.72,
  clearcoatRoughness: 0.25,
});
const cockpitMaterial = new THREE.MeshStandardMaterial({ color: 0x132c32, roughness: 0.38 });
const carbonMaterial = new THREE.MeshStandardMaterial({ color: 0x222b2e, roughness: 0.25, metalness: 0.4 });
const ropeMaterial = new THREE.MeshStandardMaterial({ color: 0x5a6767, roughness: 0.7 });
const brightMetalMaterial = new THREE.MeshStandardMaterial({ color: 0xcbd5d2, roughness: 0.18, metalness: 0.9 });
const trimMaterial = new THREE.MeshPhysicalMaterial({
  color: 0xf7f3e8,
  roughness: 0.3,
  clearcoat: 0.65,
  clearcoatRoughness: 0.22,
});
const darkFoilMaterial = new THREE.MeshPhysicalMaterial({ color: 0x333a3a, roughness: 0.24, clearcoat: 0.55 });

export class Boat {
  readonly root = new THREE.Group();
  readonly model = new THREE.Group();
  readonly hullMaterial: THREE.MeshPhysicalMaterial;
  readonly sailMaterial: THREE.MeshPhysicalMaterial;
  readonly ribbon: THREE.Mesh;
  readonly shadow: THREE.Mesh;
  private readonly sailPivot = new THREE.Group();
  private readonly rudder: THREE.Mesh;
  private readonly wakeLeft: THREE.Mesh;
  private readonly wakeRight: THREE.Mesh;
  private readonly bowWake: THREE.Mesh;
  private readonly wakeTexture: THREE.Texture;
  private readonly sailCanvas = document.createElement('canvas');
  private readonly sailNumber: number;
  private readonly jib: THREE.Mesh;
  private color = new THREE.Color();

  constructor(color: string, readonly name: string, sailNumber: number) {
    this.root.name = `boat-${name.toLowerCase()}`;
    this.root.add(this.model);
    this.color.set(color);
    this.sailNumber = sailNumber;

    this.hullMaterial = new THREE.MeshPhysicalMaterial({
      color,
      roughness: 0.2,
      metalness: 0,
      clearcoat: 1,
      clearcoatRoughness: 0.1,
      reflectivity: 0.72,
    });
    const hull = new THREE.Mesh(sharedHullGeometry, this.hullMaterial);
    hull.castShadow = true;
    hull.receiveShadow = true;
    this.model.add(hull);

    const deck = new THREE.Mesh(sharedDeckGeometry, deckMaterial);
    deck.castShadow = true;
    deck.receiveShadow = true;
    this.model.add(deck);

    for (const geometry of sharedRubRails) {
      const rail = new THREE.Mesh(geometry, trimMaterial);
      rail.castShadow = true;
      this.model.add(rail);
    }
    for (const geometry of sharedWaterlines) this.model.add(new THREE.Mesh(geometry, trimMaterial));

    const cockpitWell = new THREE.Mesh(new THREE.CircleGeometry(1, 32), cockpitMaterial);
    cockpitWell.scale.set(0.36, 0.61, 1);
    cockpitWell.rotation.x = -Math.PI / 2;
    cockpitWell.position.set(0, 0.49, -0.64);
    this.model.add(cockpitWell);

    const cockpitRing = new THREE.Mesh(sharedCockpitRing, trimMaterial);
    cockpitRing.rotation.x = -Math.PI / 2;
    cockpitRing.position.set(0, 0.505, -0.64);
    cockpitRing.castShadow = true;
    this.model.add(cockpitRing);

    const radioCover = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.34, 0.07, 24), deckMaterial);
    radioCover.scale.z = 0.72;
    radioCover.position.set(0, 0.55, 0.85);
    radioCover.castShadow = true;
    this.model.add(radioCover);

    const coverSeal = new THREE.Mesh(new THREE.TorusGeometry(0.325, 0.013, 5, 24), cockpitMaterial);
    coverSeal.scale.z = 0.72;
    coverSeal.rotation.x = Math.PI / 2;
    coverSeal.position.set(0, 0.59, 0.85);
    this.model.add(coverSeal);

    const switchBoot = new THREE.Mesh(new THREE.SphereGeometry(0.045, 10, 7), cockpitMaterial);
    switchBoot.position.set(0.22, 0.61, 0.66);
    this.model.add(switchBoot);

    const mast = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.047, 4.75, 10), carbonMaterial);
    mast.position.set(0, 2.88, 0.5);
    mast.castShadow = true;
    this.model.add(mast);

    const mastCollar = new THREE.Mesh(new THREE.TorusGeometry(0.09, 0.018, 6, 18), brightMetalMaterial);
    mastCollar.rotation.x = Math.PI / 2;
    mastCollar.position.set(0, 0.54, 0.5);
    this.model.add(mastCollar);

    this.sailCanvas.width = 512;
    this.sailCanvas.height = 512;
    paintSail(this.sailCanvas, color, sailNumber);
    const sailTexture = new THREE.CanvasTexture(this.sailCanvas);
    sailTexture.colorSpace = THREE.SRGBColorSpace;
    sailTexture.anisotropy = 4;
    this.sailMaterial = new THREE.MeshPhysicalMaterial({
      color: 0xffffff,
      map: sailTexture,
      roughness: 0.76,
      metalness: 0,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: 0.96,
      transmission: 0,
      clearcoat: 0.08,
      clearcoatRoughness: 0.7,
      sheen: 0.32,
      sheenColor: new THREE.Color('#fff8df'),
      sheenRoughness: 0.82,
      bumpMap: sharedSailBumpTexture,
      bumpScale: 0.018,
      envMapIntensity: 0.5,
      alphaTest: 0.01,
    });

    this.sailPivot.position.set(0, 0.59, 0.5);
    this.model.add(this.sailPivot);
    const mainSail = new THREE.Mesh(sharedMainSailGeometry, this.sailMaterial);
    mainSail.castShadow = true;
    this.sailPivot.add(mainSail);

    const boom = new THREE.Mesh(new THREE.CylinderGeometry(0.027, 0.038, 2.28, 8), carbonMaterial);
    boom.rotation.x = Math.PI / 2;
    boom.position.set(0, 0.19, -1.1);
    boom.castShadow = true;
    this.sailPivot.add(boom);

    const gooseneck = new THREE.Mesh(new THREE.SphereGeometry(0.065, 10, 8), brightMetalMaterial);
    gooseneck.position.set(0, 0.19, -0.015);
    this.sailPivot.add(gooseneck);

    const vang = cylinderBetween(
      new THREE.Vector3(0, 0.04, -0.06),
      new THREE.Vector3(0, 0.19, -0.58),
      0.012,
      ropeMaterial,
      5,
    );
    this.sailPivot.add(vang);

    this.jib = new THREE.Mesh(sharedJibGeometry, this.sailMaterial);
    this.jib.castShadow = true;
    this.model.add(this.jib);

    const rigging = [
      [new THREE.Vector3(0, 5.18, 0.5), new THREE.Vector3(0, 0.54, 2.2)],
      [new THREE.Vector3(0, 5.18, 0.5), new THREE.Vector3(0, 0.45, -1.68)],
      [new THREE.Vector3(0, 4.55, 0.5), new THREE.Vector3(-0.73, 0.48, 0.12)],
      [new THREE.Vector3(0, 4.55, 0.5), new THREE.Vector3(0.73, 0.48, 0.12)],
    ];
    for (const [start, end] of rigging) this.model.add(cylinderBetween(start, end, 0.008, ropeMaterial, 5));

    const bowEye = new THREE.Mesh(new THREE.TorusGeometry(0.055, 0.012, 5, 12), brightMetalMaterial);
    bowEye.rotation.x = Math.PI / 2;
    bowEye.position.set(0, 0.53, 2.11);
    this.model.add(bowEye);

    for (const x of [-0.23, 0.23]) {
      const cleat = new THREE.Mesh(new THREE.CapsuleGeometry(0.025, 0.085, 3, 6), brightMetalMaterial);
      cleat.rotation.z = Math.PI / 2;
      cleat.position.set(x, 0.5, -1.38);
      this.model.add(cleat);
    }

    const tiller = cylinderBetween(
      new THREE.Vector3(0, 0.33, -1.72),
      new THREE.Vector3(0, 0.54, -0.92),
      0.025,
      carbonMaterial,
      7,
    );
    this.model.add(tiller);

    this.rudder = new THREE.Mesh(sharedRudderGeometry, darkFoilMaterial);
    this.rudder.position.set(0, -0.08, -1.75);
    this.rudder.castShadow = true;
    this.model.add(this.rudder);

    const keel = new THREE.Mesh(sharedKeelGeometry, darkFoilMaterial);
    keel.position.set(0, -0.77, 0.12);
    keel.castShadow = true;
    this.model.add(keel);

    const ballast = new THREE.Mesh(new THREE.CapsuleGeometry(0.105, 0.72, 5, 12), darkFoilMaterial);
    ballast.rotation.x = Math.PI / 2;
    ballast.position.set(0, -1.34, 0.2);
    ballast.castShadow = true;
    this.model.add(ballast);

    const ribbonMaterial = new THREE.MeshPhysicalMaterial({
      color: 0xef4b3f,
      roughness: 0.82,
      side: THREE.DoubleSide,
    });
    this.ribbon = new THREE.Mesh(new THREE.PlaneGeometry(0.68, 0.065, 5, 1), ribbonMaterial);
    this.ribbon.geometry.translate(0.34, 0, 0);
    this.ribbon.position.set(0, 5.29, 0.5);
    this.model.add(this.ribbon);

    this.wakeTexture = sharedWakeTexture.clone();
    this.wakeTexture.needsUpdate = true;
    const wakeMaterial = new THREE.MeshBasicMaterial({
      color: 0xdce8e4,
      map: this.wakeTexture,
      transparent: true,
      opacity: 0,
      depthWrite: false,
      blending: THREE.NormalBlending,
      side: THREE.DoubleSide,
    });
    this.wakeLeft = new THREE.Mesh(new THREE.PlaneGeometry(0.18, 5.2), wakeMaterial.clone());
    this.wakeRight = new THREE.Mesh(new THREE.PlaneGeometry(0.18, 5.2), wakeMaterial.clone());
    for (const [wake, x] of [[this.wakeLeft, -0.46], [this.wakeRight, 0.46]] as const) {
      wake.rotation.x = -Math.PI / 2;
      wake.rotation.z = x < 0 ? -0.12 : 0.12;
      wake.position.set(x, -0.245, -3.25);
      wake.renderOrder = 2;
      this.root.add(wake);
    }

    const bowWakeMaterial = wakeMaterial.clone();
    this.bowWake = new THREE.Mesh(new THREE.RingGeometry(0.72, 0.84, 30, 1, 0.12, Math.PI - 0.24), bowWakeMaterial);
    this.bowWake.rotation.x = -Math.PI / 2;
    this.bowWake.rotation.z = Math.PI / 2;
    this.bowWake.scale.set(1, 1.7, 1);
    this.bowWake.position.set(0, -0.24, 1.74);
    this.bowWake.renderOrder = 2;
    this.root.add(this.bowWake);

    this.shadow = new THREE.Mesh(
      new THREE.PlaneGeometry(2.35, 4.7),
      new THREE.MeshBasicMaterial({
        map: sharedShadowTexture,
        color: 0x102f39,
        transparent: true,
        opacity: 0.12,
        depthWrite: false,
      }),
    );
    this.shadow.rotation.x = -Math.PI / 2;
    this.shadow.position.y = -0.34;
    this.root.add(this.shadow);
  }

  setColor(color: string): void {
    this.color.set(color);
    this.hullMaterial.color.copy(this.color);
    paintSail(this.sailCanvas, color, this.sailNumber);
    if (this.sailMaterial.map) this.sailMaterial.map.needsUpdate = true;
  }

  updateVisual(time: number, turn: number, speed: number, trim: number, windAngle: number): void {
    const speedRatio = THREE.MathUtils.clamp(speed / 9.4, 0, 1);
    const waveRoll = Math.sin(time * 2.4 + this.root.position.x * 0.11) * 0.015;
    const wavePitch = Math.sin(time * 1.9 + this.root.position.z * 0.09) * 0.021;
    this.model.rotation.z = THREE.MathUtils.lerp(this.model.rotation.z, -turn * 0.17 + waveRoll, 0.12);
    this.model.rotation.x = THREE.MathUtils.lerp(this.model.rotation.x, wavePitch - speedRatio * 0.015, 0.08);
    this.sailPivot.rotation.y = THREE.MathUtils.lerp(
      this.sailPivot.rotation.y,
      Math.sign(windAngle || 1) * (0.12 + trim * 0.95),
      0.08,
    );
    this.rudder.rotation.y = THREE.MathUtils.lerp(this.rudder.rotation.y, -turn * 0.5, 0.18);
    this.ribbon.rotation.y = -windAngle + Math.PI / 2;
    this.ribbon.rotation.z = Math.sin(time * 11 + this.root.position.x) * 0.07 * (0.35 + speedRatio * 0.65);

    const wakeOpacity = THREE.MathUtils.clamp((speed - 0.8) / 7.4, 0, 0.34);
    (this.wakeLeft.material as THREE.MeshBasicMaterial).opacity = wakeOpacity;
    (this.wakeRight.material as THREE.MeshBasicMaterial).opacity = wakeOpacity;
    (this.bowWake.material as THREE.MeshBasicMaterial).opacity = wakeOpacity * 0.9;
    this.wakeTexture.offset.y = -((time * (0.2 + speedRatio * 0.42)) % 1);
    this.wakeLeft.scale.set(0.78 + speedRatio * 0.62, 0.72 + speedRatio * 1.16, 1);
    this.wakeRight.scale.set(0.78 + speedRatio * 0.62, 0.72 + speedRatio * 1.16, 1);
    this.bowWake.scale.set(0.88 + speedRatio * 0.44, 1.45 + speedRatio * 0.92, 1);
  }
}
