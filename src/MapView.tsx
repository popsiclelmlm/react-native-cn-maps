import React from 'react';
import { Animated, type NativeSyntheticEvent } from 'react-native';
import NativeMapView, { Commands } from './MapViewNativeComponent';
import { MapCoordinateSystemContext } from './MapContext';
import {
  fromProviderCoordinate,
  fromProviderRegion,
  toProviderCamera,
  toProviderRegion,
} from './coordinate';
import type {
  NativeMapPressEvent,
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
  PanDragEvent,
  PoiClickEvent,
  RegionChangeEvent,
  UserLocationChangeEvent,
} from './types';

const SUPPORTED_PROVIDER: MapProvider = 'amap';
const DEFAULT_COORDINATE_SYSTEM: CoordinateSystem = 'gcj02';

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
      >
        {/* Children (<Marker> et al.) mount as native child host components and
            read the coordinate system from context to convert to gcj02. */}
        <MapCoordinateSystemContext.Provider value={coordinateSystem}>
          {children}
        </MapCoordinateSystemContext.Provider>
      </NativeMapView>
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
