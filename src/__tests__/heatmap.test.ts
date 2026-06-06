import { describe, expect, it } from '@jest/globals';
import Heatmap, { Heatmap as NamedHeatmap } from '../MapHeatmap';

describe('Heatmap component (M17)', () => {
  it('retains the __MAP_HEATMAP sentinel after the host-component conversion', () => {
    expect((Heatmap as { __MAP_HEATMAP?: boolean }).__MAP_HEATMAP).toBe(true);
  });

  it('default export is the same component as the named export', () => {
    expect(Heatmap).toBe(NamedHeatmap);
  });
});
