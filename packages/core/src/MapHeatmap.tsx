import React from 'react';
import NativeHeatmap from './HeatmapNativeComponent';
import { MapCoordinateSystemContext, MapProviderContext } from './MapContext';
import { toProviderCoordinate } from './coordinate';
import type { HeatmapProps } from './types';

/**
 * `<Heatmap>` child host component of `<MapView>`. Renders a weighted point
 * set as a tile-overlay heatmap. Points are converted to the provider system
 * here; `points` and `gradient` cross to native as JSON strings.
 */
function HeatmapComponent(props: HeatmapProps) {
  const { points, radius, opacity, gradient } = props;

  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const provider = React.useContext(MapProviderContext);
  const nativePoints = (points ?? []).map((p) => {
    const c = toProviderCoordinate(p, coordinateSystem, provider);
    return {
      latitude: c.latitude,
      longitude: c.longitude,
      weight: p.weight ?? 1,
    };
  });

  return (
    <NativeHeatmap
      points={JSON.stringify(nativePoints)}
      radius={radius}
      opacity={opacity}
      gradient={gradient ? JSON.stringify(gradient) : undefined}
    />
  );
}

export type HeatmapComponentType = ((
  props: HeatmapProps
) => React.ReactElement) & {
  __MAP_HEATMAP: true;
};

export const Heatmap = HeatmapComponent as unknown as HeatmapComponentType;

Heatmap.__MAP_HEATMAP = true;

export default Heatmap;
export type { HeatmapProps as MapHeatmapProps };
