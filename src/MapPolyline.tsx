import React from 'react';
import NativePolyline from './PolylineNativeComponent';
import { MapCoordinateSystemContext } from './MapContext';
import { toProviderCoordinate } from './coordinate';
import type { MapPressEvent, PolylineProps } from './types';

/**
 * `<Polyline>` child host component of `<MapView>`. Coordinates are converted to
 * the provider system here (global "convert in JS" principle). M16 adds gradient
 * `strokeColors` (serialized as JSON, parsed natively) plus `lineCap`/`lineJoin`/
 * `miterLimit` (best-effort on Android, full on iOS renderer).
 */
function PolylineComponent(props: PolylineProps) {
  const {
    coordinates,
    strokeColor,
    strokeColors,
    strokeWidth,
    lineDashPattern,
    lineCap,
    lineJoin,
    miterLimit,
    geodesic,
    zIndex,
    tappable,
    onPress,
  } = props;

  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const nativeCoordinates = (coordinates ?? []).map((c) =>
    toProviderCoordinate(c, coordinateSystem)
  );

  return (
    <NativePolyline
      coordinates={nativeCoordinates}
      strokeColor={strokeColor}
      strokeColors={
        strokeColors && strokeColors.length > 0
          ? JSON.stringify(strokeColors)
          : undefined
      }
      strokeWidth={strokeWidth}
      lineDashPattern={
        lineDashPattern ? JSON.stringify(lineDashPattern) : undefined
      }
      lineCap={lineCap}
      lineJoin={lineJoin}
      miterLimit={miterLimit}
      geodesic={geodesic}
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

export type PolylineComponentType = ((
  props: PolylineProps
) => React.ReactElement) & {
  __MAP_POLYLINE: true;
};

export const Polyline = PolylineComponent as unknown as PolylineComponentType;

Polyline.__MAP_POLYLINE = true;

export default Polyline;
export type { PolylineProps as MapPolylineProps };
