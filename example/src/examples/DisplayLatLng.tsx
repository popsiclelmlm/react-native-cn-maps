import { useState, useRef } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { MAP_TYPES } from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function DisplayLatLng(props: any) {
  const map = useRef<any>(null);
  const [region, setRegion] = useState<any>({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });

  function onRegionChange(next: any) {
    setRegion(next);
  }

  function jumpRandom() {
    map.current.setRegion(randomRegion());
  }

  function animateRandom() {
    map.current.animateToRegion(randomRegion());
  }

  function animateRandomCoordinate() {
    map.current.animateCamera({ center: randomCoordinate() });
  }

  function animateToRandomBearing() {
    map.current.animateCamera({ heading: getRandomFloat(-360, 360) });
  }

  function animateToRandomViewingAngle() {
    map.current.animateCamera({ pitch: getRandomFloat(0, 90) });
  }

  function getRandomFloat(min: any, max: any) {
    return Math.random() * (max - min) + min;
  }

  function randomCoordinate() {
    const scaleFactor = Math.random() * 10;
    return {
      latitude:
        region.latitude +
        (Math.random() - 0.5) * (region.latitudeDelta * scaleFactor),
      longitude:
        region.longitude +
        (Math.random() - 0.5) * (region.longitudeDelta * scaleFactor),
    };
  }

  function randomRegion() {
    return {
      ...region,
      ...randomCoordinate(),
    };
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        rotateEnabled={false}
        ref={(ref) => {
          map.current = ref;
        }}
        mapType={MAP_TYPES.TERRAIN}
        style={styles.map}
        initialRegion={region}
        onRegionChange={onRegionChange}
      />
      <DemoControls>
        <DemoHint>
          {`纬度 ${region.latitude.toPrecision(7)}，经度 ${region.longitude.toPrecision(7)}`}
        </DemoHint>
        <DemoButtonRow>
          <DemoButton label="跳转" onPress={jumpRandom} />
          <DemoButton
            label="平滑移动（区域）"
            variant="secondary"
            onPress={animateRandom}
          />
          <DemoButton
            label="平滑移动（坐标）"
            variant="secondary"
            onPress={animateRandomCoordinate}
          />
        </DemoButtonRow>
        <DemoButtonRow>
          <DemoButton
            label="平滑移动（朝向）"
            variant="secondary"
            onPress={animateToRandomBearing}
          />
          <DemoButton
            label="平滑移动（俯仰角）"
            variant="secondary"
            onPress={animateToRandomViewingAngle}
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

export default DisplayLatLng;
