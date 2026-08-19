export const TAU = Math.PI * 2;

const CRUISE_SPEED = 6.0;
const MAX_SPEED = 8.2;
const GUST_MAX_SPEED = 9.4;
const REFERENCE_SPEED = CRUISE_SPEED / 0.72;
const GUST_BOOST = 0.3;
const DRAFT_BOOST = 0.12;
export const PERFECT_TRIM_WINDOW = 0.14;
const MIN_TRIM_EFFICIENCY = 0.68;

const WIND_SPEED_CURVE: ReadonlyArray<readonly [angle: number, multiplier: number]> = [
  [0, 0.05],
  [35, 0.55],
  [55, 0.82],
  [90, 1],
  [120, 0.95],
  [180, 0.72],
];

export function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

export function lerp(start: number, end: number, amount: number): number {
  return start + (end - start) * amount;
}

/** Returns the shortest signed rotation from `from` to `to` in [-PI, PI). */
export function angleDelta(from: number, to: number): number {
  return ((to - from + Math.PI) % TAU + TAU) % TAU - Math.PI;
}

function normalizedWindAngle(angleRadFromIntoWind: number): number {
  return Math.abs(angleDelta(0, angleRadFromIntoWind));
}

/**
 * Returns the point-of-sail speed multiplier. Zero radians points directly
 * into the wind. PI radians points directly downwind.
 */
export function windAngleMultiplier(angleRadFromIntoWind: number): number {
  const degrees = normalizedWindAngle(angleRadFromIntoWind) * (180 / Math.PI);

  for (let index = 1; index < WIND_SPEED_CURVE.length; index += 1) {
    const [endAngle, endMultiplier] = WIND_SPEED_CURVE[index];

    if (degrees <= endAngle) {
      const [startAngle, startMultiplier] = WIND_SPEED_CURVE[index - 1];
      const amount = (degrees - startAngle) / (endAngle - startAngle);
      return lerp(startMultiplier, endMultiplier, amount);
    }
  }

  return WIND_SPEED_CURVE[WIND_SPEED_CURVE.length - 1][1];
}

/** Returns normalized sail trim: 0 is tight and 1 is fully eased. */
export function optimalTrim(angleRadFromIntoWind: number): number {
  const degrees = normalizedWindAngle(angleRadFromIntoWind) * (180 / Math.PI);
  if (degrees <= 35 + 1e-9) return 0;
  if (degrees >= 150 - 1e-9) return 1;
  return clamp((degrees - 35) / 115, 0, 1);
}

/**
 * Keeps a forgiving fourteen-percent sweet spot, then smoothly falls to 68 percent.
 * Bad trim costs speed but cannot stop a moving boat.
 */
export function trimEfficiency(trim: number, ideal: number): number {
  const error = Math.abs(clamp(trim, 0, 1) - clamp(ideal, 0, 1));

  if (error <= PERFECT_TRIM_WINDOW) {
    return 1;
  }

  const penalty = clamp((error - PERFECT_TRIM_WINDOW) / 0.46, 0, 1);
  const smoothPenalty = penalty * penalty * (3 - 2 * penalty);
  return lerp(1, MIN_TRIM_EFFICIENCY, smoothPenalty);
}

interface TargetSpeedInput {
  windAngle: number;
  trim: number;
  gustStrength: number;
  draftStrength: number;
  speedScale?: number;
}

export function targetSpeed({
  windAngle,
  trim,
  gustStrength,
  draftStrength,
  speedScale = 1,
}: TargetSpeedInput): number {
  const pointOfSail = windAngleMultiplier(windAngle);
  const idealTrim = optimalTrim(windAngle);
  const trimFactor = trimEfficiency(trim, idealTrim);
  const boost =
    1 +
    clamp(gustStrength, 0, 1) * GUST_BOOST +
    clamp(draftStrength, 0, 1) * DRAFT_BOOST;
  const sailingSpeed = Math.min(MAX_SPEED, REFERENCE_SPEED * pointOfSail * trimFactor);
  const rawSpeed = sailingSpeed * boost * Math.max(0, speedScale);

  return clamp(rawSpeed, 0, GUST_MAX_SPEED);
}
