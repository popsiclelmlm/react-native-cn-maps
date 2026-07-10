import { useRef } from 'react';
import { StyleSheet, View, Alert } from 'react-native';

import MapView from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;

function CameraControl(props: any) {
  const map = useRef<any>(null);

  async function getCamera() {
    const camera = await map.current.getCamera();
    Alert.alert('当前相机', JSON.stringify(camera), [{ text: '确定' }], {
      cancelable: true,
    });
  }

  async function setCamera() {
    const camera = await map.current.getCamera();
    // 注意：不必向 setCamera() 传入完整的相机对象。
    // 与 setState() 类似，只需传入想修改的属性即可。
    map.current.setCamera({
      heading: camera.heading + 10,
    });
  }

  async function animateCamera() {
    const camera = await map.current.getCamera();
    camera.heading += 40;
    camera.pitch += 10;
    camera.altitude += 1000;
    camera.zoom -= 1;
    camera.center.latitude += 0.5;
    map.current.animateCamera(camera, { duration: 2000 });
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        ref={(ref) => {
          map.current = ref;
        }}
        style={styles.map}
        initialCamera={{
          center: {
            latitude: LATITUDE,
            longitude: LONGITUDE,
          },
          pitch: 45,
          heading: 90,
          altitude: 1000,
          zoom: 10,
        }}
      />
      <DemoControls>
        <DemoButtonRow>
          <DemoButton label="获取当前相机" onPress={getCamera} />
          <DemoButton
            label="设置相机"
            variant="secondary"
            onPress={setCamera}
          />
          <DemoButton
            label="相机动画"
            variant="secondary"
            onPress={animateCamera}
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

export default CameraControl;
