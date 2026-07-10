import { useState } from 'react';
import { StyleSheet, View, Text, Dimensions } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import { DemoControls, DemoHint, DemoPanel, DEMO } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function OnPoiClick(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [poi, setPoi] = useState<any>(null);

  const onPoiClick = (e: any) => {
    const next = e.nativeEvent;

    setPoi(next);
  };

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        onPoiClick={onPoiClick}
      >
        {poi && <Marker coordinate={poi.coordinate} />}
      </MapView>

      <DemoControls>
        <DemoHint>点击地图上的 POI（兴趣点）查看信息</DemoHint>
        {poi && (
          <DemoPanel>
            <Text style={styles.panelText}>地点 ID：{poi.placeId}</Text>
            <Text style={styles.panelText}>名称：{poi.name}</Text>
          </DemoPanel>
        )}
      </DemoControls>
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
  panelText: {
    fontSize: 13,
    color: DEMO.text,
  },
});

export default OnPoiClick;
