import { useRef, useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import flagPinkImg from './assets/flag-pink.png';
import flagBlueImg from './assets/flag-blue.png';
import { DemoButton, DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
let id = 0;

function CustomMarkers(props: any) {
  // 可变的非渲染状态：下一个 marker 是否为粉色
  const pinkMarker = useRef<Boolean>(true);
  // region 初始化后不再变化，只解构值、不需要 setter
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [markers, setMarkers] = useState<any[]>([]);

  function onMapPress(e: any) {
    pinkMarker.current = !pinkMarker.current;

    setMarkers((prev) => [
      ...prev,
      {
        coordinate: e.nativeEvent.coordinate,
        key: `foo${id++}`,
        pink: pinkMarker.current,
      },
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
            image={marker.pink ? flagPinkImg : flagBlueImg}
            key={marker.key}
            coordinate={marker.coordinate}
          />
        ))}
      </MapView>

      <DemoControls>
        <DemoHint>点击地图添加标注（粉、蓝旗交替）</DemoHint>
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

export default CustomMarkers;
