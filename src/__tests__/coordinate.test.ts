import { describe, expect, it } from '@jest/globals';
import {
  fromProviderCamera,
  fromProviderCoordinate,
  toProviderCamera,
  toProviderCoordinate,
} from '../coordinate';
import type { Camera } from '../types';

const BEIJING: Camera = {
  center: { latitude: 39.9087, longitude: 116.3975 },
  heading: 90,
  pitch: 30,
  zoom: 12,
  altitude: 1000,
};

describe('toProviderCamera', () => {
  it('returns undefined for an undefined camera', () => {
    expect(toProviderCamera(undefined, 'gcj02')).toBeUndefined();
  });

  it('flattens the center and leaves gcj02 untouched', () => {
    const native = toProviderCamera(BEIJING, 'gcj02');

    expect(native).toEqual({
      latitude: BEIJING.center.latitude,
      longitude: BEIJING.center.longitude,
      heading: 90,
      pitch: 30,
      zoom: 12,
      altitude: 1000,
    });
  });

  it('converts a wgs84 center into gcj02', () => {
    const native = toProviderCamera(BEIJING, 'wgs84');
    const expected = toProviderCoordinate(BEIJING.center, 'wgs84');

    expect(native?.latitude).toBeCloseTo(expected.latitude, 10);
    expect(native?.longitude).toBeCloseTo(expected.longitude, 10);
    // wgs84 != gcj02 inside China, so the shift must be non-zero.
    expect(native?.latitude).not.toBe(BEIJING.center.latitude);
  });

  it('defaults a missing altitude to 0', () => {
    const noAltitude: Camera = {
      center: BEIJING.center,
      heading: 0,
      pitch: 0,
      zoom: 10,
    };
    expect(toProviderCamera(noAltitude, 'gcj02')?.altitude).toBe(0);
  });
});

describe('fromProviderCamera', () => {
  it('rebuilds the RNM { center } shape and inverts the conversion', () => {
    const native = toProviderCamera(BEIJING, 'wgs84')!;
    const roundTripped = fromProviderCamera(native, 'wgs84');

    expect(roundTripped.center.latitude).toBeCloseTo(
      BEIJING.center.latitude,
      4
    );
    expect(roundTripped.center.longitude).toBeCloseTo(
      BEIJING.center.longitude,
      4
    );
    expect(roundTripped.heading).toBe(90);
    expect(roundTripped.zoom).toBe(12);
  });
});

describe('fromProviderCoordinate', () => {
  it('is the inverse of toProviderCoordinate for gcj02 (identity)', () => {
    const coord = { latitude: 31.23, longitude: 121.47 };
    expect(fromProviderCoordinate(coord, 'gcj02')).toEqual(coord);
  });
});
