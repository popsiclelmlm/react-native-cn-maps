import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';
import MapView, { Heatmap } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function HeatMap(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [points] = useState([
    { latitude: 31.2304, longitude: 121.4737, weight: 1 },
    { latitude: 31.2314, longitude: 121.4747, weight: 0.8 },
    { latitude: 31.2294, longitude: 121.4727, weight: 1.2 },
    // 等等
  ]);

  // 国内 provider（高德 / 百度 / 腾讯）均支持热力图，
  // 官方示例针对 Apple 地图的 PROVIDER_GOOGLE 门槛在本库中不需要。
  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <Heatmap
          points={points}
          opacity={1}
          radius={50}
          gradient={{
            colors: ['#00f', '#0ff', '#0f0', '#ff0', '#f00'],
            startPoints: [0.1, 0.3, 0.5, 0.7, 1],
            colorMapSize: 256,
          }}
        />
      </MapView>
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

export default HeatMap;
