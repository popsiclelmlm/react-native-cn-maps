import { describe, expect, it } from '@jest/globals';
import WMSTile, { WMSTile as NamedWMSTile } from '../MapWMSTile';

describe('WMSTile component (M18)', () => {
  it('retains the __MAP_WMS_TILE sentinel after the host-component conversion', () => {
    expect((WMSTile as { __MAP_WMS_TILE?: boolean }).__MAP_WMS_TILE).toBe(true);
  });

  it('default export is the same component as the named export', () => {
    expect(WMSTile).toBe(NamedWMSTile);
  });
});
