import { useState } from 'react';
import { Text, View, Dimensions, StyleSheet, FlatList } from 'react-native';

import MapView, { Marker } from 'react-native-cn-maps';
import flagImg from './assets/flag-blue.png';
import { DemoButton } from './_ui';

const HORIZONTAL_PADDING = 12;
const VERTICAL_PADDING = 6;

function CachedMap(props: any) {
  const [data, setData] = useState<any>([...CITIES]);
  const [cache, setCache] = useState(true);

  function toggleCache() {
    // a hack to force listview to reload with the same data
    setData(data);
    setCache((c) => !c);
    setData([...CITIES]);
  }

  const { width } = Dimensions.get('window');
  const mapSize = width - HORIZONTAL_PADDING * 2;
  return (
    <View style={styles.container}>
      <View style={styles.buttonContainer}>
        <DemoButton
          label={cache ? '已缓存' : '未缓存'}
          variant={cache ? 'primary' : 'secondary'}
          onPress={toggleCache}
        />
      </View>
      <FlatList
        data={data}
        renderItem={({ item: region }) => (
          <View style={styles.item}>
            <Text>{region.name}</Text>
            <MapView
              provider={props.provider}
              style={{
                width: mapSize,
                height: mapSize,
              }}
              initialRegion={region}
              cacheEnabled={cache}
              zoomEnabled
              loadingIndicatorColor="#666666"
              loadingBackgroundColor="#eeeeee"
            >
              <Marker
                coordinate={region}
                centerOffset={{ x: -18, y: -60 }}
                anchor={{ x: 0.69, y: 1 }}
                image={flagImg}
              />
            </MapView>
          </View>
        )}
        keyExtractor={(_item, index) => index.toString()}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  item: {
    backgroundColor: 'white',
    paddingHorizontal: HORIZONTAL_PADDING,
    paddingVertical: VERTICAL_PADDING,
  },
  buttonContainer: {
    flexDirection: 'row',
    marginVertical: 20,
    marginHorizontal: 10,
    backgroundColor: 'transparent',
    justifyContent: 'flex-end',
  },
});

// 官方示例为世界各国首都；国内地图 SDK 海外底图数据有限，
// 这里换成中国主要城市列表。
const CITIES = [
  {
    name: '北京',
    latitude: 39.9042,
    longitude: 116.4074,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '上海',
    latitude: 31.2304,
    longitude: 121.4737,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '天津',
    latitude: 39.0851,
    longitude: 117.1994,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '重庆',
    latitude: 29.563,
    longitude: 106.5516,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '哈尔滨',
    latitude: 45.8038,
    longitude: 126.535,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '长春',
    latitude: 43.8171,
    longitude: 125.3235,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '沈阳',
    latitude: 41.8057,
    longitude: 123.4315,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '呼和浩特',
    latitude: 40.8424,
    longitude: 111.75,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '石家庄',
    latitude: 38.0428,
    longitude: 114.5149,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '太原',
    latitude: 37.8706,
    longitude: 112.5489,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '济南',
    latitude: 36.6512,
    longitude: 117.1201,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '郑州',
    latitude: 34.7466,
    longitude: 113.6254,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '西安',
    latitude: 34.3416,
    longitude: 108.9398,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '兰州',
    latitude: 36.0611,
    longitude: 103.8343,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '西宁',
    latitude: 36.6171,
    longitude: 101.7782,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '银川',
    latitude: 38.4872,
    longitude: 106.2309,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '乌鲁木齐',
    latitude: 43.8256,
    longitude: 87.6168,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '拉萨',
    latitude: 29.652,
    longitude: 91.1721,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '成都',
    latitude: 30.5728,
    longitude: 104.0668,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '昆明',
    latitude: 24.8801,
    longitude: 102.8329,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '贵阳',
    latitude: 26.647,
    longitude: 106.6302,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '南宁',
    latitude: 22.817,
    longitude: 108.3665,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '广州',
    latitude: 23.1291,
    longitude: 113.2644,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '深圳',
    latitude: 22.5431,
    longitude: 114.0579,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '海口',
    latitude: 20.0444,
    longitude: 110.1999,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '长沙',
    latitude: 28.2282,
    longitude: 112.9388,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '武汉',
    latitude: 30.5928,
    longitude: 114.3055,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '南昌',
    latitude: 28.682,
    longitude: 115.8579,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '合肥',
    latitude: 31.8206,
    longitude: 117.2272,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '南京',
    latitude: 32.0603,
    longitude: 118.7969,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '杭州',
    latitude: 30.2741,
    longitude: 120.1551,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '福州',
    latitude: 26.0745,
    longitude: 119.2965,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '香港',
    latitude: 22.3193,
    longitude: 114.1694,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '澳门',
    latitude: 22.1987,
    longitude: 113.5439,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
  {
    name: '台北',
    latitude: 25.033,
    longitude: 121.5654,
    latitudeDelta: 0.3,
    longitudeDelta: 0.3,
  },
];

export default CachedMap;
