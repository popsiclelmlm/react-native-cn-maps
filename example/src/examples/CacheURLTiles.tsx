import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, {
  MAP_TYPES,
  PROVIDER_DEFAULT,
  UrlTile,
} from 'react-native-cn-maps';
import { DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function CustomTiles(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });

  // MapKit 不支持将 'none' 作为底图
  const mapType =
    props.provider === PROVIDER_DEFAULT ? MAP_TYPES.STANDARD : MAP_TYPES.NONE;

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        mapType={mapType}
        style={styles.map}
        initialRegion={region}
      >
        <UrlTile
          urlTemplate="https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}"
          zIndex={-1}
          // 测试步骤：
          // 1) 不启用新的瓦片属性：注释掉 tileCachePath 与 maximumNativeZ
          // 2) 仅启用 maximumNativeZ，测试超过最大原生缩放层级后的拉伸缩放
          // 3) 加上 doubleTileSize（仅 Android）
          // 4) 再加上 tileCachePath —— 在切断 / 限速网络下测试缓存性能
          // 5) 再加上 tileCacheMaxAge
          // 6) 再加上 offlineMode=true —— 放大以测试低缩放层级瓦片拉伸到高缩放层级
          //
          maximumNativeZ={15}
          // 测试时可切换不同的瓦片缓存路径，下面的示例适用于模拟器 / 仿真器
          // iOS 模拟器路径，fileURL 与目录两种写法需分别测试
          tileCachePath="file:///Users/suomimar/Library/Developer/CoreSimulator/tiles/"
          //tileCachePath="/Users/suomimar/Library/Developer/CoreSimulator/tiles"
          // Android 模拟器路径，fileURL 与目录两种写法需分别测试
          //tileCachePath="file:///data/user/0/com.airbnb.android.react.maps.example/files/tiles"
          //tileCachePath="/data/user/0/com.airbnb.android.react.maps.example/files/tiles"
          tileCacheMaxAge={20}
          doubleTileSize={true}
          opacity={1.0}
          //offlineMode={true}
        />
      </MapView>

      <DemoControls>
        <DemoHint>缓存 URL 瓦片图层</DemoHint>
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

export default CustomTiles;
