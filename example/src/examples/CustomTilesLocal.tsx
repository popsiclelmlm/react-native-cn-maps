import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';
import MapView, {
  MAP_TYPES,
  PROVIDER_DEFAULT,
  LocalTile,
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
        <LocalTile
          pathTemplate="/path/to/locally/saved/tiles/{z}/{x}/{y}.png"
          tileSize={256}
          zIndex={-1}
        />
      </MapView>

      <DemoControls>
        <DemoHint>本地瓦片图层</DemoHint>
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
