import { describe, expect, it } from "vitest";

import {
  TAU,
  PERFECT_TRIM_WINDOW,
  angleDelta,
  clamp,
  lerp,
  optimalTrim,
  targetSpeed,
  trimEfficiency,
  windAngleMultiplier,
} from "./sailing";

const degrees = (value: number) => value * (Math.PI / 180);

describe("sailing math", () => {
  it("clamps and interpolates scalar values", () => {
    expect(clamp(-2, 0, 1)).toBe(0);
    expect(clamp(2, 0, 1)).toBe(1);
    expect(clamp(0.4, 0, 1)).toBe(0.4);
    expect(lerp(4, 8, 0.25)).toBe(5);
  });

  it("finds the shortest signed angle delta", () => {
    expect(angleDelta(degrees(350), degrees(10))).toBeCloseTo(degrees(20));
    expect(angleDelta(degrees(10), degrees(350))).toBeCloseTo(degrees(-20));
    expect(angleDelta(0, TAU)).toBeCloseTo(0);
  });

  it("interpolates the point-of-sail curve and accepts signed angles", () => {
    expect(windAngleMultiplier(0)).toBeCloseTo(0.05);
    expect(windAngleMultiplier(degrees(35))).toBeCloseTo(0.55);
    expect(windAngleMultiplier(degrees(90))).toBeCloseTo(1);
    expect(windAngleMultiplier(degrees(-120))).toBeCloseTo(0.95);
    expect(windAngleMultiplier(degrees(180))).toBeCloseTo(0.72);
    expect(windAngleMultiplier(degrees(45))).toBeCloseTo(0.685);
  });

  it("maps wind angle to a tight-to-eased optimal trim", () => {
    expect(optimalTrim(0)).toBe(0);
    expect(optimalTrim(degrees(35))).toBe(0);
    expect(optimalTrim(degrees(92.5))).toBeCloseTo(0.5);
    expect(optimalTrim(degrees(150))).toBe(1);
    expect(optimalTrim(degrees(-180))).toBe(1);
  });

  it("gives perfect trim a forgiving window and meaningful falloff", () => {
    expect(PERFECT_TRIM_WINDOW).toBe(0.14);
    expect(trimEfficiency(0.5, 0.5)).toBe(1);
    expect(trimEfficiency(0.64, 0.5)).toBe(1);
    expect(trimEfficiency(0, 1)).toBeCloseTo(0.68);
    expect(trimEfficiency(1, 0)).toBeCloseTo(0.68);
    expect(trimEfficiency(0.25, 0.5)).toBeGreaterThan(0.68);
    expect(trimEfficiency(0.25, 0.5)).toBeLessThan(1);
  });

  it("hits the cruise, maximum, gust, and draft tuning targets", () => {
    expect(
      targetSpeed({
        windAngle: degrees(180),
        trim: 1,
        gustStrength: 0,
        draftStrength: 0,
      }),
    ).toBeCloseTo(6);

    expect(
      targetSpeed({
        windAngle: degrees(90),
        trim: optimalTrim(degrees(90)),
        gustStrength: 0,
        draftStrength: 0,
      }),
    ).toBeCloseTo(8.2);

    expect(
      targetSpeed({
        windAngle: degrees(90),
        trim: optimalTrim(degrees(90)),
        gustStrength: 1,
        draftStrength: 0,
      }),
    ).toBe(9.4);

    expect(
      targetSpeed({
        windAngle: degrees(90),
        trim: optimalTrim(degrees(90)),
        gustStrength: 0,
        draftStrength: 1,
      }),
    ).toBeCloseTo(9.184);
  });

  it("keeps poor trim moving while making it substantially slower", () => {
    const windAngle = degrees(90);
    const ideal = optimalTrim(windAngle);
    const wellTrimmed = targetSpeed({
      windAngle,
      trim: ideal,
      gustStrength: 0,
      draftStrength: 0,
    });
    const poorlyTrimmed = targetSpeed({
      windAngle,
      trim: 1,
      gustStrength: 0,
      draftStrength: 0,
    });

    expect(poorlyTrimmed).toBeGreaterThan(0);
    expect(poorlyTrimmed).toBeLessThan(wellTrimmed * 0.8);
  });

  it("clamps boost strengths and applies the optional speed scale", () => {
    const windAngle = degrees(180);
    const baseline = targetSpeed({
      windAngle,
      trim: 1,
      gustStrength: 0,
      draftStrength: 0,
    });
    const scaled = targetSpeed({
      windAngle,
      trim: 1,
      gustStrength: -5,
      draftStrength: -2,
      speedScale: 0.9,
    });

    expect(scaled).toBeCloseTo(baseline * 0.9);
  });
});
