import { useState } from 'react';
import { StyleSheet, View, Text, Dimensions, ScrollView } from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;

function StaticMap(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });

  return (
    <View style={styles.container}>
      <ScrollView
        style={StyleSheet.absoluteFill}
        contentContainerStyle={styles.scrollview}
      >
        <Text>点击</Text>
        <Text>并</Text>
        <Text>拖动</Text>
        <Text>这个</Text>
        <Text>地图，</Text>
        <Text>将</Text>
        <Text>使</Text>
        <Text>其</Text>
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
        <Text>父级</Text>
        <Text>ScrollView</Text>
        <Text>发生</Text>
        <Text>滚动。</Text>
        <Text>使用</Text>
        <Text>Google</Text>
        <Text>地图</Text>
        <Text>时，</Text>
        <Text>只有</Text>
        <Text>禁用</Text>
        <Text>滚动、</Text>
        <Text>缩放、</Text>
        <Text>俯仰、</Text>
        <Text>旋转</Text>
        <Text>才会</Text>
        <Text>生效。</Text>
        <Text>……</Text>
        <Text>要是</Text>
        <Text>能</Text>
        <Text>有</Text>
        <Text>一个</Text>
        <Text>仍</Text>
        <Text>允许</Text>
        <Text>缩放</Text>
        <Text>的</Text>
        <Text>选项</Text>
        <Text>就</Text>
        <Text>好</Text>
        <Text>了。</Text>
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
    paddingVertical: 40,
  },
  map: {
    width: 250,
    height: 250,
  },
});

export default StaticMap;
