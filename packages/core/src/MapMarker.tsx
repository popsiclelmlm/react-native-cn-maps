import React from 'react';
import {
  Animated,
  Image,
  StyleSheet,
  type NativeSyntheticEvent,
} from 'react-native';
import NativeMarker, { Commands } from './MarkerNativeComponent';
import type { NativeMarkerPressEvent } from './MarkerNativeComponent';
import { MapCoordinateSystemContext, MapProviderContext } from './MapContext';
import { fromProviderCoordinate, toProviderCoordinate } from './coordinate';
import { markerColorToString } from './markerUtils';
import type {
  CalloutPressEvent,
  MapMarkerHandle,
  MarkerImageSource,
  MarkerProps,
} from './types';

// RNM default marker anchor: bottom-center. Native applies it as-is, so we send
// the explicit default whenever the user did not supply one.
const DEFAULT_ANCHOR = { x: 0.5, y: 1 } as const;

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
 * intercepts its mount/unmount and registers it as an annotation.
 *
 * The public API is `<Marker coordinate=… />` — react-native-maps compatible.
 */
function MarkerComponent(
  props: MarkerProps,
  ref: React.ForwardedRef<MapMarkerHandle>
) {
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
    tracksViewChanges,
    tracksInfoWindowChanges,
    children,
    style,
    onPress,
    onSelect,
    onDeselect,
    onCalloutPress,
    onDragStart,
    onDrag,
    onDragEnd,
  } = props;

  const nativeRef = React.useRef<React.ElementRef<typeof NativeMarker>>(null);
  const coordinateSystem = React.useContext(MapCoordinateSystemContext);
  const provider = React.useContext(MapProviderContext);
  const providerCoordinate = toProviderCoordinate(
    coordinate,
    coordinateSystem,
    provider
  );
  // RNM keeps `image` and `icon` as aliases for the same custom marker bitmap.
  // Custom React children, when present, take precedence over `image` natively.
  const imageUri = resolveImageUri(image ?? icon);

  React.useImperativeHandle(
    ref,
    () => ({
      showCallout() {
        if (nativeRef.current) {
          Commands.showCallout(nativeRef.current);
        }
      },
      hideCallout() {
        if (nativeRef.current) {
          Commands.hideCallout(nativeRef.current);
        }
      },
      redrawCallout() {
        if (nativeRef.current) {
          Commands.redrawCallout(nativeRef.current);
        }
      },
      redraw() {
        if (nativeRef.current) {
          Commands.redraw(nativeRef.current);
        }
      },
      animateMarkerToCoordinate(target, duration = 500) {
        if (nativeRef.current) {
          const providerTarget = toProviderCoordinate(
            target,
            coordinateSystem,
            provider
          );
          Commands.animateMarkerToCoordinate(
            nativeRef.current,
            providerTarget.latitude,
            providerTarget.longitude,
            duration
          );
        }
      },
    }),
    [coordinateSystem, provider]
  );

  // onPress / onSelect / onDeselect / onDragStart / onDrag / onDragEnd all carry
  // the marker's `{ coordinate }`; rebuild the RNM `{ coordinate, identifier }`
  // shape, converting the coordinate back out of the provider system.
  const buildCoordEvent = React.useCallback(
    (event: NativeSyntheticEvent<NativeMarkerPressEvent>) => ({
      nativeEvent: {
        identifier: identifier ?? '',
        coordinate: fromProviderCoordinate(
          event.nativeEvent.coordinate,
          coordinateSystem,
          provider
        ),
      },
    }),
    [coordinateSystem, identifier, provider]
  );

  return (
    <NativeMarker
      ref={nativeRef}
      // Custom marker content is rasterized into the icon offscreen; without
      // this the marker view stretches to the map's full width (default flex
      // align-stretch) and the bitmap becomes a full-width bar. flex-start sizes
      // it to its content.
      style={[markerStyles.container, style]}
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
      overlayZIndex={zIndex}
      tracksViewChanges={tracksViewChanges}
      tracksInfoWindowChanges={tracksInfoWindowChanges}
      onPress={onPress ? (event) => onPress(buildCoordEvent(event)) : undefined}
      onSelect={
        onSelect ? (event) => onSelect(buildCoordEvent(event)) : undefined
      }
      onDeselect={
        onDeselect ? (event) => onDeselect(buildCoordEvent(event)) : undefined
      }
      onDragStart={
        onDragStart ? (event) => onDragStart(buildCoordEvent(event)) : undefined
      }
      onDrag={onDrag ? (event) => onDrag(buildCoordEvent(event)) : undefined}
      onDragEnd={
        onDragEnd ? (event) => onDragEnd(buildCoordEvent(event)) : undefined
      }
      onCalloutPress={
        onCalloutPress
          ? () =>
              onCalloutPress({
                nativeEvent: {
                  identifier: identifier ?? '',
                  action: 'callout-press',
                },
              } satisfies CalloutPressEvent)
          : undefined
      }
    >
      {children}
    </NativeMarker>
  );
}

const markerStyles = StyleSheet.create({
  container: { alignSelf: 'flex-start' },
});

export type MarkerComponentType = React.ForwardRefExoticComponent<
  MarkerProps & React.RefAttributes<MapMarkerHandle>
> & {
  __MAP_MARKER: true;
  Animated: ReturnType<typeof Animated.createAnimatedComponent>;
};

export const Marker = React.forwardRef(
  MarkerComponent
) as unknown as MarkerComponentType;

// Sentinel kept so any `__MAP_MARKER` checks (and future tooling) still
// recognize the component.
Marker.__MAP_MARKER = true;

// RNM parity: `Marker.Animated`, also re-exported as `MarkerAnimated`.
Marker.Animated = Animated.createAnimatedComponent(
  Marker
) as MarkerComponentType['Animated'];

export default Marker;
export type { MarkerProps as MapMarkerProps };
