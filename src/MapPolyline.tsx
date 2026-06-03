import { useWarnNotImplemented } from './_warnings';
import type { PolylineProps } from './types';

export type PolylineComponent = ((props: PolylineProps) => null) & {
  __MAP_POLYLINE: true;
};

export const Polyline: PolylineComponent = function Polyline(
  _props: PolylineProps
) {
  useWarnNotImplemented('Polyline');
  return null;
} as PolylineComponent;

Polyline.__MAP_POLYLINE = true;

export default Polyline;
export type { PolylineProps as MapPolylineProps };
