import { useRef, useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Circle, Polygon, Polyline } from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

// react-native-cn-maps 的 Circle/Polygon/Polyline 为新架构函数组件，暂未暴露
// ref / setNativeProps（旧架构 API）。为保留官方示例结构，此处以 any 断言渲染；
// 运行时 ref 不会挂载，setNativeProps 调用会被安全跳过。
const AnyCircle: any = Circle;
const AnyPolygon: any = Polygon;
const AnyPolyline: any = Polyline;

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function SetNativePropsOverlays(props: any) {
  // 组件实例可变引用（非渲染状态）
  const circleRef = useRef<any>(null);
  const polygonRef = useRef<any>(null);
  const polylineRef = useRef<any>(null);

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

  const handleColorChange = (color: any) => {
    const nativeProps = { strokeColor: color };
    circleRef.current?.setNativeProps(nativeProps);
    polygonRef.current?.setNativeProps(nativeProps);
    polylineRef.current?.setNativeProps(nativeProps);
  };

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <AnyCircle
          ref={(ref: any) => {
            circleRef.current = ref;
          }}
          center={circle.center}
          radius={circle.radius}
          fillColor="rgba(255, 255, 255, 0.6)"
          strokeColor="green"
          zIndex={3}
          strokeWidth={3}
        />
        <AnyPolygon
          ref={(ref: any) => {
            polygonRef.current = ref;
          }}
          coordinates={polygon}
          fillColor="rgba(255, 255, 255, 0.6)"
          strokeColor="green"
          strokeWidth={2}
        />
        <AnyPolyline
          ref={(ref: any) => {
            polylineRef.current = ref;
          }}
          coordinates={polyline}
          strokeColor="green"
          strokeWidth={3}
        />
      </MapView>
      <DemoControls>
        <DemoButtonRow>
          <DemoButton
            label="绿色"
            variant="secondary"
            onPress={() => handleColorChange('green')}
          />
          <DemoButton
            label="黑色"
            variant="secondary"
            onPress={() => handleColorChange('black')}
          />
          <DemoButton
            label="红色"
            variant="secondary"
            onPress={() => handleColorChange('red')}
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
