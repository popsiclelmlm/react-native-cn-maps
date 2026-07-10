import type {
  CoordinateSystem,
  Camera,
  LatLng,
  MapProvider,
  Region,
} from './types';
import type { NativeCamera } from './MapViewNativeComponent';

const A = 6378245.0;
const EE = 0.00669342162296594323;
const PI = Math.PI;
// BD-09 uses a slightly different pi-based constant for its extra encryption.
const X_PI = (PI * 3000.0) / 180.0;

function isOutsideChina(latitude: number, longitude: number) {
  return (
    longitude < 72.004 ||
    longitude > 137.8347 ||
    latitude < 0.8293 ||
    latitude > 55.8271
  );
}

function transformLatitude(x: number, y: number) {
  let ret =
    -100.0 +
    2.0 * x +
    3.0 * y +
    0.2 * y * y +
    0.1 * x * y +
    0.2 * Math.sqrt(Math.abs(x));
  ret +=
    ((20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0) /
    3.0;
  ret +=
    ((20.0 * Math.sin(y * PI) + 40.0 * Math.sin((y / 3.0) * PI)) * 2.0) / 3.0;
  ret +=
    ((160.0 * Math.sin((y / 12.0) * PI) + 320 * Math.sin((y * PI) / 30.0)) *
      2.0) /
    3.0;
  return ret;
}

function transformLongitude(x: number, y: number) {
  let ret =
    300.0 +
    x +
    2.0 * y +
    0.1 * x * x +
    0.1 * x * y +
    0.1 * Math.sqrt(Math.abs(x));
  ret +=
    ((20.0 * Math.sin(6.0 * x * PI) + 20.0 * Math.sin(2.0 * x * PI)) * 2.0) /
    3.0;
  ret +=
    ((20.0 * Math.sin(x * PI) + 40.0 * Math.sin((x / 3.0) * PI)) * 2.0) / 3.0;
  ret +=
    ((150.0 * Math.sin((x / 12.0) * PI) + 300.0 * Math.sin((x / 30.0) * PI)) *
      2.0) /
    3.0;
  return ret;
}

export function wgs84ToGcj02(coordinate: LatLng): LatLng {
  const { latitude, longitude } = coordinate;

  if (isOutsideChina(latitude, longitude)) {
    return coordinate;
  }

  let dLat = transformLatitude(longitude - 105.0, latitude - 35.0);
  let dLon = transformLongitude(longitude - 105.0, latitude - 35.0);
  const radLat = (latitude / 180.0) * PI;
  let magic = Math.sin(radLat);
  magic = 1 - EE * magic * magic;
  const sqrtMagic = Math.sqrt(magic);
  dLat = (dLat * 180.0) / (((A * (1 - EE)) / (magic * sqrtMagic)) * PI);
  dLon = (dLon * 180.0) / ((A / sqrtMagic) * Math.cos(radLat) * PI);

  return {
    latitude: latitude + dLat,
    longitude: longitude + dLon,
  };
}

export function gcj02ToWgs84(coordinate: LatLng): LatLng {
  if (isOutsideChina(coordinate.latitude, coordinate.longitude)) {
    return coordinate;
  }

  // `wgs84ToGcj02` has no closed-form inverse, so refine a WGS-84 guess until it
  // re-encrypts back to the input GCJ-02 point. Three Newton-style passes bring
  // the residual to well under a centimetre (the old single "value*2 - forward"
  // subtraction left ~1–2 m of error).
  let wgs: LatLng = {
    latitude: coordinate.latitude,
    longitude: coordinate.longitude,
  };
  for (let i = 0; i < 3; i++) {
    const gcj = wgs84ToGcj02(wgs);
    wgs = {
      latitude: wgs.latitude + (coordinate.latitude - gcj.latitude),
      longitude: wgs.longitude + (coordinate.longitude - gcj.longitude),
    };
  }
  return wgs;
}

// BD-09 (Baidu) ↔ GCJ-02. Baidu adds one more encryption layer on top of GCJ-02.
export function bd09ToGcj02(coordinate: LatLng): LatLng {
  const x = coordinate.longitude - 0.0065;
  const y = coordinate.latitude - 0.006;
  const z = Math.sqrt(x * x + y * y) - 0.00002 * Math.sin(y * X_PI);
  const theta = Math.atan2(y, x) - 0.000003 * Math.cos(x * X_PI);
  return {
    latitude: z * Math.sin(theta),
    longitude: z * Math.cos(theta),
  };
}

export function gcj02ToBd09(coordinate: LatLng): LatLng {
  const x = coordinate.longitude;
  const y = coordinate.latitude;
  const z = Math.sqrt(x * x + y * y) + 0.00002 * Math.sin(y * X_PI);
  const theta = Math.atan2(y, x) + 0.000003 * Math.cos(x * X_PI);
  return {
    latitude: z * Math.sin(theta) + 0.006,
    longitude: z * Math.cos(theta) + 0.0065,
  };
}

// Each provider's native coordinate system. AMap / Tencent / Map Kit are GCJ-02;
// Baidu is BD-09. GCJ-02 is the conversion hub (coordinate.ts implements
// wgs84/bd09 ↔ gcj02). 查证: Map Kit 国内展示为 GCJ-02（与高德/腾讯一致）。
const PROVIDER_SYSTEM: Record<MapProvider, CoordinateSystem> = {
  amap: 'gcj02',
  tencent: 'gcj02',
  baidu: 'bd09',
  mapkit: 'gcj02',
};

/** The native coordinate system a provider's SDK expects. */
export function providerCoordinateSystem(
  provider: MapProvider
): CoordinateSystem {
  return PROVIDER_SYSTEM[provider] ?? 'gcj02';
}

// Convert between any two systems via the GCJ-02 hub.
function convertSystem(
  coordinate: LatLng,
  from: CoordinateSystem,
  to: CoordinateSystem
): LatLng {
  if (from === to) {
    return coordinate;
  }
  let gcj02: LatLng;
  switch (from) {
    case 'wgs84':
      gcj02 = wgs84ToGcj02(coordinate);
      break;
    case 'bd09':
      gcj02 = bd09ToGcj02(coordinate);
      break;
    default:
      gcj02 = coordinate;
  }
  switch (to) {
    case 'wgs84':
      return gcj02ToWgs84(gcj02);
    case 'bd09':
      return gcj02ToBd09(gcj02);
    default:
      return gcj02;
  }
}

// Convert the user's declared `coordinateSystem` into the provider's native
// system (gcj02 for amap/tencent, bd09 for baidu). `provider` defaults to amap so
// existing callers / tests keep their previous gcj02 behavior.
export function toProviderCoordinate(
  coordinate: LatLng,
  coordinateSystem: CoordinateSystem,
  provider: MapProvider = 'amap'
): LatLng {
  return convertSystem(
    coordinate,
    coordinateSystem,
    providerCoordinateSystem(provider)
  );
}

export function fromProviderCoordinate(
  coordinate: LatLng,
  coordinateSystem: CoordinateSystem,
  provider: MapProvider = 'amap'
): LatLng {
  return convertSystem(
    coordinate,
    providerCoordinateSystem(provider),
    coordinateSystem
  );
}

export function toProviderRegion(
  region: Region | undefined,
  coordinateSystem: CoordinateSystem,
  provider: MapProvider = 'amap'
): Region | undefined {
  if (!region) {
    return undefined;
  }

  return {
    ...region,
    ...toProviderCoordinate(region, coordinateSystem, provider),
  };
}

export function fromProviderRegion(
  region: Region,
  coordinateSystem: CoordinateSystem,
  provider: MapProvider = 'amap'
): Region {
  return {
    ...region,
    ...fromProviderCoordinate(region, coordinateSystem, provider),
  };
}

/**
 * Convert an RNM {@link Camera} (with a nested `center` LatLng) into the flat
 * {@link NativeCamera} struct the codegen component expects, converting the
 * center into the provider's native coordinate system on the way.
 */
export function toProviderCamera(
  camera: Camera | undefined,
  coordinateSystem: CoordinateSystem,
  provider: MapProvider = 'amap'
): NativeCamera | undefined {
  if (!camera) {
    return undefined;
  }

  const center = toProviderCoordinate(
    camera.center,
    coordinateSystem,
    provider
  );

  return {
    latitude: center.latitude,
    longitude: center.longitude,
    heading: camera.heading,
    pitch: camera.pitch,
    zoom: camera.zoom,
    altitude: camera.altitude ?? 0,
  };
}

/**
 * Inverse of {@link toProviderCamera}: rebuild the RNM `{ center }` shape from a
 * native camera struct, converting the center back out of the provider system.
 * Used by the `getCamera` command.
 */
export function fromProviderCamera(
  camera: NativeCamera,
  coordinateSystem: CoordinateSystem,
  provider: MapProvider = 'amap'
): Camera {
  const center = fromProviderCoordinate(
    { latitude: camera.latitude, longitude: camera.longitude },
    coordinateSystem,
    provider
  );

  return {
    center,
    heading: camera.heading,
    pitch: camera.pitch,
    zoom: camera.zoom,
    altitude: camera.altitude,
  };
}
