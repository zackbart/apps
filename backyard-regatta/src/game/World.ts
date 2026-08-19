import * as THREE from 'three';
import backyardPanoramaUrl from '../assets/backyard-panorama.webp';

export interface CoursePoint { x: number; z: number }
export interface GustZone { x: number; z: number; radius: number; phase: number }
export interface Obstacle { x: number; z: number; radius: number }

interface RainRipple {
  x: number;
  z: number;
  phase: number;
  size: number;
}

export const COURSE: CoursePoint[] = [
  { x: -21.5, z: -16 },
  { x: 2, z: -28 },
  { x: 25.5, z: -14 },
  { x: 25.5, z: 13 },
  { x: 2, z: 25.5 },
  { x: -24.5, z: 12.5 },
];

export function waterHeight(x: number, z: number, time: number): number {
  return (
    Math.sin(x * 0.18 + time * 1.45) * 0.095 +
    Math.sin(z * 0.23 - time * 1.12) * 0.07 +
    Math.sin((x + z) * 0.1 + time * 0.72) * 0.055
  );
}

function seeded(index: number): number {
  const value = Math.sin(index * 91.731 + 14.17) * 43758.5453;
  return value - Math.floor(value);
}

function canvasTexture(
  width: number,
  height: number,
  draw: (context: CanvasRenderingContext2D, width: number, height: number) => void,
): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (context) draw(context, width, height);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = 4;
  return texture;
}

function createGrainTexture(): THREE.CanvasTexture {
  const texture = canvasTexture(256, 256, (context, width, height) => {
    context.fillStyle = '#99978b';
    context.fillRect(0, 0, width, height);
    for (let index = 0; index < 5200; index += 1) {
      const shade = 92 + Math.floor(seeded(index + 100) * 90);
      context.fillStyle = `rgba(${shade},${shade + 2},${shade - 5},${0.06 + seeded(index + 700) * 0.15})`;
      const size = 0.5 + seeded(index + 1200) * 2.2;
      context.fillRect(seeded(index + 2300) * width, seeded(index + 3600) * height, size, size);
    }
  });
  texture.repeat.set(14, 10);
  return texture;
}

function createWoodTexture(): THREE.CanvasTexture {
  return canvasTexture(256, 512, (context, width, height) => {
    const base = context.createLinearGradient(0, 0, width, 0);
    base.addColorStop(0, '#796956');
    base.addColorStop(0.45, '#a08b70');
    base.addColorStop(1, '#6f604f');
    context.fillStyle = base;
    context.fillRect(0, 0, width, height);

    for (let index = 0; index < 185; index += 1) {
      const x = seeded(index + 30) * width;
      const bend = (seeded(index + 130) - 0.5) * 22;
      context.strokeStyle = `rgba(${45 + Math.floor(seeded(index + 90) * 35)},${39 + Math.floor(seeded(index + 190) * 27)},${30 + Math.floor(seeded(index + 290) * 24)},${0.08 + seeded(index + 390) * 0.16})`;
      context.lineWidth = 0.35 + seeded(index + 490) * 1.25;
      context.beginPath();
      context.moveTo(x, 0);
      context.bezierCurveTo(x + bend, height * 0.3, x - bend * 0.5, height * 0.7, x + bend * 0.25, height);
      context.stroke();
    }
    for (let index = 0; index < 10; index += 1) {
      const x = seeded(index + 710) * width;
      const y = seeded(index + 810) * height;
      context.fillStyle = 'rgba(45,38,30,.42)';
      context.beginPath();
      context.ellipse(x, y, 3 + seeded(index + 910) * 7, 1.5 + seeded(index + 1010) * 2.5, seeded(index + 1110), 0, Math.PI * 2);
      context.fill();
    }
    const wet = context.createLinearGradient(0, height * 0.64, 0, height);
    wet.addColorStop(0, 'rgba(30,38,34,0)');
    wet.addColorStop(1, 'rgba(24,35,32,.5)');
    context.fillStyle = wet;
    context.fillRect(0, height * 0.64, width, height * 0.36);
  });
}

function createSidingTexture(): THREE.CanvasTexture {
  const texture = canvasTexture(512, 256, (context, width, height) => {
    context.fillStyle = '#c1c1b8';
    context.fillRect(0, 0, width, height);
    for (let y = 0; y < height; y += 17) {
      context.fillStyle = 'rgba(52,58,56,.28)';
      context.fillRect(0, y, width, 2);
      context.fillStyle = 'rgba(255,255,242,.2)';
      context.fillRect(0, y + 2, width, 2);
    }
    for (let index = 0; index < 460; index += 1) {
      const alpha = 0.025 + seeded(index + 80) * 0.06;
      context.fillStyle = `rgba(50,55,51,${alpha})`;
      context.fillRect(seeded(index + 300) * width, seeded(index + 900) * height, 1, 2 + seeded(index + 1200) * 10);
    }
  });
  texture.repeat.set(4, 4);
  return texture;
}

function createEnvironmentTexture(): THREE.CanvasTexture {
  const texture = canvasTexture(1024, 512, (context, width, height) => {
    const sky = context.createLinearGradient(0, 0, 0, height);
    sky.addColorStop(0, '#557889');
    sky.addColorStop(0.42, '#91adb5');
    sky.addColorStop(0.64, '#d9d3bb');
    sky.addColorStop(0.72, '#7c8c79');
    sky.addColorStop(1, '#26352f');
    context.fillStyle = sky;
    context.fillRect(0, 0, width, height);

    for (let index = 0; index < 58; index += 1) {
      const x = seeded(index + 620) * width;
      const y = 80 + seeded(index + 720) * 170;
      const radiusX = 22 + seeded(index + 820) * 75;
      const radiusY = 5 + seeded(index + 920) * 16;
      context.fillStyle = `rgba(225,229,221,${0.025 + seeded(index + 1020) * 0.09})`;
      context.beginPath();
      context.ellipse(x, y, radiusX, radiusY, seeded(index + 1120) * 0.2, 0, Math.PI * 2);
      context.fill();
    }
    const sun = context.createRadialGradient(185, 210, 0, 185, 210, 78);
    sun.addColorStop(0, 'rgba(255,244,198,.95)');
    sun.addColorStop(0.08, 'rgba(255,224,156,.55)');
    sun.addColorStop(1, 'rgba(255,214,150,0)');
    context.fillStyle = sun;
    context.fillRect(100, 125, 170, 170);
  });
  texture.mapping = THREE.EquirectangularReflectionMapping;
  texture.wrapS = THREE.ClampToEdgeWrapping;
  texture.wrapT = THREE.ClampToEdgeWrapping;
  return texture;
}

