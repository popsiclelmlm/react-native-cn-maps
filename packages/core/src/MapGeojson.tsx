import React from 'react';
import Marker from './MapMarker';
import Polyline from './MapPolyline';
import Polygon from './MapPolygon';
import { flattenGeojson } from './geojson';
import type { GeojsonProps, MapPressEvent } from './types';

/**
 * `<Geojson>` — pure-JS GeoJSON renderer. Flattens the GeoJSON into the
 * existing `<Marker>`/`<Polyline>`/`<Polygon>` child host components; coordinate
 * conversion is handled by those children via context. No native code.
 *
 * GeoJSON is WGS-84 by spec, so set `<MapView coordinateSystem="wgs84">`.
 * `onPress` forwards each child's MapPressEvent but does not attach the source
 * feature (RNM does); `lineDashPhase` is accepted but ignored.
 */
function GeojsonComponent(props: GeojsonProps) {
  const {
    geojson,
    strokeColor,
    fillColor,
    strokeWidth,
    lineDashPattern,
    markerComponent,
    image,
    pinColor,
    title,
    zIndex,
    tappable,
    onPress,
  } = props;

  const shapes = React.useMemo(() => flattenGeojson(geojson), [geojson]);
  const dash = lineDashPattern ? Array.from(lineDashPattern) : undefined;

  return (
    <>
      {shapes.map((shape, index) => {
        const key = `${shape.kind}-${index}`;
        if (shape.kind === 'point') {
          return (
            <Marker
              key={key}
              coordinate={shape.coordinate}
              title={title}
              image={image}
              pinColor={pinColor}
              zIndex={zIndex}
              onPress={
                onPress
                  ? () =>
                      onPress({
                        nativeEvent: {
                          coordinate: shape.coordinate,
                          position: { x: 0, y: 0 },
                        },
                      } as MapPressEvent)
                  : undefined
              }
            >
              {markerComponent}
            </Marker>
          );
        }
        if (shape.kind === 'line') {
          return (
            <Polyline
              key={key}
              coordinates={shape.coordinates}
              strokeColor={strokeColor}
              strokeWidth={strokeWidth}
              lineDashPattern={dash}
              zIndex={zIndex}
              tappable={tappable}
              onPress={onPress}
            />
          );
        }
        return (
          <Polygon
            key={key}
            coordinates={shape.coordinates}
            holes={shape.holes}
            strokeColor={strokeColor}
            strokeWidth={strokeWidth}
            fillColor={fillColor}
            lineDashPattern={dash}
            zIndex={zIndex}
            tappable={tappable}
            onPress={onPress}
          />
        );
      })}
    </>
  );
}

export type GeojsonComponentType = ((
  props: GeojsonProps
) => React.ReactElement) & {
  __MAP_GEOJSON: true;
};

export const Geojson = GeojsonComponent as unknown as GeojsonComponentType;

Geojson.__MAP_GEOJSON = true;

export default Geojson;
export type { GeojsonProps as MapGeojsonProps };
