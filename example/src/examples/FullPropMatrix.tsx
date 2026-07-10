import { useCallback, useRef, useState } from 'react';
import {
  Image,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  View,
} from 'react-native';
import MapView, {
  Callout,
  Circle,
  Geojson,
  Heatmap,
  Marker,
  Overlay,
  Polygon,
  Polyline,
  UrlTile,
  WMSTile,
} from 'react-native-cn-maps';
import type {
  Camera,
  LatLng,
  MapMarkerHandle,
  MapType,
  MapViewHandle,
  Provider,
  Region,
} from 'react-native-cn-maps';
import { DemoButton, DemoButtonRow, DemoPanel } from './_ui';

// 「全属性矩阵」示例：把 MapView 的每个属性与事件都接到一个实时控件上，
// 便于在真机上逐项开关、观察效果。
// （由原单文件示例收编而来：provider 改由 App 的切换器传入，
// setPrivacyConsent 隐私合规调用移至 App.tsx 入口。）

interface DemoProps {
  provider: Provider;
}

const SHANGHAI: Region = {
  latitude: 31.2304,
  longitude: 121.4737,
  latitudeDelta: 0.08,
  longitudeDelta: 0.08,
};

const BEIJING_CAMERA: Camera = {
  center: { latitude: 39.9042, longitude: 116.4074 },
  heading: 30,
  pitch: 45,
  zoom: 12,
};

const THE_BUND: LatLng = { latitude: 31.2397, longitude: 121.499 };
const PEOPLES_SQUARE: LatLng = { latitude: 31.2286, longitude: 121.4753 };

// 标注集合：默认 / 带色 / 图片 / 自定义 React 视图 / 可拖拽 各一个，
// 外加供 ref 命令调用的目标标注。
const DEFAULT_PIN: LatLng = { latitude: 31.2204, longitude: 121.46 };
const IMAGE_MARKER: LatLng = { latitude: 31.235, longitude: 121.468 };
const CUSTOM_MARKER: LatLng = { latitude: 31.2246, longitude: 121.49 };
const DRAGGABLE_MARKER: LatLng = { latitude: 31.218, longitude: 121.478 };
const ANIMATE_TARGET: LatLng = { latitude: 31.232, longitude: 121.452 };

const TINY_LOGO = 'https://reactnative.dev/img/tiny_logo.png';

// 矢量覆盖物：一条折线、一个填充多边形围栏、一个半径圆。
const LINE: LatLng[] = [
  { latitude: 31.2397, longitude: 121.499 },
  { latitude: 31.2286, longitude: 121.4753 },
  { latitude: 31.2204, longitude: 121.46 },
];
const FENCE: LatLng[] = [
  { latitude: 31.245, longitude: 121.47 },
  { latitude: 31.245, longitude: 121.49 },
  { latitude: 31.232, longitude: 121.49 },
  { latitude: 31.232, longitude: 121.47 },
];
const CIRCLE_CENTER: LatLng = { latitude: 31.2286, longitude: 121.4753 };

// 示例 GeoJSON（坐标为 [lng, lat]，按规范为 WGS-84）——上海附近的一个点、
// 一条线和一个多边形，用于 Geojson 演示。
const SAMPLE_GEOJSON = {
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [121.5, 31.25] },
    },
    {
      type: 'Feature',
      geometry: {
        type: 'LineString',
        coordinates: [
          [121.46, 31.21],
          [121.5, 31.24],
          [121.52, 31.2],
        ],
      },
    },
    {
      type: 'Feature',
      geometry: {
        type: 'Polygon',
        coordinates: [
          [
            [121.44, 31.25],
            [121.47, 31.26],
            [121.47, 31.23],
            [121.44, 31.23],
            [121.44, 31.25],
          ],
        ],
      },
    },
  ],
};

