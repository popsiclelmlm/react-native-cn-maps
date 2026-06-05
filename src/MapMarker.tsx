import React from 'react';
import { Animated, type NativeSyntheticEvent } from 'react-native';
import NativeMarker from './MarkerNativeComponent';
import type { NativeMarkerPressEvent } from './MarkerNativeComponent';
import { MapCoordinateSystemContext } from './MapContext';
import { fromProviderCoordinate, toProviderCoordinate } from './coordinate';
import type { MarkerPressEvent, MarkerProps } from './types';

function markerColorToString(color: MarkerProps['pinColor']) {
  return typeof color === 'string' ? color : undefined;
}

/**
 * Real Fabric child host component (`RNMapsMarker`) mounted under `<MapView>`.
 * The native marker view never enters the regular RN view tree — the parent map
 * intercepts its mount/unmount and registers it as an annotation (see M3 design).
 *
 * The public API is unchanged from the M2 stub (`<Marker coordinate=… />`); only
 * the internal transport switched from a serialized `markers` array prop on the
 * MapView to this per-marker child.
 */
function MarkerComponent(props: MarkerProps) {
  // M3 PR-1 ships the minimal prop set proven against M2 behavior. The richer
  // appearance / drag / command / custom-content surface (image, anchor, zIndex,
  // drag events, children…) lands in later M3 PRs; props not listed here are
  // intentionally ignored for now.
  const {
    coordinate,
    identifier,
    title,
    description,
    pinColor,
    draggable,
    onPress,
  } = props;

  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const providerCoordinate = toProviderCoordinate(coordinate, coordinateSystem);

  const handlePress = React.useCallback(
    (event: NativeSyntheticEvent<NativeMarkerPressEvent>) => {
      onPress?.({
        nativeEvent: {
          identifier: identifier ?? '',
          coordinate: fromProviderCoordinate(
            event.nativeEvent.coordinate,
            coordinateSystem
          ),
        },
      } satisfies MarkerPressEvent);
    },
    [coordinateSystem, identifier, onPress]
  );

  return (
    <NativeMarker
      identifier={identifier}
      latitude={providerCoordinate.latitude}
      longitude={providerCoordinate.longitude}
      title={title}
      description={description}
      pinColor={markerColorToString(pinColor)}
      draggable={draggable}
      onPress={onPress ? handlePress : undefined}
    />
  );
}

export type MarkerComponentType = ((
  props: MarkerProps
) => React.ReactElement) & {
  __MAP_MARKER: true;
  Animated: ReturnType<typeof Animated.createAnimatedComponent>;
};

export const Marker = MarkerComponent as unknown as MarkerComponentType;

// Sentinel kept for parity with the M2 stub so any remaining `__MAP_MARKER`
// checks (and future tooling) still recognize the component.
Marker.__MAP_MARKER = true;

// RNM parity: `Marker.Animated`, also re-exported as `MarkerAnimated`.
Marker.Animated = Animated.createAnimatedComponent(
  Marker
) as MarkerComponentType['Animated'];

export default Marker;
export type { MarkerProps as MapMarkerProps };
