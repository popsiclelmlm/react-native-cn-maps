import React from 'react';
import { Animated, type NativeSyntheticEvent } from 'react-native';
import NativeMapView, { Commands } from './MapViewNativeComponent';
import {
  fromProviderCoordinate,
  fromProviderRegion,
  toProviderCamera,
  toProviderCoordinate,
  toProviderRegion,
} from './coordinate';
import type {
  NativeMapPressEvent,
  NativeMarker,
  NativeMarkerPressEvent,
  NativePoiClickEvent,
  NativeRegionChangeEvent,
  NativeUserLocationChangeEvent,
} from './MapViewNativeComponent';
import type {
  CoordinateSystem,
  LongPressEvent,
  MapPressEvent,
  MapProvider,
  MapViewHandle,
  MapViewProps,
  MarkerPressEvent,
  MarkerProps,
  PanDragEvent,
  PoiClickEvent,
  RegionChangeEvent,
  UserLocationChangeEvent,
} from './types';

const SUPPORTED_PROVIDER: MapProvider = 'amap';
const DEFAULT_COORDINATE_SYSTEM: CoordinateSystem = 'gcj02';

function isMarkerElement(
  child: React.ReactNode
): child is React.ReactElement<MarkerProps> {
  return (
    React.isValidElement(child) &&
    Boolean((child.type as { __MAP_MARKER?: boolean }).__MAP_MARKER)
  );
}

function markerColorToString(color: MarkerProps['pinColor']) {
  if (typeof color === 'string') {
    return color;
  }

  return undefined;
}

