import { useRef } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function createMarker(modifier = 1) {
  return {
    latitude: LATITUDE - SPACE * modifier,
    longitude: LONGITUDE - SPACE * modifier,
  };
}

const MARKERS = [
  createMarker(),
  createMarker(2),
  createMarker(3),
  createMarker(4),
];

const DEFAULT_PADDING = { top: 40, right: 40, bottom: 40, left: 40 };

function FitToCoordinates(props: any) {
  const map = useRef<any>(null);

  async function logFrames() {
    const visMarkersFrames = await map.current.getMarkersFrames(true);
    console.log('可见标注位置信息', visMarkersFrames);
    const allMarkersFrames = await map.current.getMarkersFrames();
    console.log('全部标注位置信息', allMarkersFrames);
  }

  function fitPadding() {
    map.current.fitToCoordinates([MARKERS[2], MARKERS[3]], {
      edgePadding: { top: 100, right: 100, bottom: 100, left: 100 },
      animated: true,
    });
  }

  function fitBottomTwoMarkers() {
    map.current.fitToCoordinates([MARKERS[2], MARKERS[3]], {
      edgePadding: DEFAULT_PADDING,
      animated: true,
    });
  }

  function fitAllMarkers() {
    map.current.fitToCoordinates(MARKERS, {
      edgePadding: DEFAULT_PADDING,
      animated: true,
    });
  }

  return (
    <View style={styles.container}>
      <MapView
        ref={(ref) => {
          map.current = ref;
        }}
        provider={props.provider}
        style={styles.map}
        initialRegion={{
          latitude: LATITUDE,
          longitude: LONGITUDE,
          latitudeDelta: LATITUDE_DELTA,
          longitudeDelta: LONGITUDE_DELTA,
        }}
      >
        {MARKERS.map((marker, i) => (
          <Marker key={i} identifier={`id${i}`} coordinate={marker} />
        ))}
      </MapView>
      <DemoControls>
        <DemoButtonRow>
          <DemoButton
            label="适配底部两个标注（含内边距）"
            onPress={fitPadding}
          />
          <DemoButton
            label="适配底部两个标注"
            variant="secondary"
            onPress={fitBottomTwoMarkers}
          />
          <DemoButton
            label="适配全部标注"
            variant="secondary"
            onPress={fitAllMarkers}
          />
          <DemoButton
            label="打印标注位置信息"
            variant="secondary"
            onPress={logFrames}
          />
        </DemoButtonRow>
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

export default FitToCoordinates;
