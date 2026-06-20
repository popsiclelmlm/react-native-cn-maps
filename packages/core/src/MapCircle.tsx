import React from 'react';
import NativeCircle from './CircleNativeComponent';
import { MapCoordinateSystemContext } from './MapContext';
import { toProviderCoordinate } from './coordinate';
import type { CircleProps, MapPressEvent } from './types';

/**
 * `<Circle>` child host component of `<MapView>`. The center is converted to the
 * provider system here; `radius` is in meters.
 */
function CircleComponent(props: CircleProps) {
  const {
    center,
    radius,
    strokeColor,
    strokeWidth,
    fillColor,
    lineDashPattern,
    zIndex,
    tappable,
    onPress,
  } = props;

  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const providerCenter = toProviderCoordinate(center, coordinateSystem);

  return (
    <NativeCircle
      latitude={providerCenter.latitude}
      longitude={providerCenter.longitude}
      radius={radius}
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
                  coordinate: center,
                  position: { x: 0, y: 0 },
                },
              } satisfies MapPressEvent)
          : undefined
      }
    />
  );
}

export type CircleComponentType = ((
  props: CircleProps
) => React.ReactElement) & {
  __MAP_CIRCLE: true;
};

export const Circle = CircleComponent as unknown as CircleComponentType;

Circle.__MAP_CIRCLE = true;

export default Circle;
export type { CircleProps as MapCircleProps };
