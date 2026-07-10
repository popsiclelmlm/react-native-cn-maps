import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Overlay } from 'react-native-cn-maps';
import flagPinkImg from './assets/flag-pink.png';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.01;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
// 覆盖范围：上海人民广场附近一小块区域（西南 / 东北两角坐标）
const OVERLAY_SOUTH_WEST_COORDINATE = [31.2292431, 121.473083496];
const OVERLAY_NORTH_EAST_COORDINATE = [31.231591672, 121.475830078];
const IMAGE = flagPinkImg;

function ImageOverlayWithAssets(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [overlay] = useState<any>({
    bounds: [OVERLAY_NORTH_EAST_COORDINATE, OVERLAY_SOUTH_WEST_COORDINATE],
    image: IMAGE,
  });

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <Overlay bounds={overlay.bounds} image={overlay.image} />
      </MapView>
    </View>
  );
}

export default ImageOverlayWithAssets;

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
  },
  map: {
    ...StyleSheet.absoluteFill,
  },
});
