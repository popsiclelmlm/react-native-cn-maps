import { StyleSheet, Dimensions, ScrollView } from 'react-native';

import MapView from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

const SAMPLE_REGION = {
  latitude: LATITUDE,
  longitude: LONGITUDE,
  latitudeDelta: LATITUDE_DELTA,
  longitudeDelta: LONGITUDE_DELTA,
};

function LiteMapView(props: any) {
  const maps = [];
  for (let i = 0; i < 10; i++) {
    maps.push(
      <MapView
        liteMode
        provider={props.provider}
        key={`map_${i}`}
        style={styles.map}
        initialRegion={SAMPLE_REGION}
      />
    );
  }
  return <ScrollView style={StyleSheet.absoluteFill}>{maps}</ScrollView>;
}

const styles = StyleSheet.create({
  map: {
    height: 200,
    marginVertical: 50,
  },
});

export default LiteMapView;
