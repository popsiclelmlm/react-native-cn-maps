import { useState } from 'react';
import { StyleSheet, View, Text, Dimensions, ScrollView } from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function ThemeMap(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollview}>
        <Text>系统</Text>
        <MapView
          provider={props.provider}
          style={styles.map}
          scrollEnabled={false}
          zoomEnabled={false}
          pitchEnabled={false}
          rotateEnabled={false}
          initialRegion={region}
        >
          <Marker title="这是标题" description="这是描述" coordinate={region} />
        </MapView>

        <Text>{'\n'}浅色</Text>
        <MapView
          provider={props.provider}
          style={styles.map}
          scrollEnabled={false}
          zoomEnabled={false}
          pitchEnabled={false}
          rotateEnabled={false}
          initialRegion={region}
          userInterfaceStyle="light"
        >
          <Marker title="这是标题" description="这是描述" coordinate={region} />
        </MapView>
        <Text>{'\n'}深色</Text>
        <MapView
          provider={props.provider}
          style={styles.map}
          scrollEnabled={false}
          zoomEnabled={false}
          pitchEnabled={false}
          rotateEnabled={false}
          initialRegion={region}
          userInterfaceStyle="dark"
        >
          <Marker title="这是标题" description="这是描述" coordinate={region} />
        </MapView>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
    justifyContent: 'flex-end',
    alignItems: 'center',
  },
  scrollview: {
    alignItems: 'center',
    paddingVertical: 70,
  },
  map: {
    width: 200,
    height: 200,
  },
});

export default ThemeMap;
