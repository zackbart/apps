import * as THREE from 'three';
import { RaceAudio } from './Audio';
import { Boat } from './Boat';
import { COURSE, World, waterHeight } from './World';
import { PERFECT_TRIM_WINDOW, angleDelta, clamp, optimalTrim, targetSpeed, trimEfficiency } from '../simulation/sailing';

type Mode = 'menu' | 'countdown' | 'racing' | 'paused' | 'finished';

interface RivalTuning {
  name: string;
  color: string;
  speed: number;
  aggression: number;
  error: number;
  gustPreference: number;
  draftPreference: number;
}

interface Racer {
  boat: Boat;
  position: THREE.Vector2;
  heading: number;
  speed: number;
  trim: number;
  rudder: number;
  spin: number;
  checkpoint: number;
  lap: number;
  progress: number;
  collisionCooldown: number;
  stuckTime: number;
  finishTime: number | null;
  slot: number;
  tuning: RivalTuning | null;
  raceSpeedOffset: number;
}

interface HudElements {
  startScreen: HTMLElement;
  hud: HTMLElement;
  resultScreen: HTMLElement;
  startButton: HTMLButtonElement;
  restartButton: HTMLButtonElement;
  position: HTMLElement;
  ordinal: HTMLElement;
  clock: HTMLElement;
  lap: HTMLElement;
  gate: HTMLElement;
  windDial: HTMLElement;
  windSpeed: HTMLElement;
  trimState: HTMLElement;
  trimIdeal: HTMLElement;
  trimFill: HTMLElement;
  trimKnob: HTMLElement;
  controlsHint: HTMLElement;
  centerMessage: HTMLElement;
  gateArrow: HTMLElement;
  resultKicker: HTMLElement;
  resultTitle: HTMLElement;
  resultTimeLabel: HTMLElement;
  resultTime: HTMLElement;
  resultLine: HTMLElement;
  bestTime: HTMLElement;
  resultPasses: HTMLElement;
  resultBumps: HTMLElement;
  toyTrophy: HTMLElement;
  impactFlash: HTMLElement;
  speedLines: HTMLElement;
}

interface RaceSnapshot {
  mode: Mode;
  elapsed: number;
  remaining: number;
  fps: number;
  collisions: number;
  fleetCollisions: number;
  overtakes: number;
  player: {
    place: number;
    lap: number;
    checkpoint: number;
    speed: number;
    heading: number;
    trim: number;
    trimQuality: number;
    x: number;
    z: number;
  };
  racers: Array<{ name: string; place: number; lap: number; checkpoint: number; speed: number }>;
}

declare global {
  interface Window {
    __REGATTA__: {
      start: () => void;
      restart: () => void;
      setAutopilot: (enabled: boolean) => void;
      setTimeScale: (scale: number) => void;
      getState: () => RaceSnapshot;
    };
  }
}

const RIVALS: RivalTuning[] = [
  { name: 'Ruckus', color: '#e65143', speed: 0.99, aggression: 0.72, error: 0.16, gustPreference: 0.2, draftPreference: 0.15 },
  { name: 'Tack', color: '#326fa6', speed: 1.005, aggression: 0.2, error: 0.045, gustPreference: 0.3, draftPreference: 0.2 },
  { name: 'Bumble', color: '#efbd3d', speed: 1.015, aggression: 0.4, error: 0.24, gustPreference: 0.25, draftPreference: 0.1 },
  { name: 'Gusty', color: '#4b9a69', speed: 0.995, aggression: 0.35, error: 0.13, gustPreference: 0.75, draftPreference: 0.1 },
  { name: 'Slip', color: '#8b66a9', speed: 0.985, aggression: 0.4, error: 0.1, gustPreference: 0.25, draftPreference: 0.8 },
];

const PLAYER_COLORS: Record<string, string> = {
  coral: '#e84a38',
  sun: '#f4c845',
  mint: '#4ba888',
  ink: '#335e91',
};

const RACE_DURATION = 90;
const TOTAL_LAPS = 3;
const FIXED_STEP = 1 / 60;

function getElement<T extends HTMLElement>(selector: string): T {
  const element = document.querySelector<T>(selector);
  if (!element) throw new Error(`Missing interface element: ${selector}`);
  return element;
}

function damp(current: number, target: number, smoothing: number, delta: number): number {
  return THREE.MathUtils.lerp(current, target, 1 - Math.exp(-delta / smoothing));
}

function formatTime(seconds: number): string {
  const safe = Math.max(0, seconds);
  const minutes = Math.floor(safe / 60);
  const remainder = safe - minutes * 60;
  return `${String(minutes).padStart(2, '0')}:${remainder.toFixed(1).padStart(4, '0')}`;
}

function ordinal(place: number): string {
  if (place === 1) return 'st';
  if (place === 2) return 'nd';
  if (place === 3) return 'rd';
  return 'th';
}

