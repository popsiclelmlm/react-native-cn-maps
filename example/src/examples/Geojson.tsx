import MapView, { Geojson } from 'react-native-cn-maps';
import type { Provider } from 'react-native-cn-maps';
import { StyleSheet } from 'react-native';
const myPlace: any = {
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'Point',
        coordinates: [121.4998, 31.2397],
      },
    },
  ],
};

const GeojsonMap = (props: { provider: Provider }) => (
  <MapView
    provider={props.provider}
    style={{ ...StyleSheet.absoluteFill }}
    initialRegion={{
      latitude: 31.2397,
      longitude: 121.4998,
      latitudeDelta: 0.05,
      longitudeDelta: 0.05,
    }}
  >
    <Geojson geojson={myPlace} />
  </MapView>
);

export default GeojsonMap;