export const MapView = React.forwardRef<MapViewHandle, MapViewProps>(
  function MapView(
    {
      provider = SUPPORTED_PROVIDER,
      coordinateSystem = DEFAULT_COORDINATE_SYSTEM,
      initialRegion,
      region,
      initialCamera,
      camera,
      customMapStyle,
      children,
      onRegionChange,
      onRegionChangeComplete,
      onPress,
      onLongPress,
      onDoublePress,
      onPanDrag,
      onPoiClick,
      onUserLocationChange,
      ...rest
    },
    ref
  ) {
    const nativeRef =
      React.useRef<React.ElementRef<typeof NativeMapView>>(null);
    const markerHandlers = React.useRef<Record<string, MarkerProps['onPress']>>(
      {}
    );

    if (__DEV__ && provider !== SUPPORTED_PROVIDER) {
      console.warn(
        `[react-native-cn-maps] provider="${provider}" is reserved but not implemented yet. Falling back to "amap".`
      );
    }

    if (__DEV__ && region && camera) {
      console.warn(
        '[react-native-cn-maps] Both `region` and `camera` were provided. ' +
          'Following react-native-maps, `camera` takes precedence.'
      );
    }

    const markers = React.useMemo(() => {
      const nextHandlers: Record<string, MarkerProps['onPress']> = {};
      const nativeMarkers: NativeMarker[] = [];

      React.Children.forEach(children, (child, index) => {
        if (!isMarkerElement(child)) {
          if (__DEV__ && child != null) {
            console.warn(
              '[react-native-cn-maps] Only <Marker /> children are rendered in the current MapView milestone.'
            );
          }
          return;
        }

        const identifier = child.props.identifier ?? String(index);
        const coordinate = toProviderCoordinate(
          child.props.coordinate,
          coordinateSystem
        );

        if (child.props.onPress) {
          nextHandlers[identifier] = child.props.onPress;
        }

        nativeMarkers.push({
          identifier,
          latitude: coordinate.latitude,
          longitude: coordinate.longitude,
          title: child.props.title,
          description: child.props.description,
          pinColor: markerColorToString(child.props.pinColor),
          draggable: child.props.draggable,
        });
      });

      markerHandlers.current = nextHandlers;
      return nativeMarkers;
    }, [children, coordinateSystem]);

    React.useImperativeHandle(
      ref,
      () => ({
        animateToRegion(nextRegion, duration = 500) {
          const providerRegion = toProviderRegion(nextRegion, coordinateSystem);

          if (providerRegion && nativeRef.current) {
            Commands.animateToRegion(
              nativeRef.current,
              providerRegion.latitude,
              providerRegion.longitude,
              providerRegion.latitudeDelta,
              providerRegion.longitudeDelta,
              duration
            );
          }
        },
      }),
      [coordinateSystem]
    );

    const handleRegionChange = React.useCallback(
      (event: NativeSyntheticEvent<NativeRegionChangeEvent>) => {
        onRegionChange?.({
          nativeEvent: {
            ...event.nativeEvent,
            region: fromProviderRegion(
              event.nativeEvent.region,
              coordinateSystem
            ),
          },
        } satisfies RegionChangeEvent);
      },
      [coordinateSystem, onRegionChange]
    );

    const handleRegionChangeComplete = React.useCallback(
      (event: NativeSyntheticEvent<NativeRegionChangeEvent>) => {
        onRegionChangeComplete?.({
          nativeEvent: {
            ...event.nativeEvent,
            region: fromProviderRegion(
              event.nativeEvent.region,
              coordinateSystem
            ),
          },
        } satisfies RegionChangeEvent);
      },
      [coordinateSystem, onRegionChangeComplete]
    );

    // onPress / onLongPress / onDoublePress / onPanDrag all carry the same
    // { coordinate, position } payload; convert the coordinate back out of the
    // provider (gcj02) system before handing it to the user's handler.
    const makePressHandler = React.useCallback(
      (
        handler:
          | ((event: MapPressEvent) => void)
          | ((event: LongPressEvent) => void)
          | ((event: PanDragEvent) => void)
          | undefined
      ) =>
        handler
          ? (event: NativeSyntheticEvent<NativeMapPressEvent>) => {
              handler({
                nativeEvent: {
                  coordinate: fromProviderCoordinate(
                    event.nativeEvent.coordinate,
                    coordinateSystem
                  ),
                  position: event.nativeEvent.position,
                },
              });
            }
          : undefined,
      [coordinateSystem]
    );

    const handlePress = React.useMemo(
      () => makePressHandler(onPress),
      [makePressHandler, onPress]
    );
    const handleLongPress = React.useMemo(
      () => makePressHandler(onLongPress),
      [makePressHandler, onLongPress]
    );
    const handleDoublePress = React.useMemo(
      () => makePressHandler(onDoublePress),
      [makePressHandler, onDoublePress]
    );
    const handlePanDrag = React.useMemo(
      () => makePressHandler(onPanDrag),
      [makePressHandler, onPanDrag]
    );

    const handlePoiClick = React.useCallback(
      (event: NativeSyntheticEvent<NativePoiClickEvent>) => {
        onPoiClick?.({
          nativeEvent: {
            coordinate: fromProviderCoordinate(
              event.nativeEvent.coordinate,
              coordinateSystem
            ),
            placeId: event.nativeEvent.placeId,
            name: event.nativeEvent.name,
          },
        } satisfies PoiClickEvent);
      },
      [coordinateSystem, onPoiClick]
    );

    const handleUserLocationChange = React.useCallback(
      (event: NativeSyntheticEvent<NativeUserLocationChangeEvent>) => {
        const native = event.nativeEvent.coordinate;
        onUserLocationChange?.({
          nativeEvent: {
            coordinate: native
              ? {
                  ...fromProviderCoordinate(native, coordinateSystem),
                  altitude: native.altitude,
                  accuracy: native.accuracy,
                  speed: native.speed,
                  heading: native.heading,
                  isFromMockProvider: native.isFromMockProvider,
                }
              : undefined,
          },
        } satisfies UserLocationChangeEvent);
      },
      [coordinateSystem, onUserLocationChange]
    );

    const handleMarkerPress = React.useCallback(
      (event: NativeSyntheticEvent<NativeMarkerPressEvent>) => {
        const handler = markerHandlers.current[event.nativeEvent.identifier];

        if (!handler) {
          return;
        }

        const coordinate = fromProviderCoordinate(
          event.nativeEvent.coordinate,
          coordinateSystem
        );

        handler({
          nativeEvent: {
            identifier: event.nativeEvent.identifier,
            coordinate,
          },
        } satisfies MarkerPressEvent);
      },
      [coordinateSystem]
    );

    return (
      <NativeMapView
        {...rest}
        ref={nativeRef}
        provider={SUPPORTED_PROVIDER}
        coordinateSystem={coordinateSystem}
        initialRegion={toProviderRegion(initialRegion, coordinateSystem)}
        region={toProviderRegion(region, coordinateSystem)}
        initialCamera={toProviderCamera(initialCamera, coordinateSystem)}
        camera={toProviderCamera(camera, coordinateSystem)}
        customMapStyle={
          customMapStyle ? JSON.stringify(customMapStyle) : undefined
        }
        markers={markers}
        onRegionChange={onRegionChange ? handleRegionChange : undefined}
        onRegionChangeComplete={
          onRegionChangeComplete ? handleRegionChangeComplete : undefined
        }
        onPress={handlePress}
        onLongPress={handleLongPress}
        onDoublePress={handleDoublePress}
        onPanDrag={handlePanDrag}
        onPoiClick={onPoiClick ? handlePoiClick : undefined}
        onUserLocationChange={
          onUserLocationChange ? handleUserLocationChange : undefined
        }
        onMarkerPress={handleMarkerPress}
      />
    );
  }
);

/**
 * `Animated`-wrapped MapView. react-native-maps exposes the same value as both
 * the package-level `Animated` export and the `MapView.Animated` static, so we
 * mirror both for drop-in import parity.
 */
export const AnimatedMapView = Animated.createAnimatedComponent(MapView);

(MapView as typeof MapView & { Animated: typeof AnimatedMapView }).Animated =
  AnimatedMapView;
