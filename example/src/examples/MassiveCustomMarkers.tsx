import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import flagPinkImg from './assets/flag-pink.png';
import { DemoButton, DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
let id = 0;

function MassiveCustomMarkers(props: any) {
  // region 初始化后不再变化，只解构值、不需要 setter
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [markers, setMarkers] = useState<any[]>([]);

  function generateMarkers(fromCoordinate: any) {
    const result = [];
    const { latitude, longitude } = fromCoordinate;
    for (let i = 0; i < 100; i++) {
      const newMarker = {
        coordinate: {
          latitude: latitude + 0.001 * i,
          longitude: longitude + 0.001 * i,
        },
        key: `foo${id++}`,
      };
      result.push(newMarker);
    }
    return result;
  }

  function onMapPress(e: any) {
    // 依赖旧值追加，使用函数式更新复现 setState 语义
    setMarkers((prev) => [
      ...prev,
      ...generateMarkers(e.nativeEvent.coordinate),
    ]);
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        onPress={onMapPress}
      >
        {markers.map((marker: any) => (
          <Marker
            title={marker.key}
            image={flagPinkImg}
            key={marker.key}
            coordinate={marker.coordinate}
          />
        ))}
      </MapView>
      <DemoControls>
        <DemoHint>点击地图生成 100 个标注</DemoHint>
        <DemoButton
          label="清除标注"
          variant="danger"
          onPress={() => setMarkers([])}
        />
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

export default MassiveCustomMarkers;
