import { useWarnNotImplemented } from './_warnings';
import type { UrlTileProps } from './types';

export type UrlTileComponent = ((props: UrlTileProps) => null) & {
  __MAP_URL_TILE: true;
};

export const UrlTile: UrlTileComponent = function UrlTile(
  _props: UrlTileProps
) {
  useWarnNotImplemented('UrlTile');
  return null;
} as UrlTileComponent;

UrlTile.__MAP_URL_TILE = true;

export default UrlTile;
export type { UrlTileProps as MapUrlTileProps };
