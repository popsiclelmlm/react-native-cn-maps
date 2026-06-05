import { describe, expect, it } from '@jest/globals';
import Marker, { Marker as NamedMarker } from '../MapMarker';
import { markerColorToString } from '../markerUtils';

describe('markerColorToString', () => {
  it('passes string colors through unchanged', () => {
    expect(markerColorToString('red')).toBe('red');
    expect(markerColorToString('#00ff00')).toBe('#00ff00');
  });

  it('drops non-string colors (processed colors arrive as numbers)', () => {
    expect(markerColorToString(undefined)).toBeUndefined();
    expect(markerColorToString(42 as unknown as string)).toBeUndefined();
  });
});

describe('Marker component', () => {
  it('retains the __MAP_MARKER sentinel after the host-component conversion', () => {
    expect((Marker as { __MAP_MARKER?: boolean }).__MAP_MARKER).toBe(true);
  });

  it('exposes the Animated-wrapped variant (Marker.Animated)', () => {
    expect((Marker as { Animated?: unknown }).Animated).toBeDefined();
  });

  it('default export is the same component as the named export', () => {
    expect(Marker).toBe(NamedMarker);
  });
});
