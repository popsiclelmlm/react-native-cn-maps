import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';
import MapView from 'react-native-cn-maps';
import MyLocationMapMarker from './MyLocationMapMarker';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function BugMarkerWontUpdate(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  // amount 仅由按钮更新、渲染中未读取（对应下方注释掉的 heading），故只保留 setter
  const [, setAmount] = useState(0);
  const [enableHack, setEnableHack] = useState(false);

  function increment() {
    setAmount((prev) => prev + 10);
  }

  function decrement() {
    setAmount((prev) => prev - 10);
  }

  function toggleHack() {
    setEnableHack((prev) => !prev);
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <MyLocationMapMarker
        // coordinate={coordinate}
        // heading={amount}
        // enableHack={enableHack}
        />
      </MapView>
      <DemoControls>
        <DemoButton
          label={enableHack ? '关闭 Hack' : '启用 Hack'}
          onPress={() => toggleHack()}
        />
        <DemoButtonRow>
          <DemoButton
            label="-"
            variant="secondary"
            onPress={() => decrement()}
          />
          <DemoButton
            label="+"
            variant="secondary"
            onPress={() => increment()}
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

export default BugMarkerWontUpdate;
