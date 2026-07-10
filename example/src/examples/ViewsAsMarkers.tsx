import { useState } from 'react';
import { Dimensions, StyleSheet, View } from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';
import PriceMarker from './PriceMarker';
import { DemoButton, DemoButtonRow, DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function ViewsAsMarkers(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [coordinate] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
  });
  const [amount, setAmount] = useState(99);

  function increment() {
    setAmount((prev) => prev + 1);
  }

  function decrement() {
    setAmount((prev) => prev - 1);
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
      >
        <Marker coordinate={coordinate}>
          <PriceMarker amount={amount} />
        </Marker>
      </MapView>

      <DemoControls>
        <DemoHint>点击 +/- 按钮调整标注上的价格</DemoHint>
        <DemoButtonRow>
          <DemoButton label="-" variant="secondary" onPress={decrement} />
          <DemoButton label="+" onPress={increment} />
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

export default ViewsAsMarkers;
