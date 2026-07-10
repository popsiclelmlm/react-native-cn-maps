import { useRef, useState } from 'react';
import { StyleSheet, View, Dimensions, Platform } from 'react-native';

import MapView, { Marker, AnimatedRegion } from 'react-native-cn-maps';
import { DemoButton, DemoControls, DemoHint } from './_ui';

const screen = Dimensions.get('window');

const ASPECT_RATIO = screen.width / screen.height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function AnimatedMarkers(props: any) {
  const marker = useRef<any>(null);
  const [supported] = useState(false);
  // AnimatedRegion 只创建一次，跨渲染保持同一实例
  const coordinate = useRef<any>(
    new AnimatedRegion({
      latitude: LATITUDE,
      longitude: LONGITUDE,
    })
  ).current;

  function animate() {
    const newCoordinate = {
      latitude: LATITUDE + (Math.random() - 0.5) * (LATITUDE_DELTA / 2),
      longitude: LONGITUDE + (Math.random() - 0.5) * (LONGITUDE_DELTA / 2),
    };

    if (Platform.OS === 'android') {
      if (marker.current) {
        marker.current._component.animateMarkerToCoordinate(newCoordinate, 500);
      }
    } else {
      // 不显式传入时 useNativeDriver 默认为 false，这里显式开启原生驱动
      coordinate.timing({ ...newCoordinate, useNativeDriver: true }).start();
    }
  }

  if (!supported) {
    return (
      <View style={styles.error}>
        <DemoHint>Fabric 地图暂不支持动画</DemoHint>
      </View>
    );
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
          ref={(m: any) => {
            marker.current = m;
          }}
          coordinate={coordinate}
        />
      </MapView>
      <DemoControls>
        <DemoButton label="平滑移动" onPress={() => animate()} />
      </DemoControls>
    </View>
  );
}

const styles = StyleSheet.create({
  error: {
    ...StyleSheet.absoluteFill,
    justifyContent: 'center',
    alignItems: 'center',
  },
  container: {
    ...StyleSheet.absoluteFill,
  },
  map: {
    ...StyleSheet.absoluteFill,
  },
});

export default AnimatedMarkers;
