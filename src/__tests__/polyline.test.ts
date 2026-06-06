import { describe, expect, it } from '@jest/globals';
import Polyline, { Polyline as NamedPolyline } from '../MapPolyline';

describe('Polyline component (M16)', () => {
  it('retains the __MAP_POLYLINE sentinel', () => {
    expect((Polyline as { __MAP_POLYLINE?: boolean }).__MAP_POLYLINE).toBe(
      true
    );
  });

  it('default export is the same component as the named export', () => {
    expect(Polyline).toBe(NamedPolyline);
  });
});
