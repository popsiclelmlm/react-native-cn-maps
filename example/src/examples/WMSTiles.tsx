import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { MAP_TYPES, WMSTile } from 'react-native-cn-maps';
import { DemoButton, DemoControls } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.152;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function WMSTiles(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [isWMSTilesActive, setIsWMSTilesActive] = useState(false);

  // 依赖旧值，使用函数式更新
  const toggleWMSTiles = () => {
    setIsWMSTilesActive((prev) => !prev);
  };

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        mapType={MAP_TYPES.SATELLITE}
        style={styles.map}
        initialRegion={region}
      >
        {isWMSTilesActive && (
          <WMSTile
            urlTemplate="https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi?service=WMS&version=1.1.1&request=GetMap&layers=MODIS_Terra_CorrectedReflectance_TrueColor&format=image/png&transparent=true&styles=&bbox={minX},{minY},{maxX},{maxY}&width={width}&height={height}&srs=EPSG:3857"
            zIndex={1}
            opacity={0.5}
            tileSize={512}
          />
        )}
      </MapView>

      <DemoControls>
        <DemoButton
          label={`WMS 瓦片：${isWMSTilesActive ? '开' : '关'}（点击切换）`}
          onPress={toggleWMSTiles}
        />
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

export default WMSTiles;
