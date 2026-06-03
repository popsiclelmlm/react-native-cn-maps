import { useWarnNotImplemented } from './_warnings';
import type { PolygonProps } from './types';

export type PolygonComponent = ((props: PolygonProps) => null) & {
  __MAP_POLYGON: true;
};

export const Polygon: PolygonComponent = function Polygon(
  _props: PolygonProps
) {
  useWarnNotImplemented('Polygon');
  return null;
} as PolygonComponent;

Polygon.__MAP_POLYGON = true;

export default Polygon;
export type { PolygonProps as MapPolygonProps };
