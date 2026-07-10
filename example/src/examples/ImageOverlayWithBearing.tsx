import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Overlay } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.01;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
// 高德瓦片 109763, 53556, 17（上海人民广场）
const OVERLAY_NORTH_EAST_COORDINATE = [31.231591672, 121.475830078];
const OVERLAY_SOUTH_WEST_COORDINATE = [31.2292431, 121.473083496];
const IMAGE_URL1 =
  'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x=109763&y=53556&z=17';
// 高德瓦片 109763, 53558, 17
const OVERLAY2_SOUTH_WEST_COORDINATE = [31.22454578, 121.473083496];
const OVERLAY2_NORTH_EAST_COORDINATE = [31.226894469, 121.475830078];
const IMAGE_URL2 =
  'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x=109763&y=53558&z=17';

function ImageOverlayWithBearing(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [overlay1] = useState<any>({
    bounds: [OVERLAY_NORTH_EAST_COORDINATE, OVERLAY_SOUTH_WEST_COORDINATE],
    image: IMAGE_URL1,
  });
  const [overlay2] = useState<any>({
    bounds: [OVERLAY2_NORTH_EAST_COORDINATE, OVERLAY2_SOUTH_WEST_COORDINATE],
    image: IMAGE_URL2,
  });

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <Overlay bounds={overlay1.bounds} bearing={30} image={overlay1.image} />
        <Overlay
          bounds={overlay2.bounds}
          bearing={-30}
          image={overlay2.image}
        />
      </MapView>
    </View>
  );
}

export default ImageOverlayWithBearing;

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
  },
  map: {
    ...StyleSheet.absoluteFill,
  },
});
