import React from 'react';
import type { CoordinateSystem, MapProvider } from './types';

/**
 * Carries the parent `<MapView coordinateSystem>` down to child overlays
 * (`<Marker>` / `<Polyline>` / `<Polygon>` / `<Circle>` / ...). Children read it
 * (together with {@link MapProviderContext}) to convert their coordinates into the
 * provider's native system, keeping coordinate conversion in the JS layer.
 *
 * Defaults to `gcj02` so a marker rendered outside a MapView (or before the
 * provider mounts) passes coordinates through unchanged.
 */
export const MapCoordinateSystemContext =
  React.createContext<CoordinateSystem>('gcj02');

/**
 * Carries the parent `<MapView provider>` down to child overlays so they convert
 * coordinates into that provider's native system (gcj02 for amap/tencent, bd09 for
 * baidu). Defaults to `amap`.
 */
export const MapProviderContext = React.createContext<MapProvider>('amap');
