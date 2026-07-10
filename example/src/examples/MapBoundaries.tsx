import { useRef, useState } from 'react';
import { StyleSheet, View, Text, Dimensions } from 'react-native';

import MapView from 'react-native-cn-maps';
import type { BoundingBox, MapViewHandle } from 'react-native-cn-maps';
import { DEMO, DemoControls, DemoPanel } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

const MapBoundaries = (props: any) => {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });

  const [mapBoundaries, setMapBoundaries] = useState<BoundingBox | null>(null);
  const mapRef = useRef<MapViewHandle>(null);

  const onRegionChangeComplete = () => {
    if (mapRef.current) {
      mapRef.current.getMapBoundaries?.().then((boundaries) => {
        setMapBoundaries(boundaries);
      });
    }
  };

  return (
    <View style={styles.container}>
      <MapView
        ref={mapRef}
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        onMapReady={onRegionChangeComplete}
        onRegionChangeComplete={onRegionChangeComplete}
      />
      <DemoControls>
        <DemoPanel>
          <Text style={styles.boundaryLabel}>当前地图边界</Text>
          <Text style={styles.boundaryValue}>
            {JSON.stringify(mapBoundaries)}
          </Text>
        </DemoPanel>
      </DemoControls>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
  },
  map: {
    ...StyleSheet.absoluteFill,
  },
  boundaryLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: DEMO.text,
    marginBottom: 4,
  },
  boundaryValue: {
    fontSize: 12,
    color: DEMO.textMuted,
  },
});

export default MapBoundaries;