function createFoliageTexture(): THREE.CanvasTexture {
  const texture = canvasTexture(256, 256, (context, width, height) => {
    context.clearRect(0, 0, width, height);
    for (let index = 0; index < 760; index += 1) {
      const angle = seeded(index + 6100) * Math.PI * 2;
      const radius = Math.pow(seeded(index + 6200), 0.62);
      const x = width / 2 + Math.cos(angle) * radius * width * 0.43;
      const y = height / 2 + Math.sin(angle) * radius * height * 0.36;
      const leafSize = 2.2 + seeded(index + 6300) * 6.4;
      const light = 26 + Math.floor(seeded(index + 6400) * 24);
      const green = 54 + Math.floor(seeded(index + 6500) * 38);
      const blue = 31 + Math.floor(seeded(index + 6600) * 19);
      const edgeFade = Math.max(0.18, 1 - Math.pow(radius, 2.7));
      context.fillStyle = `rgba(${light},${green},${blue},${0.5 + edgeFade * 0.48})`;
      context.beginPath();
      context.ellipse(x, y, leafSize * 1.5, leafSize * 0.65, angle + seeded(index + 6700) * 1.4, 0, Math.PI * 2);
      context.fill();
    }
    for (let index = 0; index < 95; index += 1) {
      const x = 34 + seeded(index + 6800) * 188;
      const y = 54 + seeded(index + 6900) * 150;
      context.fillStyle = 'rgba(190,205,168,.14)';
      context.beginPath();
      context.ellipse(x, y, 1.2 + seeded(index + 7000) * 2.2, 0.7 + seeded(index + 7100), seeded(index + 7200) * Math.PI, 0, Math.PI * 2);
      context.fill();
    }
  });
  texture.wrapS = THREE.ClampToEdgeWrapping;
  texture.wrapT = THREE.ClampToEdgeWrapping;
  texture.anisotropy = 4;
  return texture;
}

function createWaterNormalMap(size = 256): THREE.DataTexture {
  const heights = new Float32Array(size * size);
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const broad = Math.sin(x * 0.093 + y * 0.041) * 0.34
        + Math.sin(x * -0.052 + y * 0.121) * 0.25
        + Math.sin(x * 0.18 - y * 0.073) * 0.12
        + Math.sin(x * 0.31 + y * 0.27) * 0.045
        + Math.sin(x * 0.47 - y * 0.38) * 0.025;
      heights[y * size + x] = broad;
    }
  }
  const pixels = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const left = heights[y * size + (x + size - 1) % size];
      const right = heights[y * size + (x + 1) % size];
      const down = heights[((y + size - 1) % size) * size + x];
      const up = heights[((y + 1) % size) * size + x];
      const normal = new THREE.Vector3((left - right) * 1.28, (down - up) * 1.28, 1).normalize();
      const offset = (y * size + x) * 4;
      pixels[offset] = Math.round((normal.x * 0.5 + 0.5) * 255);
      pixels[offset + 1] = Math.round((normal.y * 0.5 + 0.5) * 255);
      pixels[offset + 2] = Math.round((normal.z * 0.5 + 0.5) * 255);
      pixels[offset + 3] = 255;
    }
  }
  const texture = new THREE.DataTexture(pixels, size, size, THREE.RGBAFormat);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.anisotropy = 8;
  texture.needsUpdate = true;
  return texture;
}

