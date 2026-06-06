import type { LatLng } from './types';

/**
 * Neutral shapes flattened out of a GeoJSON object, ready to render as
 * `<Marker>` / `<Polyline>` / `<Polygon>`. Coordinates are in `{ latitude,
 * longitude }` (GeoJSON stores them as `[longitude, latitude]`); no CRS
 * conversion happens here — the child components apply it via context.
 */
export type GeoShape =
  | { kind: 'point'; coordinate: LatLng }
  | { kind: 'line'; coordinates: LatLng[] }
  | { kind: 'polygon'; coordinates: LatLng[]; holes: LatLng[][] };

type Position = ReadonlyArray<number>;

function toLatLng(position: unknown): LatLng | null {
  if (
    Array.isArray(position) &&
    typeof position[0] === 'number' &&
    typeof position[1] === 'number'
  ) {
    // GeoJSON order is [longitude, latitude].
    return { latitude: position[1], longitude: position[0] };
  }
  return null;
}

function toLatLngArray(positions: unknown): LatLng[] {
  if (!Array.isArray(positions)) {
    return [];
  }
  return positions
    .map((p) => toLatLng(p as Position))
    .filter((p): p is LatLng => p != null);
}

function flattenGeometry(geometry: unknown, out: GeoShape[]): void {
  if (geometry == null || typeof geometry !== 'object') {
    return;
  }
  const geo = geometry as {
    type?: unknown;
    coordinates?: unknown;
    geometries?: unknown;
  };

  switch (geo.type) {
    case 'Point': {
      const coordinate = toLatLng(geo.coordinates as Position);
      if (coordinate) {
        out.push({ kind: 'point', coordinate });
      }
      break;
    }
    case 'MultiPoint': {
      toLatLngArray(geo.coordinates).forEach((coordinate) =>
        out.push({ kind: 'point', coordinate })
      );
      break;
    }
    case 'LineString': {
      const coordinates = toLatLngArray(geo.coordinates);
      if (coordinates.length > 0) {
        out.push({ kind: 'line', coordinates });
      }
      break;
    }
    case 'MultiLineString': {
      if (Array.isArray(geo.coordinates)) {
        geo.coordinates.forEach((line) => {
          const coordinates = toLatLngArray(line);
          if (coordinates.length > 0) {
            out.push({ kind: 'line', coordinates });
          }
        });
      }
      break;
    }
    case 'Polygon': {
      pushPolygon(geo.coordinates, out);
      break;
    }
    case 'MultiPolygon': {
      if (Array.isArray(geo.coordinates)) {
        geo.coordinates.forEach((polygon) => pushPolygon(polygon, out));
      }
      break;
    }
    case 'GeometryCollection': {
      if (Array.isArray(geo.geometries)) {
        geo.geometries.forEach((g) => flattenGeometry(g, out));
      }
      break;
    }
    default:
      break;
  }
}

function pushPolygon(rings: unknown, out: GeoShape[]): void {
  if (!Array.isArray(rings) || rings.length === 0) {
    return;
  }
  const coordinates = toLatLngArray(rings[0]);
  if (coordinates.length === 0) {
    return;
  }
  const holes = rings
    .slice(1)
    .map((ring) => toLatLngArray(ring))
    .filter((ring) => ring.length > 0);
  out.push({ kind: 'polygon', coordinates, holes });
}

/**
 * Flatten any GeoJSON value (FeatureCollection / Feature / Geometry /
 * GeometryCollection) into a flat list of renderable shapes. Malformed input
 * yields an empty array rather than throwing.
 */
export function flattenGeojson(geojson: unknown): GeoShape[] {
  const out: GeoShape[] = [];
  if (geojson == null || typeof geojson !== 'object') {
    return out;
  }
  const node = geojson as {
    type?: unknown;
    features?: unknown;
    geometry?: unknown;
  };

  if (node.type === 'FeatureCollection' && Array.isArray(node.features)) {
    node.features.forEach((feature) => {
      if (feature && typeof feature === 'object') {
        flattenGeometry((feature as { geometry?: unknown }).geometry, out);
      }
    });
  } else if (node.type === 'Feature') {
    flattenGeometry(node.geometry, out);
  } else {
    flattenGeometry(node, out);
  }
  return out;
}
