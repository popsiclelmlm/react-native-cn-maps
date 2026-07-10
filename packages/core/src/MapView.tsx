import React from 'react';
import { Animated, type NativeSyntheticEvent } from 'react-native';
import NativeMapView, { Commands } from './MapViewNativeComponent';
import { AnimatedRegion } from './AnimatedRegion';
import MapGeojson from './MapGeojson';
import { parseKml, type KmlFeatureCollection } from './kml';
import { MapCoordinateSystemContext, MapProviderContext } from './MapContext';
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
  Address,
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

const DEFAULT_PROVIDER: MapProvider = 'amap';
const DEFAULT_COORDINATE_SYSTEM: CoordinateSystem = 'gcj02';
// Query commands reject if the native side hasn't replied within this window,
// so callers never await a Promise that hangs forever.
const QUERY_TIMEOUT_MS = 10000;

export const MapView = React.forwardRef<MapViewHandle, MapViewProps>(
  function MapView(
    {
      provider = DEFAULT_PROVIDER,
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
      kmlSrc,
      onKmlReady,
      ...rest
    },
    ref
  ) {
    const nativeRef =
      React.useRef<React.ElementRef<typeof NativeMapView>>(null);
    // Pending Promise settlers for query commands, keyed by request id. Tracking
    // reject + a timeout lets us fail (instead of hang) when the native side
    // never replies, and clean up on unmount.
    const pendingRequests = React.useRef(
      new Map<
        number,
        {
          resolve: (data: Record<string, unknown>) => void;
          reject: (error: Error) => void;
          timer: ReturnType<typeof setTimeout>;
        }
      >()
    );
    const nextRequestId = React.useRef(1);

    // Reject any still-pending query commands when the view unmounts, so callers
    // awaiting a result get a rejection instead of a Promise that never settles.
    React.useEffect(() => {
      const pending = pendingRequests.current;
      return () => {
        pending.forEach(({ reject, timer }) => {
          clearTimeout(timer);
          reject(
            new Error(
              '[react-native-cn-maps] MapView unmounted before the command resolved'
            )
          );
        });
        pending.clear();
      };
    }, []);

    // An AnimatedRegion drives the native map imperatively (degraded to
    // animateToRegion on each value change, per RNM's fallback approach).
    React.useEffect(() => {
      if (!(region instanceof AnimatedRegion)) {
        return;
      }
      // AnimatedRegion wraps four Animated.Values, so one animation frame fires
      // the listener up to 4×. Coalesce them into a single animateToRegion per
      // frame via rAF instead of spamming the bridge with 4× redundant commands.
      let frame: ReturnType<typeof requestAnimationFrame> | null = null;
      let latest: Region | null = null;
      const flush = () => {
        frame = null;
        const next = latest;
        latest = null;
        if (!next) {
          return;
        }
        const providerRegion = toProviderRegion(
          next,
          coordinateSystem,
          provider
        );
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
      const drive = (next: Region) => {
        latest = next;
        if (frame == null) {
          frame = requestAnimationFrame(flush);
        }
      };
      // Drive the initial value immediately so the first frame isn't delayed.
      latest = region.toJSON();
      flush();
      const id = region.addListener(drive);
      return () => {
        region.removeListener(id);
        if (frame != null) {
          cancelAnimationFrame(frame);
        }
      };
    }, [region, coordinateSystem, provider]);

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
        new Promise<T>((resolve, reject) => {
          if (!nativeRef.current) {
            reject(new Error('[react-native-cn-maps] MapView is not mounted'));
            return;
          }
          const id = nextRequestId.current++;
          const timer = setTimeout(() => {
            pendingRequests.current.delete(id);
            reject(new Error('[react-native-cn-maps] map command timed out'));
          }, QUERY_TIMEOUT_MS);
          pendingRequests.current.set(id, {
            resolve: (data) => resolve(parse(data)),
            reject,
            timer,
          });
          send(id);
        });

      return {
        animateToRegion(nextRegion, duration = 500) {
          const providerRegion = toProviderRegion(
            nextRegion,
            coordinateSystem,
            provider
          );
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
            ? toProviderCoordinate(
                nextCamera.center,
                coordinateSystem,
                provider
              )
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
            ? toProviderCoordinate(
                nextCamera.center,
                coordinateSystem,
                provider
              )
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
            toProviderCoordinate(c, coordinateSystem, provider)
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
                coordinateSystem,
                provider
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
                  coordinateSystem,
                  provider
                ),
                southWest: fromProviderCoordinate(
                  { latitude: sw.latitude ?? 0, longitude: sw.longitude ?? 0 },
                  coordinateSystem,
                  provider
                ),
              };
            },
            (id) => Commands.getMapBoundaries(nativeRef.current!, id)
          ),

        pointForCoordinate(coordinate) {
          const providerCoordinate = toProviderCoordinate(
            coordinate,
            coordinateSystem,
            provider
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
                coordinateSystem,
                provider
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

        addressForCoordinate(coordinate) {
          const providerCoordinate = toProviderCoordinate(
            coordinate,
            coordinateSystem,
            provider
          );
          const str = (v: unknown) => (v == null ? '' : String(v));
          return query<Address>(
            (data) => ({
              name: str(data.name),
              thoroughfare: str(data.thoroughfare),
              subThoroughfare: str(data.subThoroughfare),
              locality: str(data.locality),
              subLocality: str(data.subLocality),
              administrativeArea: str(data.administrativeArea),
              subAdministrativeArea: str(data.subAdministrativeArea),
              postalCode: str(data.postalCode),
              countryCode: str(data.countryCode),
              country: str(data.country),
            }),
            (id) =>
              Commands.addressForCoordinate(
                nativeRef.current!,
                id,
                providerCoordinate.latitude,
                providerCoordinate.longitude
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

        setMapBoundaries(northEast, southWest) {
          const ne = toProviderCoordinate(
            northEast,
            coordinateSystem,
            provider
          );
          const sw = toProviderCoordinate(
            southWest,
            coordinateSystem,
            provider
          );
          if (nativeRef.current) {
            Commands.setMapBoundaries(
              nativeRef.current,
              ne.latitude,
              ne.longitude,
              sw.latitude,
              sw.longitude
            );
          }
        },

        getMarkersFrames(onlyVisible = false) {
          // The whole result object is the id→{point, frame} map; screen
          // coordinates need no coordinate-system conversion.
          return query(
            (data) =>
              data as Record<
                string,
                {
                  point: Point;
                  frame: {
                    x: number;
                    y: number;
                    width: number;
                    height: number;
                  };
                }
              >,
            (id) =>
              Commands.getMarkersFrames(nativeRef.current!, id, onlyVisible)
          );
        },
      };
    }, [coordinateSystem, provider]);

    const handleCommandResult = React.useCallback(
      (event: NativeSyntheticEvent<NativeCommandResultEvent>) => {
        const { id, data } = event.nativeEvent;
        const pending = pendingRequests.current.get(id);
        if (!pending) {
          return;
        }
        pendingRequests.current.delete(id);
        clearTimeout(pending.timer);
        try {
          pending.resolve(data ? JSON.parse(data) : {});
        } catch (error) {
          pending.reject(
            error instanceof Error
              ? error
              : new Error(
                  '[react-native-cn-maps] invalid command result payload'
                )
          );
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
              coordinateSystem,
              provider
            ),
          },
        } satisfies RegionChangeEvent);
      },
      [coordinateSystem, provider, onRegionChange]
    );

    const handleRegionChangeComplete = React.useCallback(
      (event: NativeSyntheticEvent<NativeRegionChangeEvent>) => {
        onRegionChangeComplete?.({
          nativeEvent: {
            ...event.nativeEvent,
            region: fromProviderRegion(
              event.nativeEvent.region,
              coordinateSystem,
              provider
            ),
          },
        } satisfies RegionChangeEvent);
      },
      [coordinateSystem, provider, onRegionChangeComplete]
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
                    coordinateSystem,
                    provider
                  ),
                  position: event.nativeEvent.position,
                },
              });
            }
          : undefined,
      [coordinateSystem, provider]
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
              coordinateSystem,
              provider
            ),
            placeId: event.nativeEvent.placeId,
            name: event.nativeEvent.name,
          },
        } satisfies PoiClickEvent);
      },
      [coordinateSystem, provider, onPoiClick]
    );

    const handleUserLocationChange = React.useCallback(
      (event: NativeSyntheticEvent<NativeUserLocationChangeEvent>) => {
        const native = event.nativeEvent.coordinate;
        onUserLocationChange?.({
          nativeEvent: {
            coordinate: native
              ? {
                  ...fromProviderCoordinate(native, coordinateSystem, provider),
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
      [coordinateSystem, provider, onUserLocationChange]
    );

    // kmlSrc: the China SDKs have no native KML loader, so fetch + parse the KML
    // in JS and render it as a <Geojson> overlay (WGS-84). Fires onKmlReady.
    const [kmlGeojson, setKmlGeojson] =
      React.useState<KmlFeatureCollection | null>(null);
    const onKmlReadyRef = React.useRef(onKmlReady);
    onKmlReadyRef.current = onKmlReady;
    React.useEffect(() => {
      if (!kmlSrc) {
        setKmlGeojson(null);
        return;
      }
      let cancelled = false;
      (async () => {
        try {
          // kmlSrc 以 "<" 开头视为内联 KML 字符串（离线 / 示例数据），
          // 否则按 URL fetch。
          const text = kmlSrc.trimStart().startsWith('<')
            ? kmlSrc
            : await (await fetch(kmlSrc)).text();
          if (cancelled) return;
          const { geojson, markers } = parseKml(text);
          setKmlGeojson(geojson);
          onKmlReadyRef.current?.({ nativeEvent: { markers } });
        } catch {
          if (!cancelled) setKmlGeojson(null);
        }
      })();
      return () => {
        cancelled = true;
      };
    }, [kmlSrc]);

    return (
      <NativeMapView
        {...rest}
        ref={nativeRef}
        provider={provider}
        coordinateSystem={coordinateSystem}
        initialRegion={toProviderRegion(
          initialRegion,
          coordinateSystem,
          provider
        )}
        region={
          region instanceof AnimatedRegion
            ? undefined
            : toProviderRegion(region, coordinateSystem, provider)
        }
        initialCamera={toProviderCamera(
          initialCamera,
          coordinateSystem,
          provider
        )}
        camera={toProviderCamera(camera, coordinateSystem, provider)}
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
            read the coordinate system + provider from context to convert into the
            provider's native system (gcj02 for amap/tencent, bd09 for baidu). */}
        <MapProviderContext.Provider value={provider}>
          <MapCoordinateSystemContext.Provider value={coordinateSystem}>
            {children}
          </MapCoordinateSystemContext.Provider>
          {/* KML parsed from kmlSrc is WGS-84 by spec, so force that system for
              its <Geojson> subtree regardless of the map's coordinateSystem. */}
          {kmlGeojson ? (
            <MapCoordinateSystemContext.Provider value="wgs84">
              <MapGeojson geojson={kmlGeojson} />
            </MapCoordinateSystemContext.Provider>
          ) : null}
        </MapProviderContext.Provider>
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