export class Regatta {
  private readonly scene = new THREE.Scene();
  private readonly camera = new THREE.PerspectiveCamera(46, 1, 0.08, 280);
  private readonly renderer: THREE.WebGLRenderer;
  private readonly world: World;
  private readonly audio = new RaceAudio();
  private readonly racers: Racer[] = [];
  private readonly keys = new Set<string>();
  private readonly hud: HudElements;
  private readonly cameraTarget = new THREE.Vector3();
  private readonly desiredCamera = new THREE.Vector3();
  private readonly lookMatrix = new THREE.Matrix4();
  private readonly desiredQuaternion = new THREE.Quaternion();
  private readonly playerMarker = new THREE.Group();
  private readonly occlusionLine = new THREE.Line3();
  private readonly occlusionPoint = new THREE.Vector3();
  private readonly occlusionClosest = new THREE.Vector3();
  private mode: Mode = 'menu';
  private modeBeforePause: Mode = 'racing';
  private accumulated = 0;
  private elapsed = 0;
  private raceElapsed = 0;
  private countdownRemaining = 3.65;
  private lastCountdown = -1;
  private selectedColor = PLAYER_COLORS.coral;
  private windFrom = 0.68;
  private windSpeed = 6.5;
  private cameraShake = 0;
  private restartHeld = 0;
  private autopilot = false;
  private timeScale = 1;
  private collisions = 0;
  private fleetCollisions = 0;
  private overtakes = 0;
  private previousPlace = 4;
  private candidatePlace = 4;
  private candidatePlaceFrames = 0;
  private fpsSamples: number[] = [];
  private fps = 60;
  private menuAngle = 0;
  private raceSeed = Math.random() * Math.PI * 2;
  private cameraShoulder = 0;
  private lastFrameTime = performance.now();
  private startPending = false;
  private restartPending = false;

  constructor(container: HTMLElement) {
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.renderer.shadowMap.autoUpdate = true;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.04;
    container.appendChild(this.renderer.domElement);

    this.world = new World(this.scene);
    this.hud = {
      startScreen: getElement('#start-screen'),
      hud: getElement('#hud'),
      resultScreen: getElement('#result-screen'),
      startButton: getElement('#start-button'),
      restartButton: getElement('#restart-button'),
      position: getElement('#position'),
      ordinal: getElement('#ordinal'),
      clock: getElement('#clock'),
      lap: getElement('#lap-label'),
      gate: getElement('#gate-label'),
      windDial: getElement('#wind-dial'),
      windSpeed: getElement('#wind-speed'),
      trimState: getElement('#trim-state'),
      trimIdeal: getElement('#trim-ideal'),
      trimFill: getElement('#trim-fill'),
      trimKnob: getElement('#trim-knob'),
      controlsHint: getElement('#controls-hint'),
      centerMessage: getElement('#center-message'),
      gateArrow: getElement('#gate-arrow'),
      resultKicker: getElement('#result-kicker'),
      resultTitle: getElement('#result-title'),
      resultTimeLabel: getElement('#result-time-label'),
      resultTime: getElement('#result-time'),
      resultLine: getElement('#result-line'),
      bestTime: getElement('#best-time'),
      resultPasses: getElement('#result-passes'),
      resultBumps: getElement('#result-bumps'),
      toyTrophy: getElement('#toy-trophy'),
      impactFlash: getElement('#impact-flash'),
      speedLines: getElement('#speed-lines'),
    };

    this.createFleet();
    this.bindInput();
    this.raceSeed = Math.random() * Math.PI * 2;
    this.resetFleet();
    this.resize();

    if (import.meta.env.DEV) {
      window.__REGATTA__ = {
        start: () => this.start(),
        restart: () => this.restart(),
        setAutopilot: (enabled) => { this.autopilot = enabled; },
        setTimeScale: (scale) => { this.timeScale = clamp(scale, 0.25, 12); },
        getState: () => this.snapshot(),
      };
    }
  }

  run(): void {
    this.renderer.setAnimationLoop(() => this.frame());
  }

