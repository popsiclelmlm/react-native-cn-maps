import { useState, useRef } from 'react';

import { View, StyleSheet } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import { DemoButton } from './_ui';
// @ts-ignore
import carImage from './assets/car.png';

export default function NavigationMap() {
  const map = useRef<any>(null);
  const [prevPos, setPrevPos] = useState<any>(null);
  const [curPos, setCurPos] = useState<any>({
    latitude: 31.2304,
    longitude: 121.4737,
  });
  const [curAng] = useState(45);
  const [latitudeDelta] = useState(0.0922);
  const [longitudeDelta] = useState(0.0421);

  function getRotation(prev: any, cur: any) {
    if (!prev) {
      return 0;
    }
    const xDiff = cur.latitude - prev.latitude;
    const yDiff = cur.longitude - prev.longitude;
    return (Math.atan2(yDiff, xDiff) * 180.0) / Math.PI;
  }

  function updateMap() {
    const curRot = getRotation(prevPos, curPos);
    map.current.animateCamera({
      heading: curRot,
      center: curPos,
      pitch: curAng,
    });
  }

  function changePosition(latOffset: number, lonOffset: number) {
    const latitude = curPos.latitude + latOffset;
    const longitude = curPos.longitude + lonOffset;
    setPrevPos(curPos);
    setCurPos({ latitude, longitude });
    updateMap();
  }

  return (
    <View style={styles.flex}>
      <MapView
        ref={(ref) => {
          map.current = ref;
        }}
        style={styles.flex}
        minZoomLevel={15}
        initialRegion={{
          ...curPos,
          latitudeDelta,
          longitudeDelta,
        }}
      >
        <Marker
          coordinate={curPos}
          anchor={{ x: 0.5, y: 0.5 }}
          image={carImage}
        />
      </MapView>
      {/* 上下方向：增减纬度 */}
      <View style={styles.buttonContainerUpDown}>
        <DemoButton
          label="+ 纬度"
          variant="secondary"
          style={[styles.pad, styles.up]}
          onPress={() => changePosition(0.0001, 0)}
        />
        <DemoButton
          label="- 纬度"
          variant="secondary"
          style={[styles.pad, styles.down]}
          onPress={() => changePosition(-0.0001, 0)}
        />
      </View>
      {/* 左右方向：增减经度 */}
      <View style={styles.buttonContainerLeftRight}>
        <DemoButton
          label="- 经度"
          variant="secondary"
          style={[styles.pad, styles.left]}
          onPress={() => changePosition(0, -0.0001)}
        />
        <DemoButton
          label="+ 经度"
          variant="secondary"
          style={[styles.pad, styles.right]}
          onPress={() => changePosition(0, 0.0001)}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: {
    flex: 1,
    width: '100%',
  },
  buttonContainerUpDown: {
    ...StyleSheet.absoluteFill,
    flexDirection: 'row',
    justifyContent: 'center',
  },
  buttonContainerLeftRight: {
    ...StyleSheet.absoluteFill,
    flexDirection: 'column',
    justifyContent: 'center',
  },
  pad: {
    position: 'absolute',
  },
  up: {
    alignSelf: 'flex-start',
  },
  down: {
    alignSelf: 'flex-end',
  },
  left: {
    alignSelf: 'flex-start',
  },
  right: {
    alignSelf: 'flex-end',
  },
});