function createWater(): { mesh: THREE.Mesh; material: THREE.ShaderMaterial | THREE.MeshPhysicalMaterial } {
  {
    const geometry = new THREE.PlaneGeometry(138, 112, 96, 80);
    const position = geometry.attributes.position;
    const colors: number[] = [];
    const deep = new THREE.Color('#314b4c');
    const silt = new THREE.Color('#716451');
    for (let index = 0; index < position.count; index += 1) {
      const edge = Math.max(Math.abs(position.getX(index)) / 69, Math.abs(position.getY(index)) / 56);
      const tone = deep.clone().lerp(silt, THREE.MathUtils.smoothstep(edge, 0.54, 0.98) * 0.82);
      colors.push(tone.r, tone.g, tone.b);
    }
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));

    const normalMap = createWaterNormalMap();
    normalMap.repeat.set(7, 6);
    const timeUniform = { value: 0 };
    const material = new THREE.MeshPhysicalMaterial({
      color: 0xffffff,
      vertexColors: true,
      roughness: 0.18,
      metalness: 0,
      clearcoat: 0.48,
      clearcoatRoughness: 0.14,
      ior: 1.333,
      envMapIntensity: 0.95,
      normalMap,
      normalScale: new THREE.Vector2(0.52, 0.52),
    });
    material.userData.waterTime = timeUniform;
    material.onBeforeCompile = (shader) => {
      shader.uniforms.uTime = timeUniform;
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', `
          #include <common>
          uniform float uTime;
          float puddleWave(vec2 p) {
            return sin(p.x * .18 + uTime * 1.45) * .095
              + sin(p.y * .23 - uTime * 1.12) * .07
              + sin((p.x + p.y) * .10 + uTime * .72) * .055;
          }
        `)
        .replace('#include <begin_vertex>', `
          vec3 transformed = vec3(position);
          transformed.z += puddleWave(vec2(position.x, -position.y));
        `);
    };
    material.customProgramCacheKey = () => 'puddle-physical-water-v1';
    const mesh = new THREE.Mesh(geometry, material);
    mesh.rotation.x = -Math.PI / 2;
    mesh.receiveShadow = true;
    mesh.renderOrder = 1;
    return { mesh, material };
  }
  const geometry = new THREE.PlaneGeometry(138, 112, 112, 92);
  const material = new THREE.ShaderMaterial({
    uniforms: {
      uTime: { value: 0 },
      uSunDirection: { value: new THREE.Vector3(-0.42, 0.76, -0.49).normalize() },
      uSunColor: { value: new THREE.Color('#ffe3a8') },
      uFogColor: { value: new THREE.Color('#a8bbc0') },
      uFogDensity: { value: 0.0062 },
    },
    vertexShader: `
      uniform float uTime;
      varying vec3 vWorld;
      varying vec3 vNormal;
      varying float vHeight;

      float waterWave(float x, float z) {
        return sin(x * .18 + uTime * 1.45) * .095
          + sin(z * .23 - uTime * 1.12) * .07
          + sin((x + z) * .10 + uTime * .72) * .055;
      }

      void main() {
        vec3 p = position;
        float worldX = p.x;
        float worldZ = -p.y;
        float height = waterWave(worldX, worldZ);
        p.z = height;

        float stepSize = .14;
        float heightX = waterWave(worldX + stepSize, worldZ);
        float heightZ = waterWave(worldX, worldZ + stepSize);
        vec3 worldNormal = normalize(vec3(-(heightX - height) / stepSize, 1.0, -(heightZ - height) / stepSize));
        vec4 world = modelMatrix * vec4(p, 1.0);
        vWorld = world.xyz;
        vNormal = normalize(mat3(modelMatrix) * vec3(worldNormal.x, worldNormal.z, worldNormal.y));
        vHeight = height;
        gl_Position = projectionMatrix * viewMatrix * world;
      }
    `,
    fragmentShader: `
      uniform float uTime;
      uniform vec3 uSunDirection;
      uniform vec3 uSunColor;
      uniform vec3 uFogColor;
      uniform float uFogDensity;
      varying vec3 vWorld;
      varying vec3 vNormal;
      varying float vHeight;

      float hash21(vec2 p) {
        p = fract(p * vec2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
      }

      float valueNoise(vec2 p) {
        vec2 cell = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
          mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
      }

      float fineRipples(vec2 p) {
        float a = sin(dot(p, normalize(vec2(.82, .57))) * 1.72 + uTime * 2.05) * .012;
        float b = sin(dot(p, normalize(vec2(-.35, .94))) * 2.48 - uTime * 1.72) * .008;
        float c = sin(dot(p, normalize(vec2(.96, -.28))) * 4.35 + uTime * 2.8) * .0035;
        return a + b + c;
      }

      vec3 reflectedSky(vec3 ray) {
        float elevation = smoothstep(-.1, .82, ray.y);
        vec3 horizon = vec3(.52, .57, .54);
        vec3 zenith = vec3(.19, .36, .43);
        vec3 sky = mix(horizon, zenith, elevation);
        float cloud = valueNoise(ray.xz * 4.2 / max(.18, abs(ray.y) + .12));
        cloud = smoothstep(.52, .78, cloud) * smoothstep(.08, .72, ray.y);
        return mix(sky, vec3(.66, .69, .66), cloud * .2);
      }

      void main() {
        vec2 p = vWorld.xz;
        float epsilon = .045;
        float fine = fineRipples(p);
        float fineX = fineRipples(p + vec2(epsilon, 0.0));
        float fineZ = fineRipples(p + vec2(0.0, epsilon));
        vec3 microNormal = vec3(-(fineX - fine) / epsilon, 0.0, -(fineZ - fine) / epsilon);
        vec3 normal = normalize(vNormal + microNormal * .72);
        vec3 viewDirection = normalize(cameraPosition - vWorld);
        float nDotV = max(dot(normal, viewDirection), 0.0);
        float fresnel = .024 + .976 * pow(1.0 - nDotV, 5.0);

        vec3 reflectionRay = reflect(-viewDirection, normal);
        vec3 reflection = reflectedSky(reflectionRay);
        float edge = max(abs(vWorld.x) / 68.0, abs(vWorld.z) / 55.0);
        float shallows = smoothstep(.48, .96, edge);
        float silt = valueNoise(p * .055 + vec2(2.7, 6.1));
        vec3 deepWater = vec3(.035, .125, .145);
        vec3 shallowWater = vec3(.13, .21, .175);
        vec3 volume = mix(deepWater, shallowWater, shallows * .8);
        volume *= .88 + silt * .16;
        volume += vec3(.02, .032, .025) * smoothstep(.08, .2, vHeight);

        float reflectionAmount = .16 + fresnel * .7;
        vec3 color = mix(volume, reflection, reflectionAmount);
        float nDotL = max(dot(normal, uSunDirection), 0.0);
        vec3 reflectedLight = reflect(-uSunDirection, normal);
        float broadSpecular = pow(max(dot(reflectedLight, viewDirection), 0.0), 115.0) * nDotL;
        float tightSpecular = pow(max(dot(reflectedLight, viewDirection), 0.0), 620.0);
        float glitterMask = step(.76, hash21(floor(p * 5.8) + floor(uTime * 5.0)));
        color += uSunColor * (broadSpecular * .54 + tightSpecular * glitterMask * 1.1);

        float sedimentRibbon = valueNoise(p * .12 + vec2(uTime * .018, 0.0));
        color *= .965 + sedimentRibbon * .055;
        float distanceToCamera = length(cameraPosition - vWorld);
        float fogFactor = 1.0 - exp(-uFogDensity * uFogDensity * distanceToCamera * distanceToCamera);
        color = mix(color, uFogColor, clamp(fogFactor, 0.0, .92));
        gl_FragColor = vec4(color, 1.0);
      }
    `,
  });
  const mesh = new THREE.Mesh(geometry, material);
  mesh.rotation.x = -Math.PI / 2;
  mesh.receiveShadow = true;
  mesh.renderOrder = 1;
  return { mesh, material };
}

function createBuoy(color: number): THREE.Group {
  const group = new THREE.Group();
  const painted = new THREE.MeshPhysicalMaterial({
    color,
    roughness: 0.38,
    clearcoat: 0.62,
    clearcoatRoughness: 0.32,
    envMapIntensity: 0.8,
  });
  const fadedWhite = new THREE.MeshStandardMaterial({ color: 0xdedbd0, roughness: 0.67 });
  const rubber = new THREE.MeshStandardMaterial({ color: 0x25343a, roughness: 0.82 });

  const body = new THREE.Mesh(new THREE.SphereGeometry(0.48, 20, 14), painted);
  body.scale.set(1, 1.12, 1);
  body.position.y = 0.32;
  body.castShadow = true;
  group.add(body);

  const darkBase = new THREE.Mesh(new THREE.TorusGeometry(0.39, 0.065, 8, 24), rubber);
  darkBase.rotation.x = Math.PI / 2;
  darkBase.position.y = 0.08;
  group.add(darkBase);

  const stripe = new THREE.Mesh(new THREE.CylinderGeometry(0.43, 0.46, 0.18, 20), fadedWhite);
  stripe.position.y = 0.35;
  group.add(stripe);

  const stalk = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.045, 0.86, 8), fadedWhite);
  stalk.position.y = 1.03;
  stalk.castShadow = true;
  group.add(stalk);

  const pennantGeometry = new THREE.BufferGeometry();
  pennantGeometry.setAttribute('position', new THREE.Float32BufferAttribute([
    0, 0, 0, 0, 0.34, 0, 0.55, 0.25, 0,
  ], 3));
  pennantGeometry.setIndex([0, 1, 2]);
  pennantGeometry.computeVertexNormals();
  const pennant = new THREE.Mesh(pennantGeometry, painted);
  pennant.position.y = 1.1;
  pennant.castShadow = true;
  group.add(pennant);
  return group;
}

function makeDuck(): THREE.Group {
  const duck = new THREE.Group();
  const yellow = new THREE.MeshPhysicalMaterial({
    color: 0xd9ad35,
    roughness: 0.42,
    clearcoat: 0.5,
    clearcoatRoughness: 0.38,
  });
  const orange = new THREE.MeshPhysicalMaterial({ color: 0xc75b2e, roughness: 0.48, clearcoat: 0.35 });
  const body = new THREE.Mesh(new THREE.SphereGeometry(0.74, 20, 14), yellow);
  body.scale.set(1.2, 0.75, 1.42);
  body.position.y = 0.48;
  body.castShadow = true;
  duck.add(body);
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.43, 18, 12), yellow);
  head.position.set(0, 1.08, 0.48);
  head.castShadow = true;
  duck.add(head);
  const bill = new THREE.Mesh(new THREE.SphereGeometry(0.22, 14, 8), orange);
  bill.scale.set(1.22, 0.38, 0.7);
  bill.position.set(0, 1.02, 0.86);
  duck.add(bill);
  const eyeMaterial = new THREE.MeshBasicMaterial({ color: 0x101619 });
  for (const x of [-0.17, 0.17]) {
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.04, 8, 6), eyeMaterial);
    eye.position.set(x, 1.19, 0.79);
    duck.add(eye);
  }
  return duck;
}

function roundedStoneGeometry(radius: number): THREE.CylinderGeometry {
  const geometry = new THREE.CylinderGeometry(radius * 0.92, radius, 0.25, 9);
  geometry.rotateY(Math.PI / 9);
  return geometry;
}

export class World {
  readonly root = new THREE.Group();
  readonly gusts: GustZone[] = [
    { x: 13, z: -22.5, radius: 7.5, phase: 0 },
    { x: 21, z: 5, radius: 8.5, phase: 2.1 },
    { x: -13, z: 19, radius: 8, phase: 4.2 },
  ];
  readonly obstacles: Obstacle[] = [
    { x: 0, z: -2, radius: 5.2 },
    { x: -8, z: 4, radius: 3.4 },
    { x: 11, z: 5, radius: 2.1 },
  ];
  readonly gateGroups: THREE.Group[] = [];
  private readonly waterMaterial: THREE.MeshPhysicalMaterial;
  private readonly gustMeshes: THREE.Mesh[] = [];
  private readonly rainRippleData: RainRipple[] = [];
  private readonly rainRipples: THREE.InstancedMesh;
  private readonly rippleTransform = new THREE.Object3D();
  private readonly sun: THREE.DirectionalLight;

  constructor(scene: THREE.Scene) {
    scene.add(this.root);
    scene.fog = new THREE.FogExp2('#a8bbc0', 0.0042);

    const environment = createEnvironmentTexture();
    scene.background = environment;
    scene.environment = environment;
    scene.environmentIntensity = 1.05;
    scene.backgroundIntensity = 1;
    scene.backgroundBlurriness = 0;
    scene.backgroundRotation.y = -0.36;
    scene.environmentRotation.y = -0.36;
    new THREE.TextureLoader().load(backyardPanoramaUrl, (panorama) => {
      panorama.mapping = THREE.EquirectangularReflectionMapping;
      panorama.colorSpace = THREE.SRGBColorSpace;
      panorama.anisotropy = 4;
      scene.background = panorama;
      scene.environment = panorama;
      environment.dispose();
    });

    const hemisphere = new THREE.HemisphereLight(0xbdd4dd, 0x3b4233, 0.78);
    scene.add(hemisphere);
    scene.add(new THREE.AmbientLight(0xdbe2dc, 0.1));

    this.sun = new THREE.DirectionalLight(0xffdda6, 4.15);
    this.sun.position.set(-42, 58, 48);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(1024, 1024);
    this.sun.shadow.camera.left = -58;
    this.sun.shadow.camera.right = 58;
    this.sun.shadow.camera.top = 48;
    this.sun.shadow.camera.bottom = -48;
    this.sun.shadow.camera.near = 2;
    this.sun.shadow.camera.far = 165;
    this.sun.shadow.bias = -0.00018;
    this.sun.shadow.normalBias = 0.025;
    scene.add(this.sun);

    const { mesh: water, material } = createWater();
    this.waterMaterial = material as THREE.MeshPhysicalMaterial;
    this.root.add(water);
    this.rainRipples = this.createRainRipples();

    this.createGround();
    this.createFence();
    this.createHouse();
    this.createTrees();
    this.createCourse();
    this.createYardProps();
    this.createGusts();
    this.createGrass();
    this.createLeaves();
  }

  private createGround(): void {
    const grain = createGrainTexture();
    const submergedMaterial = new THREE.MeshStandardMaterial({
      color: 0x34483a,
      map: grain,
      roughness: 1,
      metalness: 0,
    });
    const earth = new THREE.Mesh(new THREE.BoxGeometry(196, 1.2, 170), submergedMaterial);
    earth.position.y = -1.6;
    earth.receiveShadow = true;
    this.root.add(earth);

    const bankMaterial = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      map: grain,
      vertexColors: true,
      roughness: 0.98,
      envMapIntensity: 0.08,
    });
    const wetMud = new THREE.Color(0x343d31);
    const bankEdge = new THREE.Color(0x4c5540);
    const grass = new THREE.Color(0x526743);

    const makeBank = (horizontal: boolean, sign: number): THREE.Mesh => {
      const segments = horizontal ? 72 : 62;
      const length = horizontal ? 154 : 136;
      const positions: number[] = [];
      const uvs: number[] = [];
      const colors: number[] = [];
      const indices: number[] = [];
      for (let index = 0; index <= segments; index += 1) {
        const along = -length / 2 + (index / segments) * length;
        const wobble = Math.sin(index * 0.83 + sign * 1.7) * 0.55 + (seeded(index + (horizontal ? 20 : 220)) - 0.5) * 0.8;
        const inner = (horizontal ? 47.2 : 58.5) + wobble;
        const middle = inner + (horizontal ? 5.3 : 5.5) + seeded(index + 420) * 0.75;
        const outer = horizontal ? 72 : 80;
        const heights = [-0.2, 0.2 + seeded(index + 520) * 0.18, 0.78 + seeded(index + 620) * 0.18];
        for (let row = 0; row < 3; row += 1) {
          const across = sign * [inner, middle, outer][row];
          const x = horizontal ? along : across;
          const z = horizontal ? across : along;
          positions.push(x, heights[row], z);
          uvs.push(index / segments * (horizontal ? 14 : 12), row * 2.2);
          const color = row === 0 ? wetMud : row === 1 ? bankEdge : grass;
          const variation = 0.86 + seeded(index * 3 + row + 760) * 0.18;
          colors.push(color.r * variation, color.g * variation, color.b * variation);
        }
      }
      for (let index = 0; index < segments; index += 1) {
        for (let row = 0; row < 2; row += 1) {
          const a = index * 3 + row;
          const b = a + 3;
          indices.push(a, a + 1, b + 1, a, b + 1, b);
        }
      }
      const geometry = new THREE.BufferGeometry();
      geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
      geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
      geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
      geometry.setIndex(indices);
      geometry.computeVertexNormals();
      const mesh = new THREE.Mesh(geometry, bankMaterial);
      mesh.receiveShadow = true;
      return mesh;
    };

    this.root.add(makeBank(true, -1), makeBank(true, 1), makeBank(false, -1), makeBank(false, 1));

    const stoneMaterial = new THREE.MeshStandardMaterial({
      color: 0x77786f,
      map: grain,
      roughness: 0.94,
      envMapIntensity: 0.12,
    });
    for (let index = 0; index < 13; index += 1) {
      const x = -49 + index * 8.2;
      const stone = new THREE.Mesh(roundedStoneGeometry(2.8 + seeded(index + 940) * 0.45), stoneMaterial);
      stone.position.set(x, 0.25 + seeded(index + 1040) * 0.08, -52.5 + (seeded(index + 1140) - 0.5) * 1.4);
      stone.rotation.y = (seeded(index + 1240) - 0.5) * 0.35;
      stone.scale.z = 0.76 + seeded(index + 1340) * 0.18;
      stone.receiveShadow = true;
      stone.castShadow = true;
      this.root.add(stone);
    }
  }

  private createFence(): void {
    const woodTexture = createWoodTexture();
    const boardMaterial = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      map: woodTexture,
      roughness: 0.92,
      envMapIntensity: 0.16,
      vertexColors: true,
    });
    const railMaterial = new THREE.MeshStandardMaterial({ color: 0x5c5042, map: woodTexture, roughness: 0.95 });
    const boardGeometry = new THREE.BoxGeometry(0.94, 1, 0.18);
    const boards: Array<{ x: number; z: number; rotation: number; height: number; seed: number }> = [];

    for (let x = -75; x <= 75; x += 1.12) {
      boards.push({ x, z: 65.8, rotation: 0, height: 6.6 + seeded(x + 1600) * 0.7, seed: x + 1700 });
    }
    for (const side of [-1, 1]) {
      for (let z = -65; z <= 65; z += 1.12) {
        boards.push({ x: side * 75.2, z, rotation: Math.PI / 2, height: 6.5 + seeded(z + side * 80 + 1800) * 0.75, seed: z + side * 90 + 1900 });
      }
    }

    const fenceBoards = new THREE.InstancedMesh(boardGeometry, boardMaterial, boards.length);
    const transform = new THREE.Object3D();
    boards.forEach((board, index) => {
      transform.position.set(
        board.x + (seeded(board.seed + 10) - 0.5) * 0.07,
        1.02 + board.height / 2,
        board.z + (seeded(board.seed + 20) - 0.5) * 0.07,
      );
      transform.rotation.set(0, board.rotation, (seeded(board.seed + 30) - 0.5) * 0.018);
      transform.scale.set(1, board.height, 1);
      transform.updateMatrix();
      fenceBoards.setMatrixAt(index, transform.matrix);
      const tone = 0.72 + seeded(board.seed + 40) * 0.22;
      fenceBoards.setColorAt(index, new THREE.Color(tone, tone * 0.95, tone * 0.86));
    });
    fenceBoards.castShadow = true;
    fenceBoards.receiveShadow = true;
    this.root.add(fenceBoards);

    for (const y of [3.0, 6.15]) {
      const northRail = new THREE.Mesh(new THREE.BoxGeometry(152, 0.34, 0.34), railMaterial);
      northRail.position.set(0, y, 65.45);
      northRail.castShadow = true;
      this.root.add(northRail);
      for (const side of [-1, 1]) {
        const sideRail = new THREE.Mesh(new THREE.BoxGeometry(0.34, 0.34, 132), railMaterial);
        sideRail.position.set(side * 74.85, y, 0);
        sideRail.castShadow = true;
        this.root.add(sideRail);
      }
    }

    const postGeometry = new THREE.BoxGeometry(0.48, 7.7, 0.48);
    const posts: THREE.Vector3[] = [];
    for (let x = -74; x <= 74; x += 9.4) posts.push(new THREE.Vector3(x, 4.8, 65.2));
    for (const side of [-1, 1]) {
      for (let z = -62; z <= 62; z += 9.4) posts.push(new THREE.Vector3(side * 74.6, 4.8, z));
    }
    const fencePosts = new THREE.InstancedMesh(postGeometry, railMaterial, posts.length);
    posts.forEach((position, index) => {
      transform.position.copy(position);
      transform.rotation.set(0, 0, 0);
      transform.scale.set(1, 1, 1);
      transform.updateMatrix();
      fencePosts.setMatrixAt(index, transform.matrix);
    });
    fencePosts.castShadow = true;
    this.root.add(fencePosts);
  }

  private createHouse(): void {
    // The panorama carries the distant buildings with photographic detail.
    return;
    const siding = createSidingTexture();
    const wallMaterial = new THREE.MeshStandardMaterial({ color: 0xd2d0c4, map: siding, roughness: 0.84 });
    const trimMaterial = new THREE.MeshStandardMaterial({ color: 0xe7e2d3, roughness: 0.72 });
    const roofMaterial = new THREE.MeshStandardMaterial({ color: 0x313a3b, roughness: 0.92 });
    const glassMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x47626a,
      roughness: 0.12,
      metalness: 0.18,
      clearcoat: 0.8,
      envMapIntensity: 1.35,
    });

    const wall = new THREE.Mesh(new THREE.BoxGeometry(44, 15, 11), wallMaterial);
    wall.position.set(5, 9.3, 76.5);
    wall.castShadow = true;
    wall.receiveShadow = true;
    this.root.add(wall);

    const frontRoof = new THREE.Mesh(new THREE.BoxGeometry(47, 0.62, 11), roofMaterial);
    frontRoof.position.set(5, 17.4, 72.8);
    frontRoof.rotation.x = -0.37;
    frontRoof.castShadow = true;
    this.root.add(frontRoof);
    const rearRoof = frontRoof.clone();
    rearRoof.position.z = 80.2;
    rearRoof.rotation.x = 0.37;
    this.root.add(rearRoof);

    for (const x of [-7, 8, 18]) {
      const window = new THREE.Mesh(new THREE.PlaneGeometry(5, 4.4), glassMaterial);
      window.position.set(x, 11.6, 70.96);
      this.root.add(window);
      for (const offset of [-2.63, 2.63]) {
        const verticalTrim = new THREE.Mesh(new THREE.BoxGeometry(0.3, 5, 0.24), trimMaterial);
        verticalTrim.position.set(x + offset, 11.6, 70.82);
        verticalTrim.castShadow = true;
        this.root.add(verticalTrim);
      }
      for (const offset of [-2.33, 2.33]) {
        const horizontalTrim = new THREE.Mesh(new THREE.BoxGeometry(5.5, 0.3, 0.24), trimMaterial);
        horizontalTrim.position.set(x, 11.6 + offset, 70.82);
        horizontalTrim.castShadow = true;
        this.root.add(horizontalTrim);
      }
      const mullion = new THREE.Mesh(new THREE.BoxGeometry(0.18, 4.5, 0.18), trimMaterial);
      mullion.position.set(x, 11.6, 70.7);
      this.root.add(mullion);
      const crossbar = new THREE.Mesh(new THREE.BoxGeometry(5, 0.18, 0.18), trimMaterial);
      crossbar.position.set(x, 11.6, 70.7);
      this.root.add(crossbar);
    }

    const gutter = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.17, 47, 10), trimMaterial);
    gutter.rotation.z = Math.PI / 2;
    gutter.position.set(5, 15.2, 68.1);
    gutter.castShadow = true;
    this.root.add(gutter);
    const downspout = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, 12.5, 10), trimMaterial);
    downspout.position.set(-17.5, 8.9, 68.05);
    downspout.castShadow = true;
    this.root.add(downspout);
  }

  private createTrees(): void {
    // The photographic panorama supplies the distant tree line without adding
    // flat billboard foliage in front of the fence.
    return;
    const treePositions = [
      [-66, 69, 13], [-48, 73, 17], [38, 74, 18], [61, 69, 14],
      [-80, 34, 15], [81, 20, 18], [-81, -27, 16], [80, -43, 14],
    ] as const;
    const trunkMaterial = new THREE.MeshStandardMaterial({ color: 0x4f4438, roughness: 1 });
    const trunkGeometry = new THREE.CylinderGeometry(0.62, 0.92, 12, 9);
    const trunks = new THREE.InstancedMesh(trunkGeometry, trunkMaterial, treePositions.length);
    const transform = new THREE.Object3D();
    treePositions.forEach(([x, z, height], index) => {
      transform.position.set(x, 4.6 + height * 0.08, z);
      transform.rotation.set(0, seeded(index + 2700) * Math.PI, (seeded(index + 2800) - 0.5) * 0.08);
      transform.scale.set(0.72 + height * 0.018, height / 12, 0.72 + height * 0.018);
      transform.updateMatrix();
      trunks.setMatrixAt(index, transform.matrix);
    });
    trunks.castShadow = true;
    this.root.add(trunks);

    const canopyGeometry = new THREE.PlaneGeometry(8.8, 7.2, 1, 1);
    const foliageTexture = createFoliageTexture();
    const canopyMaterial = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      map: foliageTexture,
      transparent: true,
      alphaTest: 0.32,
      roughness: 0.96,
      vertexColors: true,
      side: THREE.DoubleSide,
    });
    const canopyCount = treePositions.length * 6;
    const canopies = new THREE.InstancedMesh(canopyGeometry, canopyMaterial, canopyCount);
    let canopyIndex = 0;
    treePositions.forEach(([x, z, height], treeIndex) => {
      for (let cluster = 0; cluster < 6; cluster += 1) {
        const angle = cluster / 6 * Math.PI * 2 + seeded(treeIndex + 2900) * 0.7;
        const radius = cluster < 2 ? 0.65 : 2.4 + seeded(canopyIndex + 2920) * 1.3;
        transform.position.set(
          x + Math.cos(angle) * radius,
          11.2 + height * 0.32 + (cluster < 2 ? 2.0 : seeded(treeIndex * 8 + cluster + 3000) * 2.6),
          z + Math.sin(angle) * radius,
        );
        transform.rotation.set(0, angle + (cluster % 2) * Math.PI / 2, (seeded(canopyIndex + 3100) - 0.5) * 0.1);
        transform.scale.set(
          0.78 + seeded(canopyIndex + 3300) * 0.42,
          0.75 + seeded(canopyIndex + 3400) * 0.38,
          1,
        );
        transform.updateMatrix();
        canopies.setMatrixAt(canopyIndex, transform.matrix);
        const shade = seeded(canopyIndex + 3600);
        canopies.setColorAt(canopyIndex, new THREE.Color().setHSL(0.28, 0.18 + shade * 0.11, 0.34 + shade * 0.12));
        canopyIndex += 1;
      }
    });
    canopies.castShadow = true;
    canopies.receiveShadow = true;
    this.root.add(canopies);
  }

  private createCourse(): void {
    COURSE.forEach((point, index) => {
      const next = COURSE[(index + 1) % COURSE.length];
      const dx = next.x - point.x;
      const dz = next.z - point.z;
      const length = Math.hypot(dx, dz);
      const px = -dz / length;
      const pz = dx / length;
      const gate = new THREE.Group();
      const width = index === 0 ? 16.5 : 14.5;
      const color = index === 0 ? 0xe8bf45 : index % 2 ? 0xbf493c : 0x327181;
      const left = createBuoy(color);
      const right = createBuoy(color);
      left.position.set(point.x + px * width / 2, 0, point.z + pz * width / 2);
      right.position.set(point.x - px * width / 2, 0, point.z - pz * width / 2);
      gate.add(left, right);

      const ribbon = new THREE.Mesh(
        new THREE.PlaneGeometry(width - 1.1, 0.11),
        new THREE.MeshBasicMaterial({
          color: index === 0 ? 0xffdc73 : 0xd6e4e1,
          transparent: true,
          opacity: 0.1,
          side: THREE.DoubleSide,
          depthWrite: false,
        }),
      );
      ribbon.rotation.x = -Math.PI / 2;
      ribbon.rotation.z = -Math.atan2(dx, dz);
      ribbon.position.set(point.x, 0.1, point.z);
      gate.add(ribbon);

      const beamMaterial = new THREE.MeshBasicMaterial({
        color: index === 0 ? 0xffd76b : 0xcfe4e1,
        transparent: true,
        opacity: 0.025,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      });
      for (const direction of [-1, 1]) {
        const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.22, 4.2, 10, 1, true), beamMaterial.clone());
        beam.position.set(point.x + px * width / 2 * direction, 2.15, point.z + pz * width / 2 * direction);
        beam.userData.gateBeam = true;
        gate.add(beam);
      }
      this.gateGroups.push(gate);
      this.root.add(gate);
    });
  }

  private createYardProps(): void {
    this.createTrampoline();
    this.createWadingPool();
    this.createPatioTable();

    const duck = makeDuck();
    duck.position.set(-54, 0.03, 36);
    duck.rotation.y = -0.55;
    this.root.add(duck);

    const ball = new THREE.Mesh(
      new THREE.SphereGeometry(0.82, 24, 16),
      new THREE.MeshPhysicalMaterial({ color: 0xd8d8d2, roughness: 0.56, clearcoat: 0.3 }),
    );
    ball.position.set(56.5, 0.44, -18);
    ball.castShadow = true;
    this.root.add(ball);
    const ballPatchMaterial = new THREE.MeshBasicMaterial({ color: 0x2e3737, side: THREE.DoubleSide });
    for (let index = 0; index < 5; index += 1) {
      const patch = new THREE.Mesh(new THREE.CircleGeometry(0.18, 5), ballPatchMaterial);
      patch.position.copy(ball.position).add(new THREE.Vector3(
        Math.sin(index * 2.5) * 0.68,
        0.28 + (index % 2) * 0.33,
        Math.cos(index * 2.5) * 0.68,
      ));
      patch.lookAt(ball.position.clone().multiplyScalar(2).sub(patch.position));
      this.root.add(patch);
    }

    const bucketMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x426a72,
      roughness: 0.47,
      clearcoat: 0.35,
      side: THREE.DoubleSide,
    });
    const bucket = new THREE.Mesh(new THREE.CylinderGeometry(1.3, 1.05, 1.85, 24, 1, true), bucketMaterial);
    bucket.position.set(54, 0.78, -38);
    bucket.rotation.z = 0.2;
    bucket.castShadow = true;
    this.root.add(bucket);
    const bucketRim = new THREE.Mesh(new THREE.TorusGeometry(1.3, 0.075, 8, 24), bucketMaterial);
    bucketRim.position.set(53.82, 1.68, -38);
    bucketRim.rotation.x = Math.PI / 2;
    bucketRim.rotation.z = 0.2;
    this.root.add(bucketRim);

    const hoseMaterial = new THREE.MeshStandardMaterial({ color: 0x31523a, roughness: 0.72 });
    const hoseCurve = new THREE.CatmullRomCurve3([
      new THREE.Vector3(-62, 0.68, -43),
      new THREE.Vector3(-50, 0.28, -45),
      new THREE.Vector3(-58, 0.2, -36),
      new THREE.Vector3(-47, 0.18, -30),
      new THREE.Vector3(-57, 0.22, -25),
    ]);
    const hose = new THREE.Mesh(new THREE.TubeGeometry(hoseCurve, 64, 0.11, 7, false), hoseMaterial);
    hose.castShadow = true;
    this.root.add(hose);

    const potMaterial = new THREE.MeshStandardMaterial({ color: 0x7c4f3a, roughness: 0.86 });
    const potSoil = new THREE.MeshStandardMaterial({ color: 0x2f2922, roughness: 1 });
    for (let index = 0; index < 4; index += 1) {
      const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.72, 0.5, 1.15, 16, 1, true), potMaterial);
      pot.position.set(-62 + index * 2.1, 1.13, 57 + (index % 2) * 0.8);
      pot.castShadow = true;
      this.root.add(pot);
      const soil = new THREE.Mesh(new THREE.CircleGeometry(0.69, 16), potSoil);
      soil.rotation.x = -Math.PI / 2;
      soil.position.set(pot.position.x, 1.71, pot.position.z);
      this.root.add(soil);
    }
  }

  private createTrampoline(): void {
    const frameMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x718086,
      metalness: 0.72,
      roughness: 0.38,
      envMapIntensity: 1.1,
    });
    const matMaterial = new THREE.MeshStandardMaterial({ color: 0x172326, roughness: 0.73, envMapIntensity: 0.22 });
    const mat = new THREE.Mesh(new THREE.CylinderGeometry(4.72, 4.72, 0.12, 48), matMaterial);
    mat.position.set(0, 0.82, -2);
    mat.castShadow = true;
    mat.receiveShadow = true;
    this.root.add(mat);
    const rim = new THREE.Mesh(new THREE.TorusGeometry(4.86, 0.12, 10, 64), frameMaterial);
    rim.rotation.x = Math.PI / 2;
    rim.position.set(0, 0.87, -2);
    rim.castShadow = true;
    this.root.add(rim);

    const legGeometry = new THREE.CylinderGeometry(0.075, 0.075, 1.45, 8);
    const legs = new THREE.InstancedMesh(legGeometry, frameMaterial, 8);
    const transform = new THREE.Object3D();
    for (let index = 0; index < 8; index += 1) {
      const angle = index / 8 * Math.PI * 2;
      transform.position.set(Math.cos(angle) * 4.15, 0.18, -2 + Math.sin(angle) * 4.15);
      transform.rotation.set(0, 0, 0);
      transform.scale.set(1, 1, 1);
      transform.updateMatrix();
      legs.setMatrixAt(index, transform.matrix);
    }
    legs.castShadow = true;
    this.root.add(legs);
  }

  private createWadingPool(): void {
    const wallMaterial = new THREE.MeshPhysicalMaterial({
      color: 0x7d9da2,
      roughness: 0.55,
      clearcoat: 0.24,
      side: THREE.DoubleSide,
      envMapIntensity: 0.75,
    });
    const trimMaterial = new THREE.MeshPhysicalMaterial({ color: 0xd4d3c8, roughness: 0.5, clearcoat: 0.3 });
    const wall = new THREE.Mesh(new THREE.CylinderGeometry(3.12, 3.18, 1.05, 40, 1, true), wallMaterial);
    wall.position.set(-8, 0.33, 4);
    wall.castShadow = true;
    this.root.add(wall);
    const rim = new THREE.Mesh(new THREE.TorusGeometry(3.13, 0.12, 9, 48), trimMaterial);
    rim.position.set(-8, 0.86, 4);
    rim.rotation.x = Math.PI / 2;
    rim.castShadow = true;
    this.root.add(rim);
  }

  private createPatioTable(): void {
    const metal = new THREE.MeshPhysicalMaterial({
      color: 0x6f7773,
      metalness: 0.55,
      roughness: 0.48,
      envMapIntensity: 1,
    });
    const wetWood = new THREE.MeshPhysicalMaterial({
      color: 0x6f5943,
      roughness: 0.52,
      clearcoat: 0.25,
      clearcoatRoughness: 0.45,
    });
    const top = new THREE.Mesh(new THREE.CylinderGeometry(1.82, 1.82, 0.16, 36), wetWood);
    top.position.set(11, 2.15, 5);
    top.castShadow = true;
    top.receiveShadow = true;
    this.root.add(top);
    const center = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.13, 2.2, 10), metal);
    center.position.set(11, 1.05, 5);
    center.castShadow = true;
    this.root.add(center);
    for (let index = 0; index < 4; index += 1) {
      const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.065, 0.075, 2.3, 8), metal);
      const angle = index / 4 * Math.PI * 2 + Math.PI / 4;
      leg.position.set(11 + Math.cos(angle) * 0.62, 1.0, 5 + Math.sin(angle) * 0.62);
      leg.rotation.z = Math.cos(angle) * 0.28;
      leg.rotation.x = Math.sin(angle) * 0.28;
      leg.castShadow = true;
      this.root.add(leg);
    }
  }

  private createGusts(): void {
    const material = new THREE.MeshBasicMaterial({
      color: 0xc4dcda,
      transparent: true,
      opacity: 0.014,
      depthWrite: false,
      blending: THREE.NormalBlending,
      side: THREE.DoubleSide,
    });
    for (const gust of this.gusts) {
      const mesh = new THREE.Mesh(new THREE.RingGeometry(gust.radius * 0.86, gust.radius, 64), material.clone());
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.set(gust.x, 0.13, gust.z);
      this.gustMeshes.push(mesh);
      this.root.add(mesh);
    }
  }

  private createRainRipples(): THREE.InstancedMesh {
    const count = 64;
    const geometry = new THREE.RingGeometry(0.46, 0.52, 28);
    const material = new THREE.MeshBasicMaterial({
      color: 0xdde8e4,
      transparent: true,
      opacity: 0.12,
      depthWrite: false,
      blending: THREE.NormalBlending,
      side: THREE.DoubleSide,
    });
    const ripples = new THREE.InstancedMesh(geometry, material, count);
    ripples.frustumCulled = false;
    ripples.renderOrder = 3;

    for (let index = 0; index < count; index += 1) {
      const x = (seeded(index + 8100) - 0.5) * 108;
      const z = (seeded(index + 8200) - 0.5) * 88;
      this.rainRippleData.push({
        x,
        z,
        phase: seeded(index + 8300),
        size: 0.55 + seeded(index + 8400) * 0.9,
      });
      ripples.setColorAt(index, new THREE.Color().setScalar(0.78 + seeded(index + 8500) * 0.22));
    }
    this.root.add(ripples);
    return ripples;
  }

  private createGrass(): void {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute([
      -0.045, 0, 0, 0.045, 0, 0, 0.012, 1, 0,
      0, 0, -0.045, 0, 0, 0.045, 0, 1, 0.012,
    ], 3));
    geometry.setIndex([0, 1, 2, 3, 4, 5]);
    geometry.computeVertexNormals();
    const material = new THREE.MeshStandardMaterial({
      color: 0xffffff,
      vertexColors: true,
      roughness: 1,
      side: THREE.DoubleSide,
    });
    const count = 1450;
    const grass = new THREE.InstancedMesh(geometry, material, count);
    const transform = new THREE.Object3D();
    for (let index = 0; index < count; index += 1) {
      const side = index % 4;
      const horizontal = side < 2;
      const along = (seeded(index + 4000) - 0.5) * (horizontal ? 148 : 130);
      const edge = horizontal ? 50.5 + seeded(index + 4100) * 17 : 62 + seeded(index + 4100) * 11;
      const x = horizontal ? along : (side === 2 ? -edge : edge);
      const z = horizontal ? (side === 0 ? -edge : edge) : along;
      const bankDepth = horizontal ? (Math.abs(z) - 47) / 24 : (Math.abs(x) - 58) / 22;
      const y = 0.06 + THREE.MathUtils.clamp(bankDepth, 0, 1) * 0.75;
      transform.position.set(x, y, z);
      transform.rotation.set((seeded(index + 4200) - 0.5) * 0.12, seeded(index + 4300) * Math.PI, (seeded(index + 4400) - 0.5) * 0.18);
      const height = 0.36 + seeded(index + 4500) * 0.68;
      const width = 0.72 + seeded(index + 4600) * 0.72;
      transform.scale.set(width, height, width);
      transform.updateMatrix();
      grass.setMatrixAt(index, transform.matrix);
      const hue = 0.24 + seeded(index + 4700) * 0.06;
      grass.setColorAt(index, new THREE.Color().setHSL(hue, 0.3 + seeded(index + 4800) * 0.2, 0.22 + seeded(index + 4900) * 0.15));
    }
    grass.receiveShadow = true;
    this.root.add(grass);
  }

  private createLeaves(): void {
    const leafGeometry = new THREE.CircleGeometry(0.18, 6);
    const leafMaterial = new THREE.MeshBasicMaterial({
      color: 0xffffff,
      vertexColors: true,
      side: THREE.DoubleSide,
    });
    const count = 110;
    const leaves = new THREE.InstancedMesh(leafGeometry, leafMaterial, count);
    const transform = new THREE.Object3D();
    for (let index = 0; index < count; index += 1) {
      const angle = seeded(index + 5100) * Math.PI * 2;
      const radius = 16 + Math.pow(seeded(index + 5200), 0.54) * 42;
      const x = Math.cos(angle) * radius * 1.08;
      const z = Math.sin(angle) * radius * 0.86;
      transform.position.set(x, waterHeight(x, z, 0) + 0.035, z);
      transform.rotation.set(-Math.PI / 2 + (seeded(index + 5300) - 0.5) * 0.08, 0, seeded(index + 5400) * Math.PI);
      transform.scale.set(0.65 + seeded(index + 5500) * 1.15, 1.2 + seeded(index + 5600) * 1.6, 1);
      transform.updateMatrix();
      leaves.setMatrixAt(index, transform.matrix);
      const tone = seeded(index + 5700);
      leaves.setColorAt(index, tone > 0.58 ? new THREE.Color(0xa17b45) : new THREE.Color(0x765a35));
    }
    leaves.receiveShadow = true;
    this.root.add(leaves);
  }

  setActiveGate(index: number): void {
    this.gateGroups.forEach((group, gateIndex) => {
      group.scale.setScalar(1);
      group.traverse((object) => {
        if (!object.userData.gateBeam || !(object instanceof THREE.Mesh)) return;
        (object.material as THREE.MeshBasicMaterial).opacity = gateIndex === index ? 0.26 : 0.022;
      });
    });
  }

  update(time: number, playerSpeed = 0): void {
    (this.waterMaterial.userData.waterTime as { value: number }).value = time;
    if (this.waterMaterial.normalMap) {
      const flow = 1 + THREE.MathUtils.clamp(playerSpeed / 9.4, 0, 1) * 1.15;
      this.waterMaterial.normalMap.offset.set(time * 0.006 * flow, -time * 0.004 * flow);
    }
    this.rainRippleData.forEach((ripple, index) => {
      const life = (time * 0.14 + ripple.phase) % 1;
      const visible = life < 0.74;
      const scale = visible ? ripple.size * (0.28 + life * 1.55) : 0.001;
      this.rippleTransform.position.set(ripple.x, waterHeight(ripple.x, ripple.z, time) + 0.16, ripple.z);
      this.rippleTransform.rotation.set(-Math.PI / 2, 0, ripple.phase * Math.PI);
      this.rippleTransform.scale.set(scale, scale, scale);
      this.rippleTransform.updateMatrix();
      this.rainRipples.setMatrixAt(index, this.rippleTransform.matrix);
    });
    this.rainRipples.instanceMatrix.needsUpdate = true;
    this.gustMeshes.forEach((mesh, index) => {
      const gust = this.gusts[index];
      const pulse = 0.94 + Math.sin(time * 1.45 + gust.phase) * 0.055;
      mesh.scale.setScalar(pulse);
      (mesh.material as THREE.MeshBasicMaterial).opacity = 0.008 + (Math.sin(time * 1.8 + gust.phase) * 0.5 + 0.5) * 0.012;
      mesh.rotation.z = time * 0.035 + gust.phase;
    });
  }
}
