import type { CoordinateSystem, Camera, LatLng, Region } from './types';
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
  const converted = wgs84ToGcj02(coordinate);

  return {
    latitude: coordinate.latitude * 2 - converted.latitude,
    longitude: coordinate.longitude * 2 - converted.longitude,
  };
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

// The provider (AMap) coordinate system is GCJ-02. These convert between the
// user's declared `coordinateSystem` and the provider's GCJ-02 by dispatching on
// the source system — `gcj02` passes through, `wgs84`/`bd09` convert.
export function toProviderCoordinate(
  coordinate: LatLng,
  coordinateSystem: CoordinateSystem
): LatLng {
  switch (coordinateSystem) {
    case 'wgs84':
      return wgs84ToGcj02(coordinate);
    case 'bd09':
      return bd09ToGcj02(coordinate);
    case 'gcj02':
    default:
      return coordinate;
  }
}

export function fromProviderCoordinate(
  coordinate: LatLng,
  coordinateSystem: CoordinateSystem
): LatLng {
  switch (coordinateSystem) {
    case 'wgs84':
      return gcj02ToWgs84(coordinate);
    case 'bd09':
      return gcj02ToBd09(coordinate);
    case 'gcj02':
    default:
      return coordinate;
  }
}

export function toProviderRegion(
  region: Region | undefined,
  coordinateSystem: CoordinateSystem
): Region | undefined {
  if (!region) {
    return undefined;
  }

  return {
    ...region,
    ...toProviderCoordinate(region, coordinateSystem),
  };
}

export function fromProviderRegion(
  region: Region,
  coordinateSystem: CoordinateSystem
): Region {
  return {
    ...region,
    ...fromProviderCoordinate(region, coordinateSystem),
  };
}

/**
 * Convert an RNM {@link Camera} (with a nested `center` LatLng) into the flat
 * {@link NativeCamera} struct the codegen component expects, converting the
 * center into the provider's coordinate system (gcj02) on the way.
 */
export function toProviderCamera(
  camera: Camera | undefined,
  coordinateSystem: CoordinateSystem
): NativeCamera | undefined {
  if (!camera) {
    return undefined;
  }

  const center = toProviderCoordinate(camera.center, coordinateSystem);

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
 * native camera struct, converting the center back out of gcj02. Reserved for
 * the M6 `getCamera` command.
 */
export function fromProviderCamera(
  camera: NativeCamera,
  coordinateSystem: CoordinateSystem
): Camera {
  const center = fromProviderCoordinate(
    { latitude: camera.latitude, longitude: camera.longitude },
    coordinateSystem
  );

  return {
    center,
    heading: camera.heading,
    pitch: camera.pitch,
    zoom: camera.zoom,
    altitude: camera.altitude,
  };
}
