import { useRef } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import { DemoButton, DemoControls } from './_ui';

const screen = Dimensions.get('window');

const ASPECT_RATIO = screen.width / screen.height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function AnimatedMarkers(props: any) {
  const markerRef = useRef<any>(null);

  function animate() {
    // 随机取一个附近坐标，命令原生标记平滑移动过去（两端统一走
    // animateMarkerToCoordinate 命令，无需 AnimatedRegion）。
    const newCoordinate = {
      latitude: LATITUDE + (Math.random() - 0.5) * (LATITUDE_DELTA / 2),
      longitude: LONGITUDE + (Math.random() - 0.5) * (LONGITUDE_DELTA / 2),
    };
    markerRef.current?.animateMarkerToCoordinate(newCoordinate, 500);
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={{
          latitude: LATITUDE,
          longitude: LONGITUDE,
          latitudeDelta: LATITUDE_DELTA,
          longitudeDelta: LONGITUDE_DELTA,
        }}
      >
        <Marker
          ref={markerRef}
          coordinate={{ latitude: LATITUDE, longitude: LONGITUDE }}
        />
      </MapView>
      <DemoControls>
        <DemoButton label="平滑移动" onPress={() => animate()} />
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

export default AnimatedMarkers;
