import type { KmlMarker } from './types';

/**
 * Minimal KML → GeoJSON parser. react-native-maps loads `kmlSrc` with a native
 * KML renderer; the China map SDKs have none, so we parse KML in JS and draw it
 * with the (provider-agnostic) `<Geojson>` component instead.
 *
 * KML coordinates are WGS-84 `longitude,latitude[,altitude]`. The caller renders
 * the result under a `coordinateSystem="wgs84"` context so it converts correctly.
 *
 * Supports the common Placemark geometries (Point / LineString / Polygon) plus
 * `<name>` / `<description>`. Not a full OGC KML implementation (no network
 * links, ground overlays, styles-by-url); that matches RNM's practical coverage.
 */

export type KmlGeometry =
  | { type: 'Point'; coordinates: [number, number] }
  | { type: 'LineString'; coordinates: Array<[number, number]> }
  | { type: 'Polygon'; coordinates: Array<Array<[number, number]>> };

export type KmlFeature = {
  type: 'Feature';
  geometry: KmlGeometry;
  properties: Record<string, unknown>;
};

export type KmlFeatureCollection = {
  type: 'FeatureCollection';
  features: KmlFeature[];
};

const innerTag = (block: string, name: string): string | undefined => {
  const m = block.match(
    new RegExp(`<${name}\\b[^>]*>([\\s\\S]*?)</${name}>`, 'i')
  );
  return m?.[1]?.trim();
};

const stripCdata = (s: string): string =>
  s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim();

const decodeXml = (s: string): string =>
  s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');

// "lon,lat,alt  lon,lat,alt …" → [[lon,lat], …] (altitude dropped).
const parseCoords = (raw: string | undefined): Array<[number, number]> => {
  if (!raw) return [];
  return raw
    .trim()
    .split(/\s+/)
    .map((tuple) => tuple.split(',').map(Number))
    .filter(
      (c) => c.length >= 2 && Number.isFinite(c[0]) && Number.isFinite(c[1])
    )
    .map((c) => [c[0], c[1]] as [number, number]);
};

export function parseKml(kml: string): {
  geojson: KmlFeatureCollection;
  markers: KmlMarker[];
} {
  const features: KmlFeature[] = [];
  const markers: KmlMarker[] = [];
  const placemarks = kml.match(/<Placemark\b[\s\S]*?<\/Placemark>/gi) ?? [];

  placemarks.forEach((pm, i) => {
    const name = decodeXml(stripCdata(innerTag(pm, 'name') ?? ''));
    const description = decodeXml(
      stripCdata(innerTag(pm, 'description') ?? '')
    );
    const idAttr = pm.match(/<Placemark\b[^>]*\bid="([^"]*)"/i)?.[1];
    const id = idAttr || (name ? `${name}-${i}` : `kml-${i}`);
    const properties = { name, description };

    const point = innerTag(pm, 'Point');
    if (point) {
      const coords = parseCoords(innerTag(point, 'coordinates'));
      const first = coords[0];
      if (first) {
        const [lng, lat] = first;
        features.push({
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [lng, lat] },
          properties,
        });
        markers.push({
          id,
          title: name,
          description,
          coordinate: { latitude: lat, longitude: lng },
          position: { x: 0, y: 0 },
        });
      }
    }

    const line = innerTag(pm, 'LineString');
    if (line) {
      const coords = parseCoords(innerTag(line, 'coordinates'));
      if (coords.length >= 2) {
        features.push({
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: coords },
          properties,
        });
      }
    }

    const polygon = innerTag(pm, 'Polygon');
    if (polygon) {
      const outer = innerTag(polygon, 'outerBoundaryIs');
      const ring = parseCoords(innerTag(outer ?? polygon, 'coordinates'));
      if (ring.length >= 3) {
        features.push({
          type: 'Feature',
          geometry: { type: 'Polygon', coordinates: [ring] },
          properties,
        });
      }
    }
  });

  return { geojson: { type: 'FeatureCollection', features }, markers };
}
