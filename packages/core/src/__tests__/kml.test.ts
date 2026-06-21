import { describe, expect, it } from '@jest/globals';
import { parseKml } from '../kml';

const SAMPLE = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark id="p1">
      <name>外滩</name>
      <description><![CDATA[The <b>Bund</b> & river]]></description>
      <Point><coordinates>121.4998,31.2397,0</coordinates></Point>
    </Placemark>
    <Placemark>
      <name>line</name>
      <LineString>
        <coordinates>
          121.50,31.24,0
          121.47,31.23,0
        </coordinates>
      </LineString>
    </Placemark>
    <Placemark>
      <name>area</name>
      <Polygon><outerBoundaryIs><LinearRing><coordinates>
        121.50,31.25 121.52,31.25 121.52,31.23 121.50,31.25
      </coordinates></LinearRing></outerBoundaryIs></Polygon>
    </Placemark>
  </Document>
</kml>`;

describe('parseKml', () => {
  it('parses Point / LineString / Polygon placemarks into GeoJSON', () => {
    const { geojson } = parseKml(SAMPLE);
    expect(geojson.type).toBe('FeatureCollection');
    expect(geojson.features.map((f) => f.geometry.type)).toEqual([
      'Point',
      'LineString',
      'Polygon',
    ]);
  });

  it('emits a KmlMarker per Point with decoded name/description + WGS-84 coordinate', () => {
    const { markers } = parseKml(SAMPLE);
    expect(markers).toHaveLength(1);
    expect(markers[0]).toMatchObject({
      id: 'p1',
      title: '外滩',
      description: 'The <b>Bund</b> & river',
      coordinate: { latitude: 31.2397, longitude: 121.4998 },
    });
  });

  it('keeps KML lon,lat order (GeoJSON [lng, lat])', () => {
    const { geojson } = parseKml(SAMPLE);
    const point = geojson.features.find((f) => f.geometry.type === 'Point');
    expect(point?.geometry.coordinates).toEqual([121.4998, 31.2397]);
  });

  it('returns an empty collection for KML with no placemarks', () => {
    const { geojson, markers } = parseKml('<kml></kml>');
    expect(geojson.features).toEqual([]);
    expect(markers).toEqual([]);
  });
});
