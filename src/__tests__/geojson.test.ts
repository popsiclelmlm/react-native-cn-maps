import { describe, expect, it } from '@jest/globals';
import { flattenGeojson } from '../geojson';
import Geojson, { Geojson as NamedGeojson } from '../MapGeojson';

describe('flattenGeojson (M14)', () => {
  it('returns [] for malformed input', () => {
    expect(flattenGeojson(null)).toEqual([]);
    expect(flattenGeojson(42)).toEqual([]);
    expect(flattenGeojson({})).toEqual([]);
    expect(flattenGeojson({ type: 'Nonsense' })).toEqual([]);
  });

  it('converts a Point ([lng, lat]) into a point shape with {latitude, longitude}', () => {
    const shapes = flattenGeojson({
      type: 'Point',
      coordinates: [121.47, 31.23],
    });
    expect(shapes).toEqual([
      { kind: 'point', coordinate: { latitude: 31.23, longitude: 121.47 } },
    ]);
  });

  it('converts a LineString into a line shape', () => {
    const shapes = flattenGeojson({
      type: 'LineString',
      coordinates: [
        [121.4, 31.2],
        [121.5, 31.3],
      ],
    });
    expect(shapes).toEqual([
      {
        kind: 'line',
        coordinates: [
          { latitude: 31.2, longitude: 121.4 },
          { latitude: 31.3, longitude: 121.5 },
        ],
      },
    ]);
  });

  it('splits a Polygon outer ring and holes', () => {
    const shapes = flattenGeojson({
      type: 'Polygon',
      coordinates: [
        [
          [0, 0],
          [0, 1],
          [1, 1],
          [0, 0],
        ],
        [
          [0.2, 0.2],
          [0.2, 0.4],
          [0.4, 0.4],
          [0.2, 0.2],
        ],
      ],
    });
    expect(shapes).toHaveLength(1);
    const polygon = shapes[0];
    expect(polygon?.kind).toBe('polygon');
    if (polygon?.kind === 'polygon') {
      expect(polygon.coordinates).toHaveLength(4);
      expect(polygon.holes).toHaveLength(1);
      expect(polygon.holes[0]).toHaveLength(4);
    }
  });

  it('flattens a FeatureCollection of mixed geometries', () => {
    const shapes = flattenGeojson({
      type: 'FeatureCollection',
      features: [
        { type: 'Feature', geometry: { type: 'Point', coordinates: [1, 2] } },
        {
          type: 'Feature',
          geometry: {
            type: 'MultiLineString',
            coordinates: [
              [
                [0, 0],
                [1, 1],
              ],
              [
                [2, 2],
                [3, 3],
              ],
            ],
          },
        },
      ],
    });
    expect(shapes.map((s) => s.kind)).toEqual(['point', 'line', 'line']);
  });
});

describe('Geojson component (M14)', () => {
  it('retains the __MAP_GEOJSON sentinel after the host-component conversion', () => {
    expect((Geojson as { __MAP_GEOJSON?: boolean }).__MAP_GEOJSON).toBe(true);
  });

  it('default export is the same component as the named export', () => {
    expect(Geojson).toBe(NamedGeojson);
  });
});
