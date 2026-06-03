import { useWarnNotImplemented } from './_warnings';
import type { WMSTileProps } from './types';

export type WMSTileComponent = ((props: WMSTileProps) => null) & {
  __MAP_WMS_TILE: true;
};

export const WMSTile: WMSTileComponent = function WMSTile(
  _props: WMSTileProps
) {
  useWarnNotImplemented('WMSTile');
  return null;
} as WMSTileComponent;

WMSTile.__MAP_WMS_TILE = true;

export default WMSTile;
export type { WMSTileProps as MapWMSTileProps };
