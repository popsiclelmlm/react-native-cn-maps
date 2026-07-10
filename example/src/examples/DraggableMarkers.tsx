import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import PriceMarker from './PriceMarker';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

// 统一打印事件日志：中文说明 + 原生事件名，便于与 API 对照
function log(eventName: any, e: any) {
  console.log(eventName, e.nativeEvent);
}

function MarkerTypes(props: any) {
  const [a] = useState({
    latitude: LATITUDE + SPACE,
    longitude: LONGITUDE + SPACE,
  });
  const [b] = useState({
    latitude: LATITUDE - SPACE,
    longitude: LONGITUDE - SPACE,
  });

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
      >
        <Marker
          coordinate={a}
          onSelect={(e) => log('选中 onSelect', e)}
          onDrag={(e) => log('拖拽中 onDrag', e)}
          onDragStart={(e) => log('拖拽开始 onDragStart', e)}
          onDragEnd={(e) => log('拖拽结束 onDragEnd', e)}
          onPress={(e) => log('点击 onPress', e)}
          draggable
        >
          <PriceMarker amount={99} />
        </Marker>
        <Marker
          coordinate={b}
          onSelect={(e) => log('选中 onSelect', e)}
          onDrag={(e) => log('拖拽中 onDrag', e)}
          onDragStart={(e) => log('拖拽开始 onDragStart', e)}
          onDragEnd={(e) => log('拖拽结束 onDragEnd', e)}
          onPress={(e) => log('点击 onPress', e)}
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

export default MarkerTypes;