  private createFleet(): void {
    const playerBoat = new Boat(this.selectedColor, 'You', 24);
    const markerCanvas = document.createElement('canvas');
    markerCanvas.width = 192;
    markerCanvas.height = 96;
    const markerContext = markerCanvas.getContext('2d');
    if (markerContext) {
      markerContext.fillStyle = 'rgba(9, 28, 32, .86)';
      markerContext.beginPath();
      markerContext.roundRect(35, 8, 122, 46, 23);
      markerContext.fill();
      markerContext.beginPath();
      markerContext.moveTo(84, 54);
      markerContext.lineTo(108, 54);
      markerContext.lineTo(96, 76);
      markerContext.closePath();
      markerContext.fill();
      markerContext.fillStyle = '#f8f6ea';
      markerContext.font = '700 24px sans-serif';
      markerContext.textAlign = 'center';
      markerContext.textBaseline = 'middle';
      markerContext.fillText('YOU', 96, 31);
    }
    const markerTexture = new THREE.CanvasTexture(markerCanvas);
    markerTexture.colorSpace = THREE.SRGBColorSpace;
    const markerSprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: markerTexture, transparent: true, depthTest: false }));
    markerSprite.scale.set(1.48, 0.74, 1);
    this.playerMarker.add(markerSprite);
    this.playerMarker.position.y = 5.55;
    playerBoat.root.add(this.playerMarker);
    this.scene.add(playerBoat.root);
    this.racers.push(this.makeRacer(playerBoat, null, 3));
    RIVALS.forEach((tuning, index) => {
      const boat = new Boat(tuning.color, tuning.name, index + 7);
      this.scene.add(boat.root);
      const slots = [0, 1, 2, 4, 5];
      this.racers.push(this.makeRacer(boat, tuning, slots[index]));
    });
  }

  private makeRacer(boat: Boat, tuning: RivalTuning | null, slot: number): Racer {
    return {
      boat,
      position: new THREE.Vector2(),
      heading: 0,
      speed: 0,
      trim: 0.46,
      rudder: 0,
      spin: 0,
      checkpoint: 1,
      lap: 0,
      progress: 0,
      collisionCooldown: 0,
      stuckTime: 0,
      finishTime: null,
      slot,
      tuning,
      raceSpeedOffset: 0,
    };
  }

  private resetFleet(): void {
    const start = COURSE[0];
    const next = COURSE[1];
    const heading = Math.atan2(next.x - start.x, next.z - start.z);
    const forwardX = Math.sin(heading);
    const forwardZ = Math.cos(heading);
    const rightX = Math.cos(heading);
    const rightZ = -Math.sin(heading);

    for (const racer of this.racers) {
      const row = Math.floor(racer.slot / 2);
      const column = racer.slot % 2 === 0 ? -1 : 1;
      const stagger = column > 0 ? 1.9 : 0;
      const backOffset = 4.4 + row * 4.8 + stagger;
      racer.position.set(
        start.x - forwardX * backOffset + rightX * column * 2.35,
        start.z - forwardZ * backOffset + rightZ * column * 2.35,
      );
      racer.heading = heading;
      racer.speed = 0;
      racer.trim = 0.46;
      racer.rudder = 0;
      racer.spin = 0;
      racer.checkpoint = 1;
      racer.lap = 0;
      racer.progress = -backOffset / Math.hypot(next.x - start.x, next.z - start.z);
      racer.collisionCooldown = 0;
      racer.stuckTime = 0;
      racer.finishTime = null;
      racer.raceSpeedOffset = racer.tuning ? Math.sin(this.raceSeed + racer.slot * 1.91) * 0.035 : 0;
      this.syncBoat(racer);
    }
  }

  private bindInput(): void {
    window.addEventListener('resize', () => this.resize());
    window.addEventListener('keydown', (event) => {
      const code = event.code;
      if (['Space', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(code)) event.preventDefault();
      this.keys.add(code);
      if (code === 'Space' && this.mode === 'menu') this.start();
      if (code === 'Enter' && this.mode === 'finished') this.restart();
      if (code === 'Escape' && (this.mode === 'racing' || this.mode === 'paused')) this.togglePause();
    });
    window.addEventListener('keyup', (event) => this.keys.delete(event.code));
    window.addEventListener('blur', () => {
      this.keys.clear();
      if (this.mode === 'racing') this.togglePause();
    });

    this.hud.startButton.addEventListener('click', () => this.start());
    this.hud.restartButton.addEventListener('click', () => this.restart());
    document.querySelectorAll<HTMLButtonElement>('.swatch').forEach((swatch) => {
      swatch.addEventListener('click', () => {
        const key = swatch.dataset.color ?? 'coral';
        this.selectedColor = PLAYER_COLORS[key] ?? PLAYER_COLORS.coral;
        this.racers[0].boat.setColor(this.selectedColor);
        document.querySelectorAll<HTMLButtonElement>('.swatch').forEach((button) => {
          const active = button === swatch;
          button.classList.toggle('is-active', active);
          button.setAttribute('aria-checked', String(active));
        });
      });
    });
  }

  private resize(): void {
    const width = window.innerWidth;
    const height = window.innerHeight;
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    const pixelRatio = Math.min(window.devicePixelRatio, width < 1000 ? 1.25 : 1.5);
    this.renderer.setPixelRatio(pixelRatio);
    this.renderer.setSize(width, height);
  }

  private async start(): Promise<void> {
    if (this.mode !== 'menu' || this.startPending) return;
    this.startPending = true;
    try {
      try {
        await this.audio.unlock();
      } catch {
        // Audio is optional. The race must work on muted or restricted devices.
      }
      this.mode = 'countdown';
      this.countdownRemaining = 3.65;
      this.lastCountdown = -1;
      this.hud.startScreen.classList.add('is-hidden');
      this.hud.resultScreen.classList.add('is-hidden');
      this.hud.hud.classList.remove('is-hidden');
    } finally {
      this.startPending = false;
    }
  }

  private async restart(): Promise<void> {
    if (this.mode === 'countdown' || this.restartPending) return;
    this.restartPending = true;
    try {
      try {
        await this.audio.unlock();
      } catch {
        // Keep restart available when browser audio cannot resume.
      }
      this.raceSeed = Math.random() * Math.PI * 2;
      this.resetFleet();
      this.raceElapsed = 0;
      this.collisions = 0;
      this.fleetCollisions = 0;
      this.overtakes = 0;
      this.previousPlace = 4;
      this.candidatePlace = 4;
      this.candidatePlaceFrames = 0;
      this.restartHeld = 0;
      this.mode = 'countdown';
      this.countdownRemaining = 3.65;
      this.lastCountdown = -1;
      this.hud.resultScreen.classList.add('is-hidden');
      this.hud.hud.classList.remove('is-hidden');
    } finally {
      this.restartPending = false;
    }
  }

  private togglePause(): void {
    if (this.mode === 'paused') {
      this.mode = this.modeBeforePause;
      this.hud.centerMessage.classList.remove('is-paused');
      this.popMessage('GO');
      this.lastFrameTime = performance.now();
    } else {
      this.modeBeforePause = this.mode;
      this.mode = 'paused';
      this.hud.centerMessage.textContent = 'PAUSED';
      this.hud.centerMessage.classList.remove('is-popping');
      this.hud.centerMessage.classList.add('is-paused');
    }
  }

  private frame(): void {
    const now = performance.now();
    const rawDelta = Math.min((now - this.lastFrameTime) / 1000, 0.08);
    this.lastFrameTime = now;
    const delta = rawDelta * this.timeScale;
    this.elapsed += delta;
    this.fpsSamples.push(rawDelta > 0 ? 1 / rawDelta : 60);
    if (this.fpsSamples.length > 90) this.fpsSamples.shift();
    this.fps = this.fpsSamples.reduce((sum, value) => sum + value, 0) / this.fpsSamples.length;
    this.world.update(this.elapsed, this.racers[0]?.speed ?? 0);

    if (this.mode === 'menu') this.updateMenu(rawDelta);
    if (this.mode === 'countdown') this.updateCountdown(delta);
    if (this.mode === 'racing') {
      this.accumulated = Math.min(this.accumulated + delta, FIXED_STEP * 12);
      while (this.accumulated >= FIXED_STEP) {
        this.simulate(FIXED_STEP);
        this.accumulated -= FIXED_STEP;
      }
    }

    if (this.mode !== 'menu') this.updateRaceCamera(rawDelta);
    this.updateVisuals(rawDelta);
    this.updateHud();
    this.renderer.render(this.scene, this.camera);
  }

  private updateMenu(delta: number): void {
    const player = this.racers[0];
    this.menuAngle += delta * 0.12;
    const focus = new THREE.Vector3(player.position.x, 1.45, player.position.y);
    this.camera.position.set(
      focus.x + Math.sin(this.menuAngle) * 15.2,
      5.15 + Math.sin(this.menuAngle * 1.4) * 0.42,
      focus.z + Math.cos(this.menuAngle) * 15.2,
    );
    this.camera.lookAt(focus.x, 1.35, focus.z);
  }

  private updateCountdown(delta: number): void {
    this.updatePlayerControls(delta, false);
    this.countdownRemaining -= delta;
    const value = Math.max(0, Math.ceil(this.countdownRemaining - 0.25));
    if (value !== this.lastCountdown) {
      this.lastCountdown = value;
      this.popMessage(value > 0 ? String(value) : 'GO!');
      this.audio.countdown(value);
    }
    if (this.countdownRemaining <= 0) {
      this.mode = 'racing';
      this.raceElapsed = 0;
    }
  }

  private simulate(delta: number): void {
    this.raceElapsed += delta;
    this.windFrom = 0.68 + Math.sin(this.raceElapsed * 0.045 + this.raceSeed) * 0.2;
    this.windSpeed = 6.5 + Math.sin(this.raceElapsed * 0.31) * 0.32;
    this.updateProgressAndRanks(false);

    this.racers.forEach((racer, index) => {
      if (racer.finishTime !== null) {
        racer.speed = damp(racer.speed, 3.8, 0.8, delta);
        return;
      }
      const isPlayer = index === 0;
      if (isPlayer && !this.autopilot) this.updatePlayerControls(delta, true);
      else this.updateAI(racer, index, delta);
      this.advanceRacer(racer, index, delta);
    });

    this.resolveCollisions(delta);
    this.updateProgressAndRanks(true);
    const player = this.racers[0];
    if (player.finishTime !== null || this.raceElapsed >= RACE_DURATION) this.finishRace();

    if (this.keys.has('KeyR')) {
      this.restartHeld += delta;
      if (this.restartHeld >= 0.7) void this.restart();
    } else {
      this.restartHeld = 0;
    }
  }

  private updatePlayerControls(delta: number, moving: boolean): void {
    const player = this.racers[0];
    const left = this.keys.has('KeyA') || this.keys.has('ArrowLeft');
    const right = this.keys.has('KeyD') || this.keys.has('ArrowRight');
    const trimIn = this.keys.has('KeyW') || this.keys.has('ArrowUp');
    const ease = this.keys.has('KeyS') || this.keys.has('ArrowDown');
    const rudderTarget = Number(left) - Number(right);
    player.rudder = damp(player.rudder, rudderTarget, 0.14, delta);
    player.trim = clamp(player.trim + (Number(ease) - Number(trimIn)) * 0.5 * delta, 0, 1);
    if (!trimIn && !ease) {
      const ideal = optimalTrim(angleDelta(player.heading, this.windFrom));
      if (Math.abs(player.trim - ideal) < PERFECT_TRIM_WINDOW + 0.06) {
        player.trim = damp(player.trim, ideal, 0.32, delta);
      }
    }
    if (!moving) player.speed = 0;
  }

  private updateAI(racer: Racer, index: number, delta: number): void {
    const tuning = racer.tuning ?? {
      name: 'Autopilot', color: '', speed: 1, aggression: 0.32, error: 0.035, gustPreference: 0.4, draftPreference: 0.4,
    };
    const target = COURSE[racer.checkpoint];
    let targetX = target.x;
    let targetZ = target.z;

    const next = COURSE[(racer.checkpoint + 1) % COURSE.length];
    const pathX = next.x - target.x;
    const pathZ = next.z - target.z;
    const pathLength = Math.max(1, Math.hypot(pathX, pathZ));
    const side = Math.sin(this.raceElapsed * (0.25 + index * 0.013) + index * 2.3 + this.raceSeed * 0.7);
    const errorWave = side * tuning.error * 5.5;
    const lane = (racer.slot - 2.5) * 1.55;
    targetX += (-pathZ / pathLength) * (errorWave + lane);
    targetZ += (pathX / pathLength) * (errorWave + lane);

    if (tuning.gustPreference > 0.5) {
      const gust = this.world.gusts.find((zone) => Math.hypot(zone.x - racer.position.x, zone.z - racer.position.y) < 16);
      if (gust) {
        targetX = THREE.MathUtils.lerp(targetX, gust.x, 0.22);
        targetZ = THREE.MathUtils.lerp(targetZ, gust.z, 0.22);
      }
    }

    let desired = Math.atan2(targetX - racer.position.x, targetZ - racer.position.y);
    const intoWind = Math.abs(angleDelta(desired, this.windFrom));
    if (intoWind < 0.56) {
      const tackSide = Math.sin(this.raceElapsed * 0.18 + index * 1.7 + this.raceSeed) >= 0 ? 1 : -1;
      desired = this.windFrom + tackSide * 0.68;
    }

    let avoid = 0;
    this.racers.forEach((other) => {
      if (other === racer) return;
      const dx = other.position.x - racer.position.x;
      const dz = other.position.y - racer.position.y;
      const distance = Math.hypot(dx, dz);
      if (distance < 9 && distance > 0.01) {
        const bearing = Math.atan2(dx, dz);
        const relative = angleDelta(racer.heading, bearing);
        if (Math.abs(relative) < 1.5) avoid -= Math.sign(relative || 1) * (9 - distance) * (0.3 - tuning.aggression * 0.055);
      }
    });
    const steeringError = angleDelta(racer.heading, desired) + avoid;
    racer.rudder = damp(racer.rudder, clamp(steeringError * 1.65, -1, 1), 0.14, delta);
    const windAngle = angleDelta(racer.heading, this.windFrom);
    racer.trim = damp(racer.trim, optimalTrim(windAngle), 0.24 + tuning.error * 0.4, delta);
  }

  private advanceRacer(racer: Racer, index: number, delta: number): void {
    racer.collisionCooldown = Math.max(0, racer.collisionCooldown - delta);
    const windAngle = angleDelta(racer.heading, this.windFrom);
    const gust = this.gustStrength(racer);
    const draft = this.draftStrength(racer);
    let speedScale = ((racer.tuning?.speed ?? 1) + racer.raceSpeedOffset) * 0.89;
    if (index > 0 && RACE_DURATION - this.raceElapsed > 15) {
      const place = this.placeOf(racer);
      speedScale *= place === 1 ? 0.98 : 1 + ((place - 1) / 5) * 0.035;
    }
    const desiredSpeed = Math.max(3.8, targetSpeed({
      windAngle,
      trim: racer.trim,
      gustStrength: gust,
      draftStrength: draft,
      speedScale,
    }));
    const acceleration = desiredSpeed > racer.speed ? 4.4 : 1.55;
    racer.speed += clamp(desiredSpeed - racer.speed, -acceleration * delta, acceleration * delta);
    racer.speed = Math.max(0, racer.speed);

    const speedTurn = clamp(racer.speed / 6, 0.22, 1.18);
    racer.heading += racer.rudder * 1.48 * speedTurn * delta + racer.spin * delta;
    racer.spin = damp(racer.spin, 0, 0.36, delta);
    racer.position.x += Math.sin(racer.heading) * racer.speed * delta;
    racer.position.y += Math.cos(racer.heading) * racer.speed * delta;

    const boundary = Math.hypot(racer.position.x / 50, racer.position.y / 42);
    if (boundary > 1) {
      racer.position.x /= boundary;
      racer.position.y /= boundary;
      racer.position.multiplyScalar(0.992);
      racer.speed *= 0.82;
      racer.spin += Math.sign(racer.position.x || 1) * 0.8;
      racer.stuckTime += delta;
    } else {
      racer.stuckTime = Math.max(0, racer.stuckTime - delta * 2);
    }

    if (racer.stuckTime > 1.2) {
      const target = COURSE[racer.checkpoint];
      racer.heading = Math.atan2(target.x - racer.position.x, target.z - racer.position.y);
      racer.speed = 3.8;
      racer.stuckTime = 0;
    }
  }

  private resolveCollisions(delta: number): void {
    for (let first = 0; first < this.racers.length; first += 1) {
      const a = this.racers[first];
      for (let second = first + 1; second < this.racers.length; second += 1) {
        const b = this.racers[second];
        const dx = b.position.x - a.position.x;
        const dz = b.position.y - a.position.y;
        const distance = Math.hypot(dx, dz);
        if (distance >= 1.32 || distance <= 0.001) continue;
        const nx = dx / distance;
        const nz = dz / distance;
        const overlap = (1.4 - distance) * 0.58;
        a.position.x -= nx * overlap;
        a.position.y -= nz * overlap;
        b.position.x += nx * overlap;
        b.position.y += nz * overlap;
        if (a.collisionCooldown === 0 && b.collisionCooldown === 0) {
          const strength = clamp((a.speed + b.speed) / 14, 0.35, 1);
          a.speed *= 0.88;
          b.speed *= 0.88;
          a.spin -= (0.55 + strength * 0.65) * Math.sign(angleDelta(a.heading, Math.atan2(dx, dz)) || 1);
          b.spin += (0.55 + strength * 0.65) * Math.sign(angleDelta(b.heading, Math.atan2(-dx, -dz)) || 1);
          a.collisionCooldown = 2.8;
          b.collisionCooldown = 2.8;
          this.fleetCollisions += 1;
          if (first === 0 || second === 0) {
            this.collisions += 1;
            this.playerImpact(strength);
          }
        }
      }

      for (const obstacle of this.world.obstacles) {
        const dx = a.position.x - obstacle.x;
        const dz = a.position.y - obstacle.z;
        const distance = Math.hypot(dx, dz);
        const minimum = obstacle.radius + 0.85;
        if (distance >= minimum || distance <= 0.001) continue;
        a.position.set(obstacle.x + dx / distance * minimum, obstacle.z + dz / distance * minimum);
        if (a.collisionCooldown === 0) {
          a.speed *= 0.78;
          a.spin += Math.sign(angleDelta(a.heading, Math.atan2(dx, dz)) || 1) * 1.8;
          a.collisionCooldown = 0.75;
          this.fleetCollisions += 1;
          if (first === 0) {
            this.collisions += 1;
            this.playerImpact(0.9);
          }
        }
      }
    }
    this.cameraShake = Math.max(0, this.cameraShake - delta * 1.7);
  }

  private gustStrength(racer: Racer): number {
    let strength = 0;
    for (const gust of this.world.gusts) {
      const distance = Math.hypot(racer.position.x - gust.x, racer.position.y - gust.z);
      strength = Math.max(strength, clamp(1 - distance / gust.radius, 0, 1));
    }
    return strength;
  }

  private draftStrength(racer: Racer): number {
    let draft = 0;
    for (const other of this.racers) {
      if (other === racer) continue;
      const dx = racer.position.x - other.position.x;
      const dz = racer.position.y - other.position.y;
      const forward = dx * Math.sin(other.heading) + dz * Math.cos(other.heading);
      const lateral = Math.abs(dx * Math.cos(other.heading) - dz * Math.sin(other.heading));
      const behind = -forward;
      if (behind > 2.8 && behind < 14 && lateral < 2.4) {
        draft = Math.max(draft, (1 - lateral / 2.4) * Math.sin((behind - 2.8) / 11.2 * Math.PI));
      }
    }
    return clamp(draft, 0, 1);
  }

  private updateProgressAndRanks(countOvertakes: boolean): void {
    for (const racer of this.racers) {
      if (racer.finishTime !== null) {
        racer.progress = TOTAL_LAPS * COURSE.length + (RACE_DURATION - racer.finishTime) * 0.001;
        continue;
      }
      const target = COURSE[racer.checkpoint];
      const previousIndex = (racer.checkpoint - 1 + COURSE.length) % COURSE.length;
      const previous = COURSE[previousIndex];
      const segmentX = target.x - previous.x;
      const segmentZ = target.z - previous.z;
      const segmentLengthSquared = segmentX * segmentX + segmentZ * segmentZ;
      const distanceToTarget = Math.hypot(target.x - racer.position.x, target.z - racer.position.y);
      const fraction = clamp(
        ((racer.position.x - previous.x) * segmentX + (racer.position.y - previous.z) * segmentZ) / segmentLengthSquared,
        racer.lap === 0 ? -0.75 : 0,
        0.99,
      );
      const completed = racer.checkpoint === 0 ? COURSE.length - 1 : racer.checkpoint - 1;
      racer.progress = racer.lap * COURSE.length + completed + fraction;

      if (distanceToTarget < 6.6) {
        if (racer.checkpoint === 0) racer.lap += 1;
        racer.checkpoint = (racer.checkpoint + 1) % COURSE.length;
        if (racer.lap >= TOTAL_LAPS) racer.finishTime = this.raceElapsed;
        if (racer === this.racers[0]) this.audio.gate();
      }
    }

    if (countOvertakes) {
      const place = this.placeOf(this.racers[0]);
      if (place !== this.candidatePlace) {
        this.candidatePlace = place;
        this.candidatePlaceFrames = 0;
      } else {
        this.candidatePlaceFrames += 1;
      }
      if (this.candidatePlaceFrames >= 60 && this.candidatePlace !== this.previousPlace) {
        if (this.candidatePlace < this.previousPlace) this.overtakes += this.previousPlace - this.candidatePlace;
        this.previousPlace = this.candidatePlace;
        this.candidatePlaceFrames = 0;
      }
    }
  }

  private placeOf(racer: Racer): number {
    return [...this.racers]
      .sort((a, b) => {
        if (a.finishTime !== null && b.finishTime !== null) return a.finishTime - b.finishTime;
        if (a.finishTime !== null) return -1;
        if (b.finishTime !== null) return 1;
        return b.progress - a.progress;
      })
      .indexOf(racer) + 1;
  }

  private playerImpact(strength: number): void {
    this.cameraShake = Math.max(this.cameraShake, 0.16 * strength);
    this.audio.impact(strength);
    this.hud.impactFlash.classList.remove('is-active');
    void this.hud.impactFlash.offsetWidth;
    this.hud.impactFlash.classList.add('is-active');
  }

  private syncBoat(racer: Racer): void {
    racer.boat.root.position.set(
      racer.position.x,
      waterHeight(racer.position.x, racer.position.y, this.elapsed) + 0.28,
      racer.position.y,
    );
    racer.boat.root.rotation.y = racer.heading;
  }

  private updateVisuals(delta: number): void {
    this.playerMarker.visible = false;
    this.playerMarker.position.y = 5.55 + Math.sin(this.elapsed * 3.2) * 0.06;
    this.playerMarker.rotation.y = -this.racers[0].heading;
    for (const racer of this.racers) {
      this.syncBoat(racer);
      racer.boat.updateVisual(
        this.elapsed,
        racer.rudder + racer.spin * 0.2,
        racer.speed,
        racer.trim,
        angleDelta(racer.heading, this.windFrom),
      );
    }
    const playerPosition = this.racers[0].boat.root.position;
    this.occlusionPoint.set(playerPosition.x, playerPosition.y + 1.4, playerPosition.z);
    this.occlusionLine.set(this.camera.position, this.occlusionPoint);
    this.racers.slice(1).forEach((racer) => {
      const rivalPosition = racer.boat.root.position;
      const nearby = rivalPosition.distanceTo(playerPosition) < 14;
      this.occlusionPoint.set(rivalPosition.x, rivalPosition.y + 2.4, rivalPosition.z);
      this.occlusionLine.closestPointToPoint(this.occlusionPoint, true, this.occlusionClosest);
      const blocksCamera = nearby && this.occlusionClosest.distanceTo(this.occlusionPoint) < 1.3;
      racer.boat.sailMaterial.opacity = damp(racer.boat.sailMaterial.opacity, blocksCamera ? 0.82 : 0.96, 0.16, delta);
      racer.boat.sailMaterial.depthWrite = true;
    });
    this.world.setActiveGate(this.racers[0].checkpoint);
  }

  private updateRaceCamera(delta: number): void {
    const player = this.racers[0];
    const speedRatio = clamp((player.speed - 3.2) / 6.2, 0, 1);
    const backDistance = 15.8 - speedRatio * 1.35;
    const windAngle = angleDelta(player.heading, this.windFrom);
    const shoulderTarget = windAngle >= 0 ? -4.2 : 4.2;
    this.cameraShoulder = damp(this.cameraShoulder, shoulderTarget, 0.45, delta);
    const rightX = Math.cos(player.heading);
    const rightZ = -Math.sin(player.heading);
    const shakeX = (Math.random() - 0.5) * this.cameraShake;
    const shakeY = (Math.random() - 0.5) * this.cameraShake;
    this.desiredCamera.set(
      player.position.x - Math.sin(player.heading) * backDistance + shakeX,
      waterHeight(player.position.x, player.position.y, this.elapsed) + 5.35 - speedRatio * 0.75 + shakeY,
      player.position.y - Math.cos(player.heading) * backDistance,
    );
    this.desiredCamera.x += rightX * this.cameraShoulder;
    this.desiredCamera.z += rightZ * this.cameraShoulder;
    this.camera.position.lerp(this.desiredCamera, 1 - Math.exp(-delta / 0.16));
    this.cameraTarget.set(
      player.position.x + Math.sin(player.heading) * (7 + speedRatio * 2.2),
      1.1,
      player.position.y + Math.cos(player.heading) * (7 + speedRatio * 2.2),
    );
    this.cameraTarget.x += rightX * this.cameraShoulder * 0.18;
    this.cameraTarget.z += rightZ * this.cameraShoulder * 0.18;
    this.lookMatrix.lookAt(this.camera.position, this.cameraTarget, THREE.Object3D.DEFAULT_UP);
    this.desiredQuaternion.setFromRotationMatrix(this.lookMatrix);
    this.camera.quaternion.slerp(this.desiredQuaternion, 1 - Math.exp(-delta / 0.12));
    this.camera.fov = damp(this.camera.fov, 50 + speedRatio * 8, 0.18, delta);
    this.camera.updateProjectionMatrix();
  }

  private updateHud(): void {
    if (this.mode === 'menu') return;
    const player = this.racers[0];
    const place = this.placeOf(player);
    const windAngle = angleDelta(player.heading, this.windFrom);
    const ideal = optimalTrim(windAngle);
    const quality = trimEfficiency(player.trim, ideal);
    this.hud.position.textContent = String(place);
    this.hud.ordinal.textContent = ordinal(place);
    this.hud.clock.textContent = formatTime(RACE_DURATION - this.raceElapsed);
    this.hud.lap.textContent = `Lap ${Math.min(player.lap + 1, TOTAL_LAPS)} / ${TOTAL_LAPS}`;
    this.hud.gate.textContent = `Gate ${player.checkpoint + 1} / ${COURSE.length}`;
    this.hud.windSpeed.textContent = this.windSpeed.toFixed(1);
    this.hud.windDial.style.transform = `rotate(${THREE.MathUtils.radToDeg(this.windFrom - player.heading)}deg)`;
    this.hud.trimKnob.style.left = `${player.trim * 100}%`;
    this.hud.trimFill.style.width = `${player.trim * 100}%`;
    const idealStart = clamp(ideal - PERFECT_TRIM_WINDOW, 0, 1);
    const idealEnd = clamp(ideal + PERFECT_TRIM_WINDOW, 0, 1);
    this.hud.trimIdeal.style.left = `${idealStart * 100}%`;
    this.hud.trimIdeal.style.width = `${(idealEnd - idealStart) * 100}%`;
    this.hud.trimState.textContent = quality > 0.98 ? 'PERFECT' : quality > 0.86 ? 'GOOD' : quality > 0.7 ? 'LOOSE' : 'FLAPPING';
    this.hud.trimState.style.color = quality > 0.86 ? '#2b8169' : quality > 0.7 ? '#b47620' : '#e84a38';
    this.hud.controlsHint.classList.toggle('is-faded', this.raceElapsed > 12);
    const rush = clamp((player.speed - 3.6) / 5.8, 0, 1);
    this.hud.speedLines.classList.toggle('is-fast', rush > 0.04);
    this.hud.speedLines.style.opacity = String(rush * 0.09);
    this.audio.update(player.speed / 9.4, quality, this.mode === 'racing');

    const gate = COURSE[player.checkpoint];
    const worldMarker = new THREE.Vector3(gate.x, 3.4, gate.z);
    const localMarker = this.camera.worldToLocal(worldMarker.clone());
    const behind = localMarker.z > 0;
    const marker = worldMarker.project(this.camera);
    const courseDelta = angleDelta(player.heading, Math.atan2(gate.x - player.position.x, gate.z - player.position.y));
    const left = behind ? (courseDelta >= 0 ? 88 : 12) : clamp(50 + marker.x * 42, 12, 88);
    const top = behind ? 44 : clamp(45 - marker.y * 35, 17, 62);
    this.hud.gateArrow.style.left = `${left}%`;
    this.hud.gateArrow.style.top = `${top}%`;
    this.hud.gateArrow.style.opacity = marker.z < 1 || behind ? '1' : '0';
    const gateCopy = this.hud.gateArrow.querySelector('small');
    if (gateCopy) gateCopy.textContent = behind ? 'Turn around' : 'Next gate';
  }

  private popMessage(message: string): void {
    this.hud.centerMessage.textContent = message;
    this.hud.centerMessage.classList.remove('is-paused');
    this.hud.centerMessage.classList.remove('is-popping');
    void this.hud.centerMessage.offsetWidth;
    this.hud.centerMessage.classList.add('is-popping');
  }

  private finishRace(): void {
    if (this.mode === 'finished') return;
    this.mode = 'finished';
    const player = this.racers[0];
    const place = this.placeOf(player);
    const timedOut = player.finishTime === null;
    const resultTime = player.finishTime ?? RACE_DURATION;
    this.audio.finish(place);
    this.hud.hud.classList.add('is-hidden');
    this.hud.resultScreen.classList.remove('is-hidden');
    this.hud.resultKicker.textContent = timedOut ? 'Time at the horn' : 'Race complete';
    this.hud.resultTitle.textContent = `${place}${ordinal(place)} place`;
    this.hud.resultScreen.classList.toggle('is-winner', place === 1 && !timedOut);
    this.hud.toyTrophy.setAttribute('aria-hidden', String(place !== 1 || timedOut));
    this.hud.resultTimeLabel.textContent = timedOut ? 'Progress' : 'Your time';
    this.hud.resultTime.textContent = timedOut
      ? `Lap ${Math.min(player.lap + 1, TOTAL_LAPS)} • Gate ${player.checkpoint + 1}`
      : formatTime(resultTime);
    let bestTime = Number.NaN;
    try {
      bestTime = Number.parseFloat(localStorage.getItem('puddle-cup-best') ?? '');
      if (!timedOut && (!Number.isFinite(bestTime) || resultTime < bestTime)) {
        bestTime = resultTime;
        localStorage.setItem('puddle-cup-best', bestTime.toFixed(3));
      }
    } catch {
      if (!timedOut) bestTime = resultTime;
    }
    this.hud.bestTime.textContent = Number.isFinite(bestTime) ? formatTime(bestTime) : '—';
    this.hud.resultPasses.textContent = String(this.overtakes);
    this.hud.resultBumps.textContent = String(this.collisions);
    this.hud.resultLine.textContent = place === 1
      ? 'The tiny trophy is yours. Defend it.'
      : place <= 3
        ? 'A toy-boat podium. One cleaner tack wins it.'
        : 'The puddle wants a rematch.';
  }

  private snapshot(): RaceSnapshot {
    const player = this.racers[0];
    const windAngle = angleDelta(player.heading, this.windFrom);
    return {
      mode: this.mode,
      elapsed: this.raceElapsed,
      remaining: Math.max(0, RACE_DURATION - this.raceElapsed),
      fps: this.fps,
      collisions: this.collisions,
      fleetCollisions: this.fleetCollisions,
      overtakes: this.overtakes,
      player: {
        place: this.placeOf(player),
        lap: Math.min(player.lap + 1, TOTAL_LAPS),
        checkpoint: player.checkpoint + 1,
        speed: player.speed,
        heading: player.heading,
        trim: player.trim,
        trimQuality: trimEfficiency(player.trim, optimalTrim(windAngle)),
        x: player.position.x,
        z: player.position.y,
      },
      racers: this.racers.map((racer) => ({
        name: racer.boat.name,
        place: this.placeOf(racer),
        lap: Math.min(racer.lap + 1, TOTAL_LAPS),
        checkpoint: racer.checkpoint + 1,
        speed: racer.speed,
      })),
    };
  }
}
