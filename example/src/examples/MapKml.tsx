import { useState, useRef } from 'react';
import { StyleSheet, View, Dimensions } from 'react-native';
import MapView, { Marker } from 'react-native-cn-maps';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
// 内联 KML 数据（上海地标：Point / LineString / Polygon 各一个）。
// kmlSrc 同样支持 http(s) URL；官方示例的 pastebin 源在国内无法访问，
// 这里改用内联字符串，离线也能演示。
const KML_FILE = `<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>东方明珠</name>
      <description>Oriental Pearl Tower</description>
      <Point>
        <coordinates>121.4998,31.2397,0</coordinates>
      </Point>
    </Placemark>
    <Placemark>
      <name>外滩滨江线</name>
      <LineString>
        <coordinates>
          121.4906,31.2419,0 121.4954,31.2385,0
          121.4990,31.2340,0 121.5010,31.2290,0
        </coordinates>
      </LineString>
    </Placemark>
    <Placemark>
      <name>人民广场</name>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              121.4690,31.2330,0 121.4780,31.2330,0 121.4780,31.2270,0
              121.4690,31.2270,0 121.4690,31.2330,0
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>`;

export default function MapKml(props: any) {
  const map = useRef<any>(null);
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });

  const onKmlReady = () => {
    map.current.fitToElements({ animated: true });
  };

  return (
    <View style={styles.container}>
      <MapView
        ref={(ref) => {
          map.current = ref;
        }}
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        kmlSrc={KML_FILE}
        onKmlReady={onKmlReady}
      >
        <Marker
          coordinate={region}
          title="中心点"
          description="地图中心示例标注"
        />
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
    width,
    height,
  },
});
