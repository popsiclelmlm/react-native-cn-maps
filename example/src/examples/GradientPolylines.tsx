import { useState } from 'react';
import { StyleSheet, Dimensions } from 'react-native';

import MapView, { Polyline } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

const COORDINATES = [
  { latitude: 31.2446759, longitude: 121.4709569 },
  { latitude: 31.2317886, longitude: 121.484454 },
  { latitude: 31.2086748, longitude: 121.4899372 },
  { latitude: 31.2155653, longitude: 121.4483213 },
  { latitude: 31.2370105, longitude: 121.4464935 },
  { latitude: 31.2446759, longitude: 121.4709569 },
];

const COLORS = [
  '#7F0000',
  '#00000000', // 无颜色，会在前后两个坐标之间形成一段「长」渐变
  '#B24112',
  '#E5845C',
  '#238C23',
  '#7F0000',
];

function GradientPolylines(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [coordinates] = useState(COORDINATES);

  return (
    <MapView
      provider={props.provider}
      style={styles.container}
      initialRegion={region}
    >
      <Polyline
        coordinates={coordinates}
        strokeColor="#000"
        strokeColors={COLORS}
        strokeWidth={6}
      />
    </MapView>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
  },
});

export default GradientPolylines;
