import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Circle, Polygon, Polyline } from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

// 新架构下 Circle/Polygon/Polyline 是函数组件，用 props 驱动即可，无需旧架构的
// ref.setNativeProps —— 这里用 state 保存描边色，点击按钮改 state 触发重渲染。
const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function SetNativePropsOverlays(props: any) {
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
  const [strokeColor, setStrokeColor] = useState('green');

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
          fillColor="rgba(255, 255, 255, 0.6)"
          strokeColor={strokeColor}
          zIndex={3}
          strokeWidth={3}
        />
        <Polygon
          coordinates={polygon}
          fillColor="rgba(255, 255, 255, 0.6)"
          strokeColor={strokeColor}
          strokeWidth={2}
        />
        <Polyline
          coordinates={polyline}
          strokeColor={strokeColor}
          strokeWidth={3}
        />
      </MapView>
      <DemoControls>
        <DemoButtonRow>
          <DemoButton
            label="绿色"
            variant="secondary"
            onPress={() => setStrokeColor('green')}
          />
          <DemoButton
            label="黑色"
            variant="secondary"
            onPress={() => setStrokeColor('black')}
          />
          <DemoButton
            label="红色"
            variant="secondary"
            onPress={() => setStrokeColor('red')}
          />
        </DemoButtonRow>
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

export default SetNativePropsOverlays;
