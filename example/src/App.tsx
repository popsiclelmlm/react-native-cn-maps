import { View, StyleSheet } from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';

export default function App() {
  return (
    <View style={styles.container}>
      <MapView
        provider="amap"
        coordinateSystem="gcj02"
        initialRegion={{
          latitude: 31.2304,
          longitude: 121.4737,
          latitudeDelta: 0.05,
          longitudeDelta: 0.05,
        }}
        style={styles.map}
      >
        <Marker
          coordinate={{ latitude: 31.2304, longitude: 121.4737 }}
          title="Shanghai"
          description="AMap marker"
        />
      </MapView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  map: {
    alignSelf: 'stretch',
    flex: 1,
  },
});
