import type { MarkerProps } from './types';

export type MarkerComponent = ((props: MarkerProps) => null) & {
  __MAP_MARKER: true;
};

export const Marker: MarkerComponent = function Marker(_props: MarkerProps) {
  return null;
} as MarkerComponent;

Marker.__MAP_MARKER = true;

export default Marker;
export type { MarkerProps as MapMarkerProps };
