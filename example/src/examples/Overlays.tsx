import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Circle, Polygon, Polyline } from 'react-native-cn-maps';
import { DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function Overlays(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [circle] = useState({
    center: {
      latitude: LATITUDE + SPACE,
      longitude: LONGITUDE + SPACE,
    },
    radius: 700,
  });
  const [polygon] = useState([
    {
      latitude: LATITUDE + SPACE,
      longitude: LONGITUDE + SPACE,
    },
    {
      latitude: LATITUDE - SPACE,
      longitude: LONGITUDE - SPACE,
    },
    {
      latitude: LATITUDE - SPACE,
      longitude: LONGITUDE + SPACE,
    },
  ]);
  const [polyline] = useState([
    {
      latitude: LATITUDE + SPACE,
      longitude: LONGITUDE - SPACE,
    },
    {
      latitude: LATITUDE - 2 * SPACE,
      longitude: LONGITUDE + 2 * SPACE,
    },
    {
      latitude: LATITUDE - SPACE,
      longitude: LONGITUDE - SPACE,
    },
    {
      latitude: LATITUDE - 2 * SPACE,
      longitude: LONGITUDE - SPACE,
    },
  ]);

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <Circle
          center={circle.center}
          radius={circle.radius}
          fillColor="rgba(255, 255, 255, 1)"
          strokeColor="rgba(0,0,0,0.5)"
          zIndex={2}
          strokeWidth={2}
        />
        <Polygon
          coordinates={polygon}
          fillColor="rgba(0, 200, 0, 0.5)"
          strokeColor="rgba(0,0,0,0.5)"
          strokeWidth={2}
        />
        <Polyline
          coordinates={polyline}
          strokeColor="rgba(0,0,200,0.5)"
          strokeWidth={3}
          lineDashPattern={[5, 2, 3, 2]}
        />
      </MapView>
      <DemoControls>
        <DemoHint>渲染圆、多边形与折线</DemoHint>
      </DemoControls>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
  },
  map: {
    ...StyleSheet.absoluteFill,
  },
});

export default Overlays;