// 热力图演示：上海附近一簇带权重的点。
const HEATMAP_POINTS = [
  { latitude: 31.23, longitude: 121.47, weight: 1 },
  { latitude: 31.232, longitude: 121.472, weight: 0.8 },
  { latitude: 31.228, longitude: 121.468, weight: 0.6 },
  { latitude: 31.235, longitude: 121.475, weight: 1 },
  { latitude: 31.225, longitude: 121.465, weight: 0.4 },
  { latitude: 31.233, longitude: 121.463, weight: 0.7 },
];

const MAP_TYPES: MapType[] = ['standard', 'satellite', 'hybrid'];

// mapType 取值的中文标签（仅用于按钮显示，传给 setMapType 的仍是原值）
const MAP_TYPE_LABELS: Partial<Record<MapType, string>> = {
  standard: '标准',
  satellite: '卫星',
  hybrid: '混合',
};

// 布尔属性以开关网格呈现，按显示顺序排列。
const TOGGLE_KEYS = [
  'showsTraffic',
  'showsBuildings',
  'showsCompass',
  'showsScale',
  'showsIndoors',
  'showsPointsOfInterest',
  'showsUserLocation',
  'showsMyLocationButton',
  'zoomControlEnabled',
  'zoomEnabled',
  'scrollEnabled',
  'rotateEnabled',
  'pitchEnabled',
] as const;

type ToggleKey = (typeof TOGGLE_KEYS)[number];

const INITIAL_FLAGS: Record<ToggleKey, boolean> = {
  showsTraffic: false,
  showsBuildings: true,
  showsCompass: true,
  showsScale: true,
  showsIndoors: true,
  showsPointsOfInterest: true,
  showsUserLocation: false,
  showsMyLocationButton: true,
  zoomControlEnabled: false,
  zoomEnabled: true,
  scrollEnabled: true,
  rotateEnabled: true,
  pitchEnabled: true,
};

// 各开关的中文注解（仅用于显示，键名仍是 API 属性名）
const TOGGLE_LABELS: Record<ToggleKey, string> = {
  showsTraffic: '路况',
  showsBuildings: '3D 建筑',
  showsCompass: '指南针',
  showsScale: '比例尺',
  showsIndoors: '室内图',
  showsPointsOfInterest: '兴趣点',
  showsUserLocation: '我的位置',
  showsMyLocationButton: '定位按钮',
  zoomControlEnabled: '缩放控件',
  zoomEnabled: '缩放手势',
  scrollEnabled: '平移手势',
  rotateEnabled: '旋转手势',
  pitchEnabled: '俯仰手势',
};

const fmt = (n: number) => n.toFixed(4);

const coordText = (c: LatLng) => `${fmt(c.latitude)}, ${fmt(c.longitude)}`;

