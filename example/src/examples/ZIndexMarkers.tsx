import { useRef, useState } from 'react';
import { Dimensions, StyleSheet, View } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import { DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const MARKERS_LATITUDE_DELTA = 0.03;
const MARKERS_LONGITUDE_DELTA = MARKERS_LATITUDE_DELTA * ASPECT_RATIO;
const MAP_LATITUDE_DELTA = 0.3;
const MAP_LONGITUDE_DELTA = MAP_LATITUDE_DELTA * ASPECT_RATIO;
const NUM_MARKERS = 100;
const PERCENT_SPECIAL_MARKERS = 0.1;

function ZIndexMarkers(props: any) {
  const map = useRef<any>(null);
  // markerInfo 在初始化时计算一次（复现原类初始化中的随机生成逻辑）
  const [markerInfo] = useState(() => {
    const list = [];
    for (let i = 1; i < NUM_MARKERS; i++) {
      list.push({
        latitude: (Math.random() * 2 - 1) * MARKERS_LATITUDE_DELTA + LATITUDE,
        longitude:
          (Math.random() * 2 - 1) * MARKERS_LONGITUDE_DELTA + LONGITUDE,
        isSpecial: Math.random() < PERCENT_SPECIAL_MARKERS,
        id: i,
      });
    }
    return list;
  });

  const markers = markerInfo.map((info: any) => (
    <Marker
      coordinate={info}
      key={info.id}
      pinColor={info.isSpecial ? '#c5a620' : undefined}
      style={info.isSpecial ? styles.specialMarker : null}
    />
  ));

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
          latitudeDelta: MAP_LATITUDE_DELTA,
          longitudeDelta: MAP_LONGITUDE_DELTA,
        }}
      >
        {markers}
      </MapView>
      <DemoControls>
        <DemoHint>黄色标注的 zIndex 更高，会显示在其它标注之上。</DemoHint>
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
  specialMarker: {
    zIndex: 1,
  },
});

export default ZIndexMarkers;
