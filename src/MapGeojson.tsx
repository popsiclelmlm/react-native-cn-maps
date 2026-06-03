import { useWarnNotImplemented } from './_warnings';
import type { GeojsonProps } from './types';

export type GeojsonComponent = ((props: GeojsonProps) => null) & {
  __MAP_GEOJSON: true;
};

export const Geojson: GeojsonComponent = function Geojson(
  _props: GeojsonProps
) {
  useWarnNotImplemented('Geojson');
  return null;
} as GeojsonComponent;

Geojson.__MAP_GEOJSON = true;

export default Geojson;
export type { GeojsonProps as MapGeojsonProps };
