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
        <Text style={styles.paragraph}>
          这是一个「静态地图」示例：地图禁用了滚动、缩放、俯仰和旋转，
          因此它不会拦截手势。用手指按住地图上下拖动，滚动的会是外层的
          ScrollView，而不是地图本身。
        </Text>
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
        <Text style={styles.paragraph}>
          把地图当作页面里的一张普通图片来嵌入，就是这个示例要演示的效果。
          上下的这两段文字只是用来撑高内容、方便看到滚动，没有其他作用。
        </Text>
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
        <Text style={styles.paragraph}>
          把地图当作页面里的一张普通图片来嵌入，就是这个示例要演示的效果。
          上下的这两段文字只是用来撑高内容、方便看到滚动，没有其他作用。
        </Text>
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
    paddingVertical: 120,
  },
  paragraph: {
    paddingHorizontal: 24,
    paddingVertical: 24,
    fontSize: 15,
    lineHeight: 22,
    color: '#333',
  },
  map: {
    width: 250,
    height: 250,
  },
});

export default StaticMap;
