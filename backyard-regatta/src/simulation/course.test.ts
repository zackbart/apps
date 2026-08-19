import { describe, expect, it } from 'vitest';
import { COURSE } from '../game/World';

function segmentLength(index: number): number {
  const point = COURSE[index];
  const next = COURSE[(index + 1) % COURSE.length];
  return Math.hypot(next.x - point.x, next.z - point.z);
}

function distanceToSegment(x: number, z: number, index: number): number {
  const point = COURSE[index];
  const next = COURSE[(index + 1) % COURSE.length];
  const dx = next.x - point.x;
  const dz = next.z - point.z;
  const lengthSquared = dx * dx + dz * dz;
  const amount = Math.min(1, Math.max(0, ((x - point.x) * dx + (z - point.z) * dz) / lengthSquared));
  return Math.hypot(x - (point.x + dx * amount), z - (point.z + dz * amount));
}

describe('race course', () => {
  it('uses six readable gates and a three-lap-friendly perimeter', () => {
    expect(COURSE).toHaveLength(6);
    const perimeter = COURSE.reduce((total, _point, index) => total + segmentLength(index), 0);
    expect(perimeter).toBeGreaterThan(160);
    expect(perimeter).toBeLessThan(170);
  });

  it('keeps every leg long enough for sailing decisions', () => {
    COURSE.forEach((_point, index) => {
      expect(segmentLength(index)).toBeGreaterThan(25);
      expect(segmentLength(index)).toBeLessThan(31);
    });
  });

  it('keeps the racing line clear of the central backyard toys', () => {
    const obstacles = [
      { x: 0, z: -2, radius: 5.2 },
      { x: -8, z: 4, radius: 3.4 },
      { x: 11, z: 5, radius: 2.1 },
    ];

    for (const obstacle of obstacles) {
      const clearance = Math.min(...COURSE.map((_point, index) => distanceToSegment(obstacle.x, obstacle.z, index)));
      expect(clearance).toBeGreaterThan(obstacle.radius + 6);
    }
  });
});
