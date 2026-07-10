import { useState } from 'react';
import { Text, View, Dimensions, StyleSheet } from 'react-native';

import MapView, { Marker, Callout } from 'react-native-cn-maps';
import flagImg from './assets/flag-blue.png';
import { DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function LoadingMap(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        loadingEnabled
        loadingIndicatorColor="#666666"
        loadingBackgroundColor="#eeeeee"
      >
        <Marker
          coordinate={{
            latitude: LATITUDE + SPACE,
            longitude: LONGITUDE + SPACE,
          }}
          centerOffset={{ x: -18, y: -60 }}
          anchor={{ x: 0.69, y: 1 }}
          image={flagImg}
        />
        <Marker
          coordinate={{
            latitude: LATITUDE - SPACE,
            longitude: LONGITUDE - SPACE,
          }}
          centerOffset={{ x: -42, y: -60 }}
          anchor={{ x: 0.84, y: 1 }}
        >
          <Callout>
            <View>
              <Text>这是一个普通视图</Text>
            </View>
          </Callout>
        </Marker>
      </MapView>
      <DemoControls>
        <DemoHint>带加载动画的地图</DemoHint>
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

export default LoadingMap;
