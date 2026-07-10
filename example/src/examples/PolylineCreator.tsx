import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { Polyline } from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
let id = 0;

function PolylineCreator(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [polylines, setPolylines] = useState<any[]>([]);
  const [editing, setEditing] = useState<any>(null);

  const finish = () => {
    setPolylines((prev) => [...prev, editing]);
    setEditing(null);
  };

  const onPanDrag = (e: any) => {
    console.log('拖动绘制 onPanDrag', e.nativeEvent);
    if (!editing) {
      setEditing({
        id: id++,
        coordinates: [e.nativeEvent.coordinate],
      });
    } else {
      setEditing({
        ...editing,
        coordinates: [...editing.coordinates, e.nativeEvent.coordinate],
      });
    }
  };

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        scrollEnabled={false}
        onPanDrag={(e) => onPanDrag(e)}
      >
        {polylines.map((polyline: any) => (
          <Polyline
            key={polyline.id}
            coordinates={polyline.coordinates}
            strokeColor="#000"
            strokeWidth={1}
          />
        ))}
        {editing && (
          <Polyline
            key="editingPolyline"
            coordinates={editing.coordinates}
            strokeColor="#F00"
            strokeWidth={1}
          />
        )}
      </MapView>
      {editing && (
        <DemoControls>
          <DemoButtonRow>
            <DemoButton label="完成" onPress={() => finish()} />
          </DemoButtonRow>
        </DemoControls>
      )}
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

export default PolylineCreator;
