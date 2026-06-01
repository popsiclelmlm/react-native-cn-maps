import React from 'react';
import type { NativeSyntheticEvent } from 'react-native';
import NativeMapView, { Commands } from './MapViewNativeComponent';
import {
  fromProviderCoordinate,
  fromProviderRegion,
  toProviderCoordinate,
  toProviderRegion,
} from './coordinate';
import type {
  NativeMarker,
  NativeMarkerPressEvent,
  NativeRegionChangeEvent,
} from './MapViewNativeComponent';
import type {
  CoordinateSystem,
  MapProvider,
  MapViewHandle,
  MapViewProps,
  MarkerPressEvent,
  MarkerProps,
  RegionChangeEvent,
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
      children,
      onRegionChange,
      onRegionChangeComplete,
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
        markers={markers}
        onRegionChange={onRegionChange ? handleRegionChange : undefined}
        onRegionChangeComplete={
          onRegionChangeComplete ? handleRegionChangeComplete : undefined
        }
        onMarkerPress={handleMarkerPress}
      />
    );
  }
);
