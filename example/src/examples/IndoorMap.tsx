import { useRef } from 'react';
import { StyleSheet, View, Dimensions, Alert } from 'react-native';
import MapView from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

const { width, height } = Dimensions.get('window');
const ASPECT_RATIO = width / height;
const LATITUDE = 31.23545;
const LONGITUDE = 121.42222;
const LATITUDE_DELTA = 0.003;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

export default function IndoorMap(props: any) {
  const map = useRef<any>(null);

  function handleIndoorFocus(event: any) {
    const { activeLevelIndex, levels } = event.nativeEvent;
    const levelNames = levels.map((lv: any) => lv.name || '');
    const msg = `默认楼层：${
      levels[activeLevelIndex].name
    }\n全部楼层：${levelNames.toString()}`;
    Alert.alert('已聚焦室内建筑', msg);
  }

  function setIndoorLevel(level: any) {
    map.current.setIndoorActiveLevelIndex(level);
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
        showsIndoors
        showsIndoorLevelPicker
        onIndoorBuildingFocused={handleIndoorFocus}
        ref={(m) => {
          map.current = m;
        }}
      />
      <DemoControls>
        <DemoButtonRow>
          <DemoButton
            label="前往第 5 层"
            onPress={() => {
              setIndoorLevel(5);
            }}
          />
          <DemoButton
            label="前往第 1 层"
            variant="secondary"
            onPress={() => {
              setIndoorLevel(1);
            }}
          />
        </DemoButtonRow>
      </DemoControls>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
    justifyContent: 'flex-end',
    alignItems: 'center',
  },
  map: {
    ...StyleSheet.absoluteFill,
  },
});
