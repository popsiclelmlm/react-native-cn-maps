import React from 'react';
import type { CoordinateSystem } from './types';

/**
 * Carries the parent `<MapView coordinateSystem>` down to child overlays
 * (`<Marker>` now, `<Polyline>` / `<Polygon>` / `<Circle>` in M5). Children read
 * it to convert WGS-84 / bd09 coordinates into the gcj02 the native layer
 * expects, keeping coordinate conversion in the JS layer (global principle).
 *
 * Defaults to `gcj02` so a marker rendered outside a MapView (or before the
 * provider mounts) passes coordinates through unchanged.
 */
export const MapCoordinateSystemContext =
  React.createContext<CoordinateSystem>('gcj02');
