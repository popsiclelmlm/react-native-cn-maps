import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';
import { DemoButton, DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
let id = 0;

function randomColor() {
  return `#${Math.floor(Math.random() * 16777215)
    .toString(16)
    .padStart(6, '0')}`;
}

function DefaultMarkers(props: any) {
  // region 初始化后不再变化，只解构值、不需要 setter
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [markers, setMarkers] = useState<any[]>([]);

  function onMapPress(e: any) {
    // 依赖旧值追加，使用函数式更新复现 setState 语义
    setMarkers((prev) => [
      ...prev,
      {
        coordinate: e.nativeEvent.coordinate,
        key: id++,
        color: randomColor(),
      },
    ]);
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        onPress={(e) => onMapPress(e)}
      >
        {markers.map((marker: any) => (
          <Marker
            key={marker.key}
            coordinate={marker.coordinate}
            pinColor={marker.color}
          />
        ))}
      </MapView>

      <DemoControls>
        <DemoHint>点击地图添加随机颜色的标注</DemoHint>
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

export default DefaultMarkers;
