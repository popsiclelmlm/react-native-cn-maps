import { useState, useRef } from 'react';
import {
  StyleSheet,
  View,
  Dimensions,
  TouchableOpacity,
  Image,
} from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import flagBlueImg from './assets/flag-blue.png';
import flagPinkImg from './assets/flag-pink.png';
import { DemoButton, DemoControls } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function TakeSnapshot(props: any) {
  const map = useRef<any>(null);
  const [mapSnapshot, setMapSnapshot] = useState<any>(null);

  function takeSnapshot() {
    map.current
      .takeSnapshot({
        width: 300,
        height: 300,
        region: {
          latitude: LATITUDE - SPACE,
          longitude: LONGITUDE - SPACE,
          latitudeDelta: 0.01,
          longitudeDelta: 0.01 * ASPECT_RATIO,
        },
      })
      .then((result: string) => {
        console.log('截图成功', result);
        // 处理成功结果
        setMapSnapshot(result);
      })
      .catch((error: any) => {
        console.log('截图失败', error); // 处理失败情况
      });
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        ref={(ref) => {
          map.current = ref;
        }}
        style={styles.map}
        initialRegion={{
          latitude: LATITUDE,
          longitude: LONGITUDE,
          latitudeDelta: LATITUDE_DELTA,
          longitudeDelta: LONGITUDE_DELTA,
        }}
      >
        <Marker
          coordinate={{
            latitude: LATITUDE + SPACE,
            longitude: LONGITUDE + SPACE,
          }}
          centerOffset={{ x: -18, y: -60 }}
          anchor={{ x: 0.69, y: 1 }}
          image={flagBlueImg}
        />
        <Marker
          coordinate={{
            latitude: LATITUDE - SPACE,
            longitude: LONGITUDE - SPACE,
          }}
          centerOffset={{ x: -42, y: -60 }}
          anchor={{ x: 0.84, y: 1 }}
          image={flagPinkImg}
        />
      </MapView>

      <DemoControls>
        <DemoButton label="截图" onPress={() => takeSnapshot()} />
      </DemoControls>
      {mapSnapshot && (
        <TouchableOpacity
          style={[styles.container, styles.overlay]}
          onPress={() => setMapSnapshot(null)}
        >
          <Image source={{ uri: mapSnapshot }} style={styles.mapSnapshot} />
        </TouchableOpacity>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
    justifyContent: 'flex-end',
    alignItems: 'center',
  },
  map: {
    ...StyleSheet.absoluteFill,
  },
  overlay: {
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
  },
  mapSnapshot: { width: 300, height: 300 },
});

export default TakeSnapshot;
