import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { MAP_TYPES, WMSTile } from 'react-native-cn-maps';
import { DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.152;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function CacheWMSTiles(props: any) {
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
        mapType={MAP_TYPES.SATELLITE}
        style={styles.map}
        initialRegion={region}
      >
        <WMSTile
          urlTemplate="https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?service=WMS&version=1.1.1&request=GetMap&layers=MODIS_Terra_CorrectedReflectance_TrueColor&format=image/png&transparent=true&styles=&bbox={minX},{minY},{maxX},{maxY}&width={width}&height={height}&srs=EPSG:3857"
          zIndex={2}
          tileSize={256}
          // 测试步骤：
          // 1) 不启用新的瓦片属性：注释掉 tileCachePath 与 maximumNativeZ
          // 2) 仅启用 maximumNativeZ，测试超过最大原生缩放层级后的拉伸缩放
          // 3) 再加上 tileCachePath —— 在切断 / 限速网络下测试缓存性能
          // 4) 再加上 tileCacheMaxAge
          // 5) 再加上 offlineMode=true —— 放大以测试低缩放层级瓦片拉伸到高缩放层级
          //
          maximumNativeZ={12}
          // tileCachePath 需要一个可写目录（各平台沙盒路径不同），示例默认不设置。
          // 实测磁盘缓存时，用 react-native-fs / expo-file-system 取得
          // documentDirectory 后再传入，例如 tileCachePath={`${docDir}/wms_tiles`}。
          tileCacheMaxAge={20}
          opacity={1.0}
          //offlineMode={true}
        />
      </MapView>

      <DemoControls>
        <DemoHint>缓存 WMS 瓦片图层</DemoHint>
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

export default CacheWMSTiles;
