import { useState } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';

import MapView, { MAP_TYPES, Polygon } from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoControls } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
let id = 0;

function PolygonCreator(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [polygons, setPolygons] = useState<any[]>([]);
  const [editing, setEditing] = useState<any>(null);
  const [creatingHole, setCreatingHole] = useState(false);

  const finish = () => {
    setPolygons((prev) => [...prev, editing]);
    setEditing(null);
    setCreatingHole(false);
  };

  const createHole = () => {
    if (!creatingHole) {
      setCreatingHole(true);
      setEditing({
        ...editing,
        holes: [...editing.holes, []],
      });
    } else {
      const holes = [...editing.holes];
      if (holes[holes.length - 1].length === 0) {
        holes.pop();
        setEditing({
          ...editing,
          holes,
        });
      }
      setCreatingHole(false);
    }
  };

  const onPress = (e: any) => {
    if (!editing) {
      setEditing({
        id: id++,
        coordinates: [e.nativeEvent.coordinate],
        holes: [],
      });
    } else if (!creatingHole) {
      setEditing({
        ...editing,
        coordinates: [...editing.coordinates, e.nativeEvent.coordinate],
      });
    } else {
      const holes = [...editing.holes];
      holes[holes.length - 1] = [
        ...holes[holes.length - 1],
        e.nativeEvent.coordinate,
      ];
      setEditing({
        ...editing,
        id: id++, // 持续递增 id 以触发显示刷新
        coordinates: [...editing.coordinates],
        holes,
      });
    }
  };

  const mapOptions: any = {
    scrollEnabled: true,
  };

  if (editing) {
    mapOptions.scrollEnabled = false;
    mapOptions.onPanDrag = (e: any) => onPress(e);
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        mapType={MAP_TYPES.HYBRID}
        initialRegion={region}
        onPress={(e) => onPress(e)}
        {...mapOptions}
      >
        {polygons.map((polygon: any) => (
          <Polygon
            key={polygon.id}
            coordinates={polygon.coordinates}
            holes={polygon.holes}
            strokeColor="#F00"
            fillColor="rgba(255,0,0,0.5)"
            strokeWidth={1}
          />
        ))}
        {editing && (
          <Polygon
            key={editing.id}
            coordinates={editing.coordinates}
            holes={editing.holes}
            strokeColor="#000"
            fillColor="rgba(255,0,0,0.5)"
            strokeWidth={1}
          />
        )}
      </MapView>
      {editing && (
        <DemoControls>
          <DemoButtonRow>
            <DemoButton
              label={creatingHole ? '完成孔洞' : '创建孔洞'}
              variant="secondary"
              onPress={() => createHole()}
            />
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

export default PolygonCreator;
