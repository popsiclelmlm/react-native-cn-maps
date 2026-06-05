import type { PolylineProps } from './types';

// M7 web stub.
export type PolylineComponentType = ((props: PolylineProps) => null) & {
  __MAP_POLYLINE: true;
};

export const Polyline = function Polyline(_props: PolylineProps) {
  return null;
} as PolylineComponentType;

Polyline.__MAP_POLYLINE = true;

export default Polyline;
export type { PolylineProps as MapPolylineProps };
