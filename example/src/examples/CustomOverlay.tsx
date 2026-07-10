import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView from 'react-native-cn-maps';
import XMarksTheSpot from './CustomOverlayXMarksTheSpot';

const { width, height } = Dimensions.get('window');
const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function CustomOverlay(props: any) {
  // state 在原 class 里仅在 constructor 里初始化、之后从不更新，故用 useState 只取初值
  const [state] = useState<any>({
    region: {
      latitude: LATITUDE,
      longitude: LONGITUDE,
      latitudeDelta: LATITUDE_DELTA,
      longitudeDelta: LONGITUDE_DELTA,
    },
    coordinates: [
      {
        longitude: 121.463347,
        latitude: 31.24094,
      },
      {
        longitude: 121.481372,
        latitude: 31.243382,
      },
      {
        longitude: 121.483603,
        latitude: 31.232801,
      },
      {
        longitude: 121.465407,
        latitude: 31.230359,
      },
    ],
    center: {
      longitude: 121.4734351064324,
      latitude: 31.23633561114521,
    },
  });

  const { coordinates, center, region } = state;
  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <XMarksTheSpot coordinates={coordinates} center={center} />
      </MapView>
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

export default CustomOverlay;
