import { useState, useEffect, useRef } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

const markerIDs = ['Marker1', 'Marker2', 'Marker3', 'Marker4', 'Marker5'];
const timeout = 4000;
let animationTimeout: any;

function FitToSuppliedMarkers(props: any) {
  const map = useRef<any>(null);
  const [a] = useState<any>({
    latitude: LATITUDE + SPACE,
    longitude: LONGITUDE + SPACE,
  });
  const [b] = useState<any>({
    latitude: LATITUDE - SPACE,
    longitude: LONGITUDE - SPACE,
  });
  const [c] = useState<any>({
    latitude: LATITUDE - SPACE * 2,
    longitude: LONGITUDE - SPACE * 2,
  });
  const [d] = useState<any>({
    latitude: LATITUDE - SPACE * 3,
    longitude: LONGITUDE - SPACE * 3,
  });
  const [e] = useState<any>({
    latitude: LATITUDE - SPACE * 4,
    longitude: LONGITUDE - SPACE * 4,
  });

  function focusMap(markers: any, animated: any) {
    console.log(`用于适配地图的标注：${markers}`);
    map.current.fitToSuppliedMarkers(markers, animated);
  }

  function focus1() {
    animationTimeout = setTimeout(() => {
      focusMap([markerIDs[1], markerIDs[4]], true);

      focus2();
    }, timeout);
  }

  function focus2() {
    animationTimeout = setTimeout(() => {
      focusMap([markerIDs[2], markerIDs[3]], false);

      focus3();
    }, timeout);
  }

  function focus3() {
    animationTimeout = setTimeout(() => {
      focusMap([markerIDs[1], markerIDs[2]], false);

      focus4();
    }, timeout);
  }

  function focus4() {
    animationTimeout = setTimeout(() => {
      focusMap([markerIDs[0], markerIDs[3]], true);

      focus1();
    }, timeout);
  }

  // 挂载后启动动画计时；卸载时清理，等价于原 componentDidMount / componentWillUnmount
  useEffect(() => {
    animationTimeout = setTimeout(() => {
      focus1();
    }, timeout);
    return () => {
      if (animationTimeout) {
        clearTimeout(animationTimeout);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        ref={(ref) => {
          map.current = ref;
        }}
        style={styles.map}
        initialRegion={{
          latitude: LATITUDE,
          longitude: LONGITUDE,
          latitudeDelta: LATITUDE_DELTA,
          longitudeDelta: LONGITUDE_DELTA,
        }}
      >
        <Marker identifier="Marker1" coordinate={a} />
        <Marker identifier="Marker2" coordinate={b} />
        <Marker identifier="Marker3" coordinate={c} />
        <Marker identifier="Marker4" coordinate={d} />
        <Marker identifier="Marker5" coordinate={e} />
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

export default FitToSuppliedMarkers;
