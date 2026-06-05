import { describe, expect, it } from '@jest/globals';
import UrlTile, { UrlTile as NamedUrlTile } from '../MapUrlTile';
import LocalTile, { LocalTile as NamedLocalTile } from '../MapLocalTile';

describe('UrlTile component (M11)', () => {
  it('retains the __MAP_URL_TILE sentinel after the host-component conversion', () => {
    expect((UrlTile as { __MAP_URL_TILE?: boolean }).__MAP_URL_TILE).toBe(true);
  });

  it('default export is the same component as the named export', () => {
    expect(UrlTile).toBe(NamedUrlTile);
  });
});

describe('LocalTile component (M11)', () => {
  it('retains the __MAP_LOCAL_TILE sentinel after the host-component conversion', () => {
    expect((LocalTile as { __MAP_LOCAL_TILE?: boolean }).__MAP_LOCAL_TILE).toBe(
      true
    );
  });

  it('default export is the same component as the named export', () => {
    expect(LocalTile).toBe(NamedLocalTile);
  });
});