export default function FullPropMatrix({ provider }: DemoProps) {
  const mapRef = useRef<MapViewHandle>(null);
  const panCount = useRef(0);
  const customMarkerRef = useRef<MapMarkerHandle>(null);
  const draggableMarkerRef = useRef<MapMarkerHandle>(null);

  const [mapType, setMapType] = useState<MapType>('standard');
  const [dark, setDark] = useState(false);
  const [camera, setCamera] = useState<Camera | undefined>(undefined);
  const [showTiles, setShowTiles] = useState(false);
  const [showOverlay, setShowOverlay] = useState(false);
  const [showGeojson, setShowGeojson] = useState(false);
  const [gradientLine, setGradientLine] = useState(false);
  const [showHeatmap, setShowHeatmap] = useState(false);
  const [showWms, setShowWms] = useState(false);
  const [snapshotUri, setSnapshotUri] = useState<string | null>(null);
  const [flags, setFlags] = useState(INITIAL_FLAGS);
  const [log, setLog] = useState<string[]>([]);
  const [pan, setPan] = useState('拖动 onPanDrag —');
  const [regionText, setRegionText] = useState('区域 region —');
  // 递增该值会重渲染自定义标注的内容；开启 tracksViewChanges 后，
  // 标注会重新栅格化以反映变化。
  const [customLabel, setCustomLabel] = useState(0);

  const pushLog = useCallback((line: string) => {
    setLog((prev) => [line, ...prev].slice(0, 7));
  }, []);

  const setFlag = useCallback(
    (key: ToggleKey) => (value: boolean) =>
      setFlags((prev) => ({ ...prev, [key]: value })),
    []
  );

  const flyToBeijing = useCallback(() => {
    setCamera(BEIJING_CAMERA);
    pushLog('相机 → 北京');
  }, [pushLog]);

  const backToShanghai = useCallback(() => {
    // 先清除受控 camera，再用命令式 animateToRegion 把地图带回初始区域。
    setCamera(undefined);
    mapRef.current?.animateToRegion(SHANGHAI, 800);
    pushLog('animateToRegion → 上海');
  }, [pushLog]);

  const captureSnapshot = useCallback(async () => {
    try {
      const uri = await mapRef.current?.takeSnapshot?.({ result: 'file' });
      setSnapshotUri(uri ?? null);
      pushLog(`takeSnapshot → ${uri ? '成功' : '空'}`);
    } catch (e) {
      pushLog(`takeSnapshot 出错：${String(e)}`);
    }
  }, [pushLog]);

  const limitToShanghai = useCallback(() => {
    mapRef.current?.setMapBoundaries?.(
      { latitude: 31.27, longitude: 121.52 },
      { latitude: 31.19, longitude: 121.43 }
    );
    pushLog('setMapBoundaries → 上海边界框');
  }, [pushLog]);

  const logMarkerFrames = useCallback(async () => {
    try {
      const frames = await mapRef.current?.getMarkersFrames?.();
      pushLog(`getMarkersFrames → ${Object.keys(frames ?? {}).join(', ')}`);
    } catch (e) {
      pushLog(`getMarkersFrames 出错：${String(e)}`);
    }
  }, [pushLog]);

  const logAddress = useCallback(async () => {
    try {
      const addr = await mapRef.current?.addressForCoordinate?.(THE_BUND);
      pushLog(`地址 → ${addr?.name || '(空)'}`);
    } catch (e) {
      pushLog(`addressForCoordinate 出错：${String(e)}`);
    }
  }, [pushLog]);

  return (
    <View style={styles.container}>
      <MapView
        // provider 变化时重新挂载 —— 一个地图视图在其生命周期内绑定单个 SDK
        // 实例（provider 属于「挂载即固定」）。
        key={`map-${provider}`}
        ref={mapRef}
        style={styles.map}
        provider={provider}
        coordinateSystem="gcj02"
        initialRegion={SHANGHAI}
        camera={camera}
        mapType={mapType}
        userInterfaceStyle={dark ? 'dark' : 'light'}
        minZoomLevel={3}
        maxZoomLevel={19}
        showsTraffic={flags.showsTraffic}
        showsBuildings={flags.showsBuildings}
        showsCompass={flags.showsCompass}
        showsScale={flags.showsScale}
        showsIndoors={flags.showsIndoors}
        showsPointsOfInterest={flags.showsPointsOfInterest}
        showsUserLocation={flags.showsUserLocation}
        showsMyLocationButton={flags.showsMyLocationButton}
        zoomControlEnabled={flags.zoomControlEnabled}
        zoomEnabled={flags.zoomEnabled}
        scrollEnabled={flags.scrollEnabled}
        rotateEnabled={flags.rotateEnabled}
        pitchEnabled={flags.pitchEnabled}
        onMapReady={() => pushLog('onMapReady 地图就绪')}
        onMapLoaded={() => pushLog('onMapLoaded 地图加载完成')}
        onPress={(e) =>
          pushLog(`onPress ${coordText(e.nativeEvent.coordinate)}`)
        }
        onLongPress={(e) =>
          pushLog(`onLongPress ${coordText(e.nativeEvent.coordinate)}`)
        }
        onDoublePress={(e) =>
          pushLog(`onDoublePress ${coordText(e.nativeEvent.coordinate)}`)
        }
        onPanDrag={(e) => {
          panCount.current += 1;
          setPan(
            `onPanDrag ${coordText(e.nativeEvent.coordinate)} ×${panCount.current}`
          );
        }}
        onPoiClick={(e) =>
          pushLog(
            `onPoiClick ${e.nativeEvent.name ?? '(无名)'} ${coordText(
              e.nativeEvent.coordinate
            )}`
          )
        }
        onUserLocationChange={(e) => {
          const c = e.nativeEvent.coordinate;
          if (c) {
            pushLog(`onUserLocationChange ${coordText(c)}`);
          }
        }}
        onRegionChangeComplete={(e) =>
          setRegionText(
            `区域 ${coordText(e.nativeEvent.region)} (手势：${
              e.nativeEvent.isGesture ? '是' : '否'
            })`
          )
        }
      >
        <Marker
          coordinate={THE_BUND}
          identifier="bund"
          title="外滩"
          description="外滩"
          pinColor="green"
          onPress={(e) => pushLog(`标注 onPress ${e.nativeEvent.identifier}`)}
        >
          {/* 自定义 <Callout>：绿色图钉 + 可点击的自定义气泡。 */}
          <Callout onPress={() => pushLog('callout onPress 外滩')}>
            <View style={styles.callout}>
              <Text style={styles.calloutTitle}>外滩</Text>
              <Text style={styles.calloutBody}>自定义气泡 — 点我</Text>
            </View>
          </Callout>
        </Marker>
        <Marker
          coordinate={PEOPLES_SQUARE}
          identifier="square"
          title="人民广场"
          description="人民广场"
          pinColor="purple"
          onPress={(e) => pushLog(`标注 onPress ${e.nativeEvent.identifier}`)}
        />

        {/* 默认图钉（无 pinColor / image）。 */}
        <Marker
          coordinate={DEFAULT_PIN}
          identifier="default"
          title="默认图钉"
          onPress={(e) => pushLog(`标注 onPress ${e.nativeEvent.identifier}`)}
        />

        {/* 从远程 uri 解析的图片标注。 */}
        <Marker
          coordinate={IMAGE_MARKER}
          identifier="image"
          title="图片标注"
          image={{ uri: TINY_LOGO }}
          onPress={(e) => pushLog(`标注 onPress ${e.nativeEvent.identifier}`)}
        />

        {/* 自定义 React 内容栅格化为图标；通过 ref 触发命令。 */}
        <Marker
          ref={customMarkerRef}
          coordinate={CUSTOM_MARKER}
          identifier="custom"
          title="自定义视图"
          tracksViewChanges
          onSelect={(e) => pushLog(`标注 onSelect ${e.nativeEvent.identifier}`)}
          onCalloutPress={() => pushLog('标注 onCalloutPress 自定义')}
        >
          <View style={styles.customMarker}>
            <Text style={styles.customMarkerText}>🚇 {customLabel}</Text>
          </View>
        </Marker>

        {/* 可拖拽标注；拖拽 + animate 命令的目标。 */}
        <Marker
          ref={draggableMarkerRef}
          coordinate={DRAGGABLE_MARKER}
          identifier="draggable"
          title="拖动我"
          pinColor="#1f6feb"
          draggable
          onDragStart={(e) =>
            pushLog(`标注 onDragStart ${coordText(e.nativeEvent.coordinate)}`)
          }
          onDragEnd={(e) =>
            pushLog(`标注 onDragEnd ${coordText(e.nativeEvent.coordinate)}`)
          }
        />

        {/* 矢量覆盖物。 */}
        <Polyline
          coordinates={LINE}
          strokeColor="#e2231a"
          strokeColors={
            gradientLine ? ['#ff0000', '#00ff00', '#0000ff'] : undefined
          }
          strokeWidth={4}
          lineCap="round"
          lineJoin="round"
          tappable
          onPress={() => pushLog('折线 onPress')}
        />
        <Polygon
          coordinates={FENCE}
          strokeColor="#1f6feb"
          strokeWidth={2}
          fillColor="rgba(31,111,235,0.2)"
        />
        <Circle
          center={CIRCLE_CENTER}
          radius={800}
          strokeColor="#2e7d32"
          strokeWidth={2}
          fillColor="rgba(46,125,50,0.15)"
        />
        {showTiles && (
          <UrlTile
            urlTemplate="https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}"
            maximumZ={19}
            zIndex={-1}
          />
        )}
        {showOverlay && (
          <Overlay
            image={{ uri: 'https://reactnative.dev/img/tiny_logo.png' }}
            bounds={[
              { latitude: 31.27, longitude: 121.44 },
              { latitude: 31.19, longitude: 121.51 },
            ]}
            opacity={0.7}
          />
        )}
        {showGeojson && (
          <Geojson
            geojson={SAMPLE_GEOJSON}
            strokeColor="#8e24aa"
            strokeWidth={3}
            fillColor="rgba(142,36,170,0.2)"
            pinColor="purple"
          />
        )}
        {showHeatmap && <Heatmap points={HEATMAP_POINTS} radius={40} />}
        {showWms && (
          <WMSTile
            urlTemplate={
              'https://ows.terrestris.de/osm/service?SERVICE=WMS&VERSION=1.1.1' +
              '&REQUEST=GetMap&LAYERS=OSM-WMS&STYLES=&FORMAT=image/png' +
              '&TRANSPARENT=true&SRS=EPSG:3857&WIDTH={width}&HEIGHT={height}' +
              '&BBOX={minX},{minY},{maxX},{maxY}'
            }
            maximumZ={19}
            zIndex={-1}
          />
        )}
      </MapView>

      <View pointerEvents="none" style={styles.logOverlay}>
        <Text style={styles.logLine}>{regionText}</Text>
        <Text style={styles.logLine}>{pan}</Text>
        {log.map((line, index) => (
          <Text key={`${index}-${line}`} style={styles.logLine}>
            {line}
          </Text>
        ))}
      </View>

      <ScrollView
        style={styles.panel}
        contentContainerStyle={styles.panelInner}
      >
        <Text style={styles.sectionTitle}>相机 / 区域</Text>
        <DemoButtonRow style={styles.buttonRow}>
          <DemoButton label="飞到北京（相机）" onPress={flyToBeijing} />
          <DemoButton label="回到上海（动画）" onPress={backToShanghai} />
        </DemoButtonRow>

        <Text style={styles.sectionTitle}>截图</Text>
        <DemoButtonRow style={styles.buttonRow}>
          <DemoButton label="截图 takeSnapshot" onPress={captureSnapshot} />
        </DemoButtonRow>
        {snapshotUri && (
          <DemoPanel style={styles.snapshotPanel}>
            <Image source={{ uri: snapshotUri }} style={styles.snapshot} />
          </DemoPanel>
        )}

        <Text style={styles.sectionTitle}>命令</Text>
        <DemoButtonRow style={styles.buttonRow}>
          <DemoButton
            label="设置边界 setMapBoundaries"
            onPress={limitToShanghai}
          />
          <DemoButton
            label="获取标注框 getMarkersFrames"
            onPress={logMarkerFrames}
          />
          <DemoButton
            label="逆地理编码 addressForCoordinate"
            onPress={logAddress}
          />
        </DemoButtonRow>

        <Text style={styles.sectionTitle}>标注</Text>
        <DemoButtonRow style={styles.buttonRow}>
          <DemoButton
            label="显示气泡（自定义）"
            onPress={() => customMarkerRef.current?.showCallout()}
          />
          <DemoButton
            label="更新自定义标签"
            onPress={() => {
              setCustomLabel((n) => n + 1);
              pushLog('自定义标注标签已更新');
            }}
          />
          <DemoButton
            label="重绘自定义"
            onPress={() => customMarkerRef.current?.redraw()}
          />
          <DemoButton
            label="平移可拖拽标注"
            onPress={() => {
              draggableMarkerRef.current?.animateMarkerToCoordinate(
                ANIMATE_TARGET,
                1000
              );
              pushLog('平移可拖拽标注');
            }}
          />
        </DemoButtonRow>

        <Text style={styles.sectionTitle}>地图类型 mapType</Text>
        <View style={styles.buttonRow}>
          {MAP_TYPES.map((type) => (
            <Pressable
              key={type}
              style={[styles.chip, mapType === type && styles.chipActive]}
              onPress={() => setMapType(type)}
            >
              <Text
                style={[
                  styles.chipText,
                  mapType === type && styles.chipTextActive,
                ]}
              >
                {MAP_TYPE_LABELS[type] ?? type}
              </Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>userInterfaceStyle：暗色</Text>
          <Switch value={dark} onValueChange={setDark} />
        </View>

        <Text style={styles.sectionTitle}>瓦片 / 覆盖物</Text>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>UrlTile：OSM 栅格瓦片</Text>
          <Switch value={showTiles} onValueChange={setShowTiles} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Overlay：图片地面覆盖物</Text>
          <Switch value={showOverlay} onValueChange={setShowOverlay} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Geojson：点 + 线 + 多边形</Text>
          <Switch value={showGeojson} onValueChange={setShowGeojson} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Polyline：渐变</Text>
          <Switch value={gradientLine} onValueChange={setGradientLine} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>Heatmap：带权重的点</Text>
          <Switch value={showHeatmap} onValueChange={setShowHeatmap} />
        </View>
        <View style={styles.toggleRow}>
          <Text style={styles.toggleLabel}>WMSTile：OSM-WMS</Text>
          <Switch value={showWms} onValueChange={setShowWms} />
        </View>

        <Text style={styles.sectionTitle}>显示与手势开关</Text>
        {TOGGLE_KEYS.map((key) => (
          <View key={key} style={styles.toggleRow}>
            <Text
              style={styles.toggleLabel}
            >{`${key}：${TOGGLE_LABELS[key]}`}</Text>
            <Switch value={flags[key]} onValueChange={setFlag(key)} />
          </View>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  map: {
    flex: 1,
  },
  logOverlay: {
    position: 'absolute',
    top: 48,
    left: 12,
    right: 12,
    padding: 8,
    borderRadius: 8,
    backgroundColor: 'rgba(0, 0, 0, 0.55)',
  },
  logLine: {
    color: '#fff',
    fontSize: 11,
    lineHeight: 16,
    fontFamily: 'Courier',
  },
  panel: {
    maxHeight: '42%',
    backgroundColor: '#fff',
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#ccc',
  },
  panelInner: {
    padding: 12,
    paddingBottom: 32,
  },
  snapshotPanel: {
    marginTop: 8,
    alignSelf: 'flex-start',
  },
  snapshot: {
    width: 160,
    height: 100,
    borderRadius: 6,
    backgroundColor: '#eee',
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '700',
    color: '#333',
    marginTop: 12,
    marginBottom: 6,
  },
  buttonRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 14,
    borderRadius: 16,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: '#1f6feb',
  },
  chipActive: {
    backgroundColor: '#1f6feb',
  },
  chipText: {
    color: '#1f6feb',
    fontSize: 12,
    fontWeight: '600',
  },
  chipTextActive: {
    color: '#fff',
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 4,
  },
  toggleLabel: {
    fontSize: 13,
    color: '#333',
    flexShrink: 1,
  },
  customMarker: {
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 14,
    backgroundColor: '#1f6feb',
    borderWidth: 2,
    borderColor: '#fff',
  },
  customMarkerText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '700',
  },
  callout: {
    padding: 8,
    backgroundColor: '#fff',
    borderRadius: 8,
    minWidth: 160,
  },
  calloutTitle: {
    fontSize: 14,
    fontWeight: '700',
    color: '#111',
  },
  calloutBody: {
    fontSize: 12,
    color: '#555',
    marginTop: 2,
  },
});
