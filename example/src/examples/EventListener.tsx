import { memo, useState } from 'react';
import { StyleSheet, View, Text, Dimensions, ScrollView } from 'react-native';
import MapView, {
  Marker,
  Polygon,
  Polyline,
  Callout,
} from 'react-native-cn-maps';
import PriceMarker from './PriceMarker';
import { DemoPanel } from './_ui';

const { width, height } = Dimensions.get('window');

const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
let id = 0;

// 原 shouldComponentUpdate 返回 id 不同才重渲染；memo 比较函数返回 true 表示跳过，故 id 相等时跳过
const Event = memo(
  function Event(props: any) {
    const { event } = props;
    return (
      <View style={styles.event}>
        <Text style={styles.eventName}>{event.name}</Text>
        <Text style={styles.eventData}>
          {JSON.stringify(event.data, null, 2)}
        </Text>
      </View>
    );
  },
  (prevProps, nextProps) => prevProps.event.id === nextProps.event.id
);

function EventListener(props: any) {
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [events, setEvents] = useState<any[]>([]);

  function makeEvent(e: any, name: any) {
    return {
      id: id++,
      name,
      data: e.nativeEvent ? e.nativeEvent : e,
    };
  }

  function recordEvent(name: any) {
    return (e: any) => {
      if (e.persist) {
        e.persist(); // 避免 React 事件池相关警告，详见 https://fb.me/react-event-pooling
      }
      setEvents((prevEvents: any) => [
        makeEvent(e, name),
        ...prevEvents.slice(0, 10),
      ]);
    };
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        showsUserLocation
        showsMyLocationButton
        onRegionChange={recordEvent('Map::onRegionChange 区域变化')}
        onRegionChangeComplete={recordEvent(
          'Map::onRegionChangeComplete 区域变化完成'
        )}
        onPress={recordEvent('Map::onPress 点击地图')}
        onPanDrag={recordEvent('Map::onPanDrag 拖动地图')}
        onLongPress={recordEvent('Map::onLongPress 长按地图')}
        onMarkerPress={recordEvent('Map::onMarkerPress 点击标注')}
        onMarkerSelect={recordEvent('Map::onMarkerSelect 选中标注')}
        onMarkerDeselect={recordEvent('Map::onMarkerDeselect 取消选中标注')}
        onCalloutPress={recordEvent('Map::onCalloutPress 点击气泡')}
        onUserLocationChange={recordEvent(
          'Map::onUserLocationChange 用户位置变化'
        )}
      >
        <Marker
          coordinate={{
            latitude: LATITUDE + LATITUDE_DELTA / 2,
            longitude: LONGITUDE + LONGITUDE_DELTA / 2,
          }}
        />
        <Marker
          coordinate={{
            latitude: LATITUDE - LATITUDE_DELTA / 2,
            longitude: LONGITUDE - LONGITUDE_DELTA / 2,
          }}
        />
        <Marker
          title="这是标题"
          description="这是描述"
          coordinate={region}
          onPress={recordEvent('Marker::onPress 点击标注')}
          onSelect={recordEvent('Marker::onSelect 选中标注')}
          onDeselect={recordEvent('Marker::onDeselect 取消选中标注')}
          onCalloutPress={recordEvent('Marker::onCalloutPress 点击气泡')}
        >
          <PriceMarker amount={99} />
          <Callout
            style={styles.callout}
            onPress={recordEvent('Callout::onPress 点击气泡')}
          >
            <View>
              <Text>你好呀……</Text>
            </View>
          </Callout>
        </Marker>
        <Polygon
          fillColor={'rgba(255,0,0,0.3)'}
          onPress={recordEvent('Polygon::onPress')}
          tappable
          coordinates={[
            {
              latitude: LATITUDE + LATITUDE_DELTA / 5,
              longitude: LONGITUDE + LONGITUDE_DELTA / 4,
            },
            {
              latitude: LATITUDE + LATITUDE_DELTA / 3,
              longitude: LONGITUDE + LONGITUDE_DELTA / 4,
            },
            {
              latitude: LATITUDE + LATITUDE_DELTA / 4,
              longitude: LONGITUDE + LONGITUDE_DELTA / 2,
            },
          ]}
        />
        <Polyline
          strokeColor={'rgba(255,0,0,1)'}
          onPress={recordEvent('Polyline::onPress')}
          tappable
          coordinates={[
            {
              latitude: LATITUDE + LATITUDE_DELTA / 5,
              longitude: LONGITUDE - LONGITUDE_DELTA / 4,
            },
            {
              latitude: LATITUDE + LATITUDE_DELTA / 3,
              longitude: LONGITUDE - LONGITUDE_DELTA / 4,
            },
            {
              latitude: LATITUDE + LATITUDE_DELTA / 4,
              longitude: LONGITUDE - LONGITUDE_DELTA / 2,
            },
          ]}
        />
      </MapView>
      <DemoPanel style={styles.eventList}>
        <ScrollView>
          {events.map((event: any) => (
            <Event key={event.id} event={event} />
          ))}
        </ScrollView>
      </DemoPanel>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    ...StyleSheet.absoluteFill,
    justifyContent: 'flex-end',
    alignItems: 'center',
  },
  eventList: {
    position: 'absolute',
    top: (2 / 3) * height, // 从屏幕三分之二处开始
    left: 0,
    right: 0,
    bottom: 0,
  },
  map: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: height / 3, // 调整为屏幕的三分之一
  },
  event: {
    borderBottomWidth: 1,
    borderBottomColor: '#ccc',
    padding: 8,
  },
  eventData: {
    fontSize: 10,
    fontFamily: 'courier',
    color: '#555',
  },
  eventName: {
    fontSize: 13,
    fontWeight: 'bold',
    color: '#222',
  },
  callout: {
    width: 60,
  },
});

export default EventListener;
