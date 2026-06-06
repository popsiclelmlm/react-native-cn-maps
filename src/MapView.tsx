import React from 'react';
import { Animated, type NativeSyntheticEvent } from 'react-native';
import NativeMapView, { Commands } from './MapViewNativeComponent';
import { AnimatedRegion } from './AnimatedRegion';
import { MapCoordinateSystemContext } from './MapContext';
import {
  fromProviderCamera,
  fromProviderCoordinate,
  fromProviderRegion,
  toProviderCamera,
  toProviderCoordinate,
  toProviderRegion,
} from './coordinate';
import type {
  NativeCommandResultEvent,
  NativeMapPressEvent,
  NativePoiClickEvent,
  NativeRegionChangeEvent,
  NativeUserLocationChangeEvent,
} from './MapViewNativeComponent';
import type {
  BoundingBox,
  Camera,
  CoordinateSystem,
  LatLng,
  LongPressEvent,
  MapPressEvent,
  MapProvider,
  MapViewHandle,
  MapViewProps,
  PanDragEvent,
  Point,
  PoiClickEvent,
  Region,
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
    // Pending Promise resolvers for query commands, keyed by request id.
    const pendingRequests = React.useRef(
      new Map<number, (data: Record<string, unknown>) => void>()
    );
    const nextRequestId = React.useRef(1);

    // M10: an AnimatedRegion drives the native map imperatively (degraded to
    // animateToRegion on each value change, per RNM's fallback approach).
    React.useEffect(() => {
      if (!(region instanceof AnimatedRegion)) {
        return;
      }
      const drive = (next: Region) => {
        const providerRegion = toProviderRegion(next, coordinateSystem);
        if (providerRegion && nativeRef.current) {
          Commands.animateToRegion(
            nativeRef.current,
            providerRegion.latitude,
            providerRegion.longitude,
            providerRegion.latitudeDelta,
            providerRegion.longitudeDelta,
            0
          );
        }
      };
      drive(region.toJSON());
      const id = region.addListener(drive);
      return () => region.removeListener(id);
    }, [region, coordinateSystem]);

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

    React.useImperativeHandle(ref, () => {
      // Allocate a request id, register the resolver, and fire the query
      // command; onCommandResult resolves it with the parsed JSON payload.
      const query = <T,>(
        parse: (data: Record<string, unknown>) => T,
        send: (requestId: number) => void
      ): Promise<T> =>
        new Promise<T>((resolve) => {
          const id = nextRequestId.current++;
          pendingRequests.current.set(id, (data) => resolve(parse(data)));
          if (nativeRef.current) {
            send(id);
          }
        });

      return {
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

        animateCamera(nextCamera, opts) {
          if (!nativeRef.current) {
            return;
          }
          const center = nextCamera.center
            ? toProviderCoordinate(nextCamera.center, coordinateSystem)
            : { latitude: 0, longitude: 0 };
          Commands.animateCamera(
            nativeRef.current,
            center.latitude,
            center.longitude,
            nextCamera.heading ?? 0,
            nextCamera.pitch ?? 0,
            nextCamera.zoom ?? 0,
            opts?.duration ?? 500
          );
        },

        setCamera(nextCamera) {
          if (!nativeRef.current) {
            return;
          }
          const center = nextCamera.center
            ? toProviderCoordinate(nextCamera.center, coordinateSystem)
            : { latitude: 0, longitude: 0 };
          Commands.setCamera(
            nativeRef.current,
            center.latitude,
            center.longitude,
            nextCamera.heading ?? 0,
            nextCamera.pitch ?? 0,
            nextCamera.zoom ?? 0
          );
        },

        fitToCoordinates(coordinates, options) {
          if (!nativeRef.current) {
            return;
          }
          const providerCoordinates = (coordinates ?? []).map((c) =>
            toProviderCoordinate(c, coordinateSystem)
          );
          Commands.fitToCoordinates(
            nativeRef.current,
            JSON.stringify(providerCoordinates),
            JSON.stringify(options?.edgePadding ?? {}),
            options?.animated ?? true
          );
        },

        fitToElements(options) {
          if (nativeRef.current) {
            Commands.fitToElements(
              nativeRef.current,
              options?.animated ?? true
            );
          }
        },

        fitToSuppliedMarkers(markerIDs, options) {
          if (nativeRef.current) {
            Commands.fitToSuppliedMarkers(
              nativeRef.current,
              JSON.stringify(markerIDs ?? []),
              JSON.stringify(options?.edgePadding ?? {}),
              options?.animated ?? true
            );
          }
        },

        getCamera: () =>
          query<Camera>(
            (data) =>
              fromProviderCamera(
                {
                  latitude: Number(data.latitude) || 0,
                  longitude: Number(data.longitude) || 0,
                  heading: Number(data.heading) || 0,
                  pitch: Number(data.pitch) || 0,
                  zoom: Number(data.zoom) || 0,
                  altitude: Number(data.altitude) || 0,
                },
                coordinateSystem
              ),
            (id) => Commands.getCamera(nativeRef.current!, id)
          ),

        getMapBoundaries: () =>
          query<BoundingBox>(
            (data) => {
              const ne = (data.northEast ?? {}) as LatLng;
              const sw = (data.southWest ?? {}) as LatLng;
              return {
                northEast: fromProviderCoordinate(
                  { latitude: ne.latitude ?? 0, longitude: ne.longitude ?? 0 },
                  coordinateSystem
                ),
                southWest: fromProviderCoordinate(
                  { latitude: sw.latitude ?? 0, longitude: sw.longitude ?? 0 },
                  coordinateSystem
                ),
              };
            },
            (id) => Commands.getMapBoundaries(nativeRef.current!, id)
          ),

        pointForCoordinate(coordinate) {
          const providerCoordinate = toProviderCoordinate(
            coordinate,
            coordinateSystem
          );
          return query<Point>(
            (data) => ({ x: Number(data.x) || 0, y: Number(data.y) || 0 }),
            (id) =>
              Commands.pointForCoordinate(
                nativeRef.current!,
                id,
                providerCoordinate.latitude,
                providerCoordinate.longitude
              )
          );
        },

        coordinateForPoint(point) {
          return query<LatLng>(
            (data) =>
              fromProviderCoordinate(
                {
                  latitude: Number(data.latitude) || 0,
                  longitude: Number(data.longitude) || 0,
                },
                coordinateSystem
              ),
            (id) =>
              Commands.coordinateForPoint(
                nativeRef.current!,
                id,
                point.x,
                point.y
              )
          );
        },

        takeSnapshot(options = {}) {
          // `region` is accepted for RNM parity but ignored (native snapshots the
          // current viewport). Returns a file:// uri, or raw base64 when
          // result: 'base64'.
          return query<string>(
            (data) => String(data.uri ?? ''),
            (id) =>
              Commands.takeSnapshot(
                nativeRef.current!,
                id,
                Math.round(options.width ?? 0),
                Math.round(options.height ?? 0),
                options.format ?? 'png',
                options.quality ?? 1,
                options.result ?? 'file'
              )
          );
        },
      };
    }, [coordinateSystem]);

    const handleCommandResult = React.useCallback(
      (event: NativeSyntheticEvent<NativeCommandResultEvent>) => {
        const { id, data } = event.nativeEvent;
        const resolver = pendingRequests.current.get(id);
        if (resolver) {
          pendingRequests.current.delete(id);
          resolver(data ? JSON.parse(data) : {});
        }
      },
      []
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
        region={
          region instanceof AnimatedRegion
            ? undefined
            : toProviderRegion(region, coordinateSystem)
        }
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
        onCommandResult={handleCommandResult}
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
