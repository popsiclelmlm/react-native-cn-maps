import { describe, expect, it } from '@jest/globals';
import { Commands } from '../MapViewNativeComponent';

describe('MapView native commands (M13)', () => {
  it('exposes takeSnapshot among the codegen commands', () => {
    const c = Commands as unknown as Record<string, unknown>;
    expect(typeof c.takeSnapshot).toBe('function');
  });

  it('exposes the M15 commands (setMapBoundaries, getMarkersFrames)', () => {
    const c = Commands as unknown as Record<string, unknown>;
    expect(typeof c.setMapBoundaries).toBe('function');
    expect(typeof c.getMarkersFrames).toBe('function');
  });

  it('still exposes the M6 query commands', () => {
    const c = Commands as unknown as Record<string, unknown>;
    expect(typeof c.getCamera).toBe('function');
    expect(typeof c.getMapBoundaries).toBe('function');
    expect(typeof c.pointForCoordinate).toBe('function');
    expect(typeof c.coordinateForPoint).toBe('function');
  });
});
