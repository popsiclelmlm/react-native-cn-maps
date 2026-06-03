import { useWarnNotImplemented } from './_warnings';
import type { LocalTileProps } from './types';

export type LocalTileComponent = ((props: LocalTileProps) => null) & {
  __MAP_LOCAL_TILE: true;
};

export const LocalTile: LocalTileComponent = function LocalTile(
  _props: LocalTileProps
) {
  useWarnNotImplemented('LocalTile');
  return null;
} as LocalTileComponent;

LocalTile.__MAP_LOCAL_TILE = true;

export default LocalTile;
export type { LocalTileProps as MapLocalTileProps };
