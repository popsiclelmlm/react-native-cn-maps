import type { PolygonProps } from './types';

// M7 web stub.
export type PolygonComponentType = ((props: PolygonProps) => null) & {
  __MAP_POLYGON: true;
};

export const Polygon = function Polygon(_props: PolygonProps) {
  return null;
} as PolygonComponentType;

Polygon.__MAP_POLYGON = true;

export default Polygon;
export type { PolygonProps as MapPolygonProps };
