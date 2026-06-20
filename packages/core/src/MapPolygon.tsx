import React from 'react';
import NativePolygon from './PolygonNativeComponent';
import { MapCoordinateSystemContext, MapProviderContext } from './MapContext';
import { toProviderCoordinate } from './coordinate';
import type { MapPressEvent, PolygonProps } from './types';

/**
 * `<Polygon>` child host component of `<MapView>`. Outline + holes are converted
 * to the provider system here; holes cross the boundary as a JSON string.
 */
function PolygonComponent(props: PolygonProps) {
  const {
    coordinates,
    holes,
    strokeColor,
    strokeWidth,
    fillColor,
    lineDashPattern,
    zIndex,
    tappable,
    onPress,
  } = props;

  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const provider = React.useContext(MapProviderContext);
  const nativeCoordinates = (coordinates ?? []).map((c) =>
    toProviderCoordinate(c, coordinateSystem, provider)
  );
  const nativeHoles = holes?.map((ring) =>
    ring.map((c) => toProviderCoordinate(c, coordinateSystem, provider))
  );

  return (
    <NativePolygon
      coordinates={nativeCoordinates}
      holes={nativeHoles ? JSON.stringify(nativeHoles) : undefined}
      strokeColor={strokeColor}
      strokeWidth={strokeWidth}
      fillColor={fillColor}
      lineDashPattern={
        lineDashPattern ? JSON.stringify(lineDashPattern) : undefined
      }
      overlayZIndex={zIndex}
      tappable={tappable}
      onPress={
        onPress
          ? () =>
              onPress({
                nativeEvent: {
                  coordinate: coordinates?.[0] ?? { latitude: 0, longitude: 0 },
                  position: { x: 0, y: 0 },
                },
              } satisfies MapPressEvent)
          : undefined
      }
    />
  );
}

export type PolygonComponentType = ((
  props: PolygonProps
) => React.ReactElement) & {
  __MAP_POLYGON: true;
};

export const Polygon = PolygonComponent as unknown as PolygonComponentType;

Polygon.__MAP_POLYGON = true;

export default Polygon;
export type { PolygonProps as MapPolygonProps };
