import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function log(eventName: any, e: any) {
  // 保留英文事件名（对应原生 API 事件），前面加中文标签便于识别
  console.log('标注事件', eventName, e.nativeEvent);
}

function TestIdMarkers(props: any) {
  // a 初始化后不再变化，只解构值、不需要 setter
  const [a] = useState({
    latitude: LATITUDE + SPACE,
    longitude: LONGITUDE + SPACE,
  });

  return (
    <View style={styles.container} accessible>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={{
          latitude: LATITUDE,
          longitude: LONGITUDE,
          latitudeDelta: LATITUDE_DELTA,
          longitudeDelta: LONGITUDE_DELTA,
        }}
      >
        <Marker
          testID="marker"
          coordinate={a}
          onSelect={(e) => log('onSelect', e)}
          onDrag={(e) => log('onDrag', e)}
          onDragStart={(e) => log('onDragStart', e)}
          onDragEnd={(e) => log('onDragEnd', e)}
          onPress={(e) => log('onPress', e)}
          draggable
        />
      </MapView>
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

export default TestIdMarkers;
