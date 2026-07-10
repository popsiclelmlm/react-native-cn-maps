import { useEffect, useRef, useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  Dimensions,
  Alert,
  Platform,
} from 'react-native';
import MapView, { Marker, Callout, CalloutSubview } from 'react-native-cn-maps';
import CustomCallout from './CustomCallout';
import { DemoButton, DemoButtonRow, DemoControls, DemoHint } from './_ui';

const { width, height } = Dimensions.get('window');
const ASPECT_RATIO = width / height;
const LATITUDE = 31.2304;
const LONGITUDE = 121.4737;
const LATITUDE_DELTA = 0.0922;
const LONGITUDE_DELTA = LATITUDE_DELTA * ASPECT_RATIO;
const SPACE = 0.01;

function Callouts(props: any) {
  const marker1 = useRef<any>(null);
  const marker2 = useRef<any>(null);
  const marker4 = useRef<any>(null);

  const [cnt, setCnt] = useState(0);
  const [region] = useState({
    latitude: LATITUDE,
    longitude: LONGITUDE,
    latitudeDelta: LATITUDE_DELTA,
    longitudeDelta: LONGITUDE_DELTA,
  });
  const [markers] = useState<any>([
    {
      coordinate: {
        latitude: LATITUDE + SPACE,
        longitude: LONGITUDE + SPACE,
      },
    },
    {
      coordinate: {
        latitude: LATITUDE + SPACE,
        longitude: LONGITUDE - SPACE,
      },
    },
    {
      coordinate: {
        latitude: LATITUDE,
        longitude: LONGITUDE,
      },
    },
    {
      coordinate: {
        latitude: LATITUDE,
        longitude: LONGITUDE - SPACE / 2,
      },
    },
  ]);

  // cnt 变化后重绘 callout，等价于原 setState 回调（跳过首次挂载）
  const isFirstRender = useRef(true);
  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false;
      return;
    }
    marker2.current.redrawCallout();
  }, [cnt]);

  function show() {
    marker1.current.showCallout();
  }

  function hide() {
    marker1.current.hideCallout();
  }

  return (
    <View style={styles.container}>
      <MapView
        provider={props.provider}
        style={styles.map}
        initialRegion={region}
        zoomTapEnabled={false}
      >
        <Marker
          ref={(ref) => {
            marker1.current = ref;
          }}
          coordinate={markers[0].coordinate}
          title="原生样式气泡"
          description="标题与描述由地图 SDK 原生渲染，点击标注即可弹出。"
        />
        <Marker coordinate={markers[1].coordinate}>
          <Callout style={styles.plainView}>
            <View>
              <Text style={styles.plainText}>这是一个普通视图</Text>
            </View>
          </Callout>
        </Marker>
        <Marker
          coordinate={markers[2].coordinate}
          calloutAnchor={{ x: 0.5, y: 0.4 }}
          ref={(ref) => {
            marker2.current = ref;
          }}
        >
          <Callout
            alphaHitTest
            tooltip
            onPress={(_) => {
              Alert.alert('气泡被点击');
            }}
            style={styles.customView}
          >
            <CustomCallout>
              <Text style={styles.customText}>{`自定义气泡视图 ${cnt}`}</Text>
              {Platform.OS === 'ios' && (
                <CalloutSubview
                  onPress={() => {
                    setCnt((c) => c + 1);
                  }}
                  style={[styles.calloutButton]}
                >
                  <Text style={styles.calloutButtonText}>点我 +1</Text>
                </CalloutSubview>
              )}
            </CustomCallout>
          </Callout>
        </Marker>
        <Marker
          ref={(ref) => {
            marker4.current = ref;
          }}
          coordinate={markers[3].coordinate}
          title="也可以打开这个气泡"
          description="点击自定义气泡的透明区域即可触发。"
        />
      </MapView>

      <DemoControls>
        <DemoHint>点击不同标注，查看多种气泡样式</DemoHint>
        <DemoButtonRow>
          <DemoButton label="显示气泡" onPress={show} />
          <DemoButton label="隐藏气泡" variant="secondary" onPress={hide} />
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

  // 气泡内容（与地图相关，留在本文件）
  customView: {
    width: 140,
    height: Platform.select({ android: 100, default: 140 }),
  },
  customText: {
    fontSize: 14,
    color: '#0F172A',
  },
  plainView: {
    width: 72,
  },
  plainText: {
    fontSize: 13,
    color: '#0F172A',
  },
  calloutButton: {
    marginTop: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
    backgroundColor: '#2563EB',
    alignItems: 'center',
  },
  calloutButtonText: {
    fontSize: 13,
    color: '#FFFFFF',
    fontWeight: '600',
  },
});

export default Callouts;
