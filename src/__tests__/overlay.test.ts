import { describe, expect, it } from '@jest/globals';
import Overlay, {
  Overlay as NamedOverlay,
  normalizeOverlayBounds,
} from '../MapOverlay';

describe('normalizeOverlayBounds (M12)', () => {
  it('derives sw (min) and ne (max) regardless of corner order', () => {
    const a = { latitude: 31.3, longitude: 121.5 };
    const b = { latitude: 31.1, longitude: 121.2 };
    expect(normalizeOverlayBounds(a, b)).toEqual({
      sw: { latitude: 31.1, longitude: 121.2 },
      ne: { latitude: 31.3, longitude: 121.5 },
    });
    // swapping the inputs yields the same sw/ne
    expect(normalizeOverlayBounds(b, a)).toEqual(normalizeOverlayBounds(a, b));
  });
});

describe('Overlay component (M12)', () => {
  it('retains the __MAP_OVERLAY sentinel after the host-component conversion', () => {
    expect((Overlay as { __MAP_OVERLAY?: boolean }).__MAP_OVERLAY).toBe(true);
  });

  it('exposes the Animated-wrapped variant (Overlay.Animated)', () => {
    expect((Overlay as { Animated?: unknown }).Animated).toBeDefined();
  });

  it('default export is the same component as the named export', () => {
    expect(Overlay).toBe(NamedOverlay);
  });
});
