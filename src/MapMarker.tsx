import React from 'react';
import { Animated, Image, type NativeSyntheticEvent } from 'react-native';
import NativeMarker from './MarkerNativeComponent';
import type { NativeMarkerPressEvent } from './MarkerNativeComponent';
import { MapCoordinateSystemContext } from './MapContext';
import { fromProviderCoordinate, toProviderCoordinate } from './coordinate';
import type { MarkerImageSource, MarkerPressEvent, MarkerProps } from './types';

// RNM default marker anchor: bottom-center. Native applies it as-is, so we send
// the explicit default whenever the user did not supply one.
const DEFAULT_ANCHOR = { x: 0.5, y: 1 } as const;

function markerColorToString(color: MarkerProps['pinColor']) {
  return typeof color === 'string' ? color : undefined;
}

// Resolve an RNM image source (require()'d asset, { uri }, or an array of
// resolutions) into the plain uri string the native layer loads.
function resolveImageUri(source: MarkerImageSource | undefined) {
  if (source == null) {
    return undefined;
  }

  const candidate = Array.isArray(source) ? source[0] : source;
  return Image.resolveAssetSource(candidate)?.uri;
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
  // PR-1 + PR-2 surface. Custom React content (children), drag/select events and
  // ref commands arrive in later M3 PRs; props not listed here are still ignored.
  const {
    coordinate,
    identifier,
    title,
    description,
    pinColor,
    draggable,
    image,
    icon,
    anchor,
    centerOffset,
    calloutAnchor,
    opacity,
    rotation,
    flat,
    zIndex,
    onPress,
  } = props;

  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const providerCoordinate = toProviderCoordinate(coordinate, coordinateSystem);
  // RNM keeps `image` and `icon` as aliases for the same custom marker bitmap.
  const imageUri = resolveImageUri(image ?? icon);

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
      image={imageUri}
      anchor={anchor ?? DEFAULT_ANCHOR}
      centerOffset={centerOffset}
      calloutAnchor={calloutAnchor}
      opacity={opacity}
      rotation={rotation}
      flat={flat}
      zIndex={zIndex}
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
