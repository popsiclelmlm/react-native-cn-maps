import { useMemo, useRef, useState } from 'react';
import type { ComponentType, ReactNode } from 'react';
import type { StyleProp, ViewStyle } from 'react-native';
import {
  FlatList,
  Platform,
  Pressable,
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { setPrivacyConsent } from 'react-native-cn-maps';
import type { Provider } from 'react-native-cn-maps';

import AnimatedMarkers from './examples/AnimatedMarkers';
import AnimatedNavigation from './examples/AnimatedNavigation';
import AnimatedViews from './examples/AnimatedViews';
import BugMarkerWontUpdate from './examples/BugMarkerWontUpdate';
import CachedMap from './examples/CachedMap';
import CacheURLTiles from './examples/CacheURLTiles';
import CacheWMSTiles from './examples/CacheWMSTiles';
import Callouts from './examples/Callouts';
import CameraControl from './examples/CameraControl';
import CustomMarkers from './examples/CustomMarkers';
import CustomOverlay from './examples/CustomOverlay';
import CustomTiles from './examples/CustomTiles';
import CustomTilesLocal from './examples/CustomTilesLocal';
import DefaultMarkers from './examples/DefaultMarkers';
import DisplayLatLng from './examples/DisplayLatLng';
import DraggableMarkers from './examples/DraggableMarkers';
import EventListener from './examples/EventListener';
import FitToCoordinates from './examples/FitToCoordinates';
import FitToSuppliedMarkers from './examples/FitToSuppliedMarkers';
import FullPropMatrix from './examples/FullPropMatrix';
import GeojsonMap from './examples/Geojson';
import GradientPolylines from './examples/GradientPolylines';
import GradientPolylinesFunctional from './examples/GradientPolylinesFunctional';
import HeatMap from './examples/HeatMap';
import ImageOverlayWithAssets from './examples/ImageOverlayWithAssets';
import ImageOverlayWithBearing from './examples/ImageOverlayWithBearing';
import ImageOverlayWithURL from './examples/ImageOverlayWithURL';
import IndoorMap from './examples/IndoorMap';
import LegalLabel from './examples/LegalLabel';
import LiteMapView from './examples/LiteMapView';
import LoadingMap from './examples/LoadingMap';
import MapBoundaries from './examples/MapBoundaries';
import MapKml from './examples/MapKml';
import MarkerTypes from './examples/MarkerTypes';
import MassiveCustomMarkers from './examples/MassiveCustomMarkers';
import OnPoiClick from './examples/OnPoiClick';
import Overlays from './examples/Overlays';
import PolygonCreator from './examples/PolygonCreator';
import PolylineCreator from './examples/PolylineCreator';
import SetNativePropsOverlays from './examples/SetNativePropsOverlays';
import StaticMap from './examples/StaticMap';
import TakeSnapshot from './examples/TakeSnapshot';
import TestIdMarkers from './examples/TestIdMarkers';
import ThemeMap from './examples/ThemeMap';
import ViewsAsMarkers from './examples/ViewsAsMarkers';
import WMSTiles from './examples/WMSTiles';
import ZIndexMarkers from './examples/ZIndexMarkers';

// 隐私合规：国内地图 SDK（高德 / 百度 / 腾讯）要求在任何 MapView 挂载之前
// 确认用户已同意隐私政策，否则 SDK 拒绝初始化、地图一片空白。
// 这里在模块加载时直接同意仅用于 Demo —— 真实应用必须先向用户展示
// 隐私政策，用户实际同意后才能调用。
setPrivacyConsent({ agreed: true, contains: true, shown: true });

type DemoComponent = ComponentType<{ provider: Provider }>;

const PROVIDERS: { key: Provider; label: string; color: string }[] = [
  { key: 'amap', label: '高德', color: '#1677FF' },
  { key: 'baidu', label: '百度', color: '#3385FF' },
  { key: 'tencent', label: '腾讯', color: '#07C160' },
  { key: 'mapkit', label: 'MapKit', color: '#FF6B35' },
];

interface Category {
  title: string;
  icon: string;
  items: [DemoComponent, string][];
}

const CATEGORIES: Category[] = [
  {
    title: '基础地图',
    icon: '🗺',
    items: [
      [StaticMap, '静态地图'],
      [ThemeMap, '主题切换'],
      [LoadingMap, '加载状态'],
      [CachedMap, '地图缓存'],
      [LiteMapView, '轻量地图'],
      [IndoorMap, '室内地图'],
    ],
  },
  {
    title: '标注',
    icon: '📍',
    items: [
      [DefaultMarkers, '默认标注'],
      [CustomMarkers, '自定义标注'],
      [MarkerTypes, '图片标注'],
      [DraggableMarkers, '可拖拽标注'],
      [AnimatedMarkers, '动画标注'],
      [ViewsAsMarkers, '视图作为标注'],
      [ZIndexMarkers, '层级排序（Z-Index）'],
      [TestIdMarkers, '测试 ID 标注'],
      [MassiveCustomMarkers, '海量标注'],
      [BugMarkerWontUpdate, 'Bug：标注不更新'],
    ],
  },
  {
    title: '覆盖物',
    icon: '🔷',
    items: [
      [Overlays, '圆 · 多边形 · 折线'],
      [PolygonCreator, '绘制多边形'],
      [PolylineCreator, '绘制折线'],
      [GradientPolylines, '渐变折线'],
      [GradientPolylinesFunctional, '渐变折线（函数式）'],
      [CustomOverlay, '自定义覆盖物'],
      [SetNativePropsOverlays, '原生属性覆盖物'],
      [ImageOverlayWithAssets, '图片覆盖物（本地）'],
      [ImageOverlayWithURL, '图片覆盖物（网络）'],
      [ImageOverlayWithBearing, '图片覆盖物（旋转）'],
    ],
  },
  {
    title: '气泡',
    icon: '💬',
    items: [[Callouts, '自定义气泡']],
  },
  {
    title: '相机与导航',
    icon: '🎯',
    items: [
      [DisplayLatLng, '位置追踪'],
      [CameraControl, '相机控制'],
      [AnimatedNavigation, '导航动画'],
      [AnimatedViews, '地图联动动画'],
      [FitToSuppliedMarkers, '聚焦标注'],
      [FitToCoordinates, '适配坐标范围'],
      [MapBoundaries, '地图边界限制'],
    ],
  },
  {
    title: '图层与瓦片',
    icon: '🧩',
    items: [
      [CustomTiles, '自定义瓦片'],
      [CustomTilesLocal, '本地瓦片'],
      [WMSTiles, 'WMS 瓦片'],
      [CacheURLTiles, '瓦片缓存（URL）'],
      [CacheWMSTiles, '瓦片缓存（WMS）'],
      [HeatMap, '热力图'],
    ],
  },
  {
    title: '交互与事件',
    icon: '⚡',
    items: [
      [EventListener, '事件监听'],
      [OnPoiClick, 'POI 点击'],
      [LegalLabel, '合规标识'],
      [TakeSnapshot, '地图截图'],
    ],
  },
  {
    title: '数据',
    icon: '📊',
    items: [
      [MapKml, 'KML 数据'],
      [GeojsonMap, 'GeoJSON 数据'],
    ],
  },
  {
    title: '全量测试',
    icon: '🧪',
    items: [[FullPropMatrix, '全属性矩阵']],
  },
];

const TOTAL_COUNT = CATEGORIES.reduce((n, c) => n + c.items.length, 0);

// harmony 上 Pressable 在 touch start 时即抢占 JS responder，与 ArkUI Scroll 的
// 原生滚动手势竞争；竞争失败时表现为「手指拖动、列表不滚」，且 Scroll 会闪现
// 顶部一帧。这里在 harmony 上改用被动 touch 事件识别点击（完全不参与 responder
// 协商），滚动手势无条件归 Scroll；iOS/Android 仍用 Pressable 保留按压反馈。
function Tap({
  style,
  pressedStyle,
  onPress,
  children,
}: {
  style: StyleProp<ViewStyle>;
  pressedStyle?: StyleProp<ViewStyle>;
  onPress: () => void;
  children: ReactNode;
}) {
  const start = useRef<{ x: number; y: number; t: number } | null>(null);

  if (!IS_HARMONY) {
    return (
      <Pressable
        style={({ pressed }) => [style, pressed && pressedStyle]}
        onPress={onPress}
      >
        {children}
      </Pressable>
    );
  }

  return (
    <View
      style={style}
      onTouchStart={(e) => {
        const t = e.nativeEvent.touches[0] ?? e.nativeEvent;
        start.current = { x: t.pageX, y: t.pageY, t: Date.now() };
      }}
      onTouchEnd={(e) => {
        const s = start.current;
        start.current = null;
        if (!s) return;
        const t = e.nativeEvent.changedTouches[0] ?? e.nativeEvent;
        // 位移超过阈值（滚动）或按住过久（长按）都不算点击
        const moved =
          Math.abs(t.pageX - s.x) > 10 || Math.abs(t.pageY - s.y) > 10;
        if (!moved && Date.now() - s.t < 600) onPress();
      }}
    >
      {children}
    </View>
  );
}

export default function App() {
  const [demo, setDemo] = useState<[DemoComponent, string] | null>(null);
  const [provider, setProvider] = useState<Provider>('amap');
  const [search, setSearch] = useState('');

  const filteredCategories = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return CATEGORIES;
    return CATEGORIES.map((cat) => ({
      ...cat,
      items: cat.items.filter(([, title]) => title.toLowerCase().includes(q)),
    })).filter((cat) => cat.items.length > 0);
  }, [search]);

  // ---- 示例详情页 ----
  if (demo) {
    const [Demo, title] = demo;
    return (
      <View style={styles.fill}>
        <StatusBar barStyle="dark-content" />
        <Demo key={`${title}-${provider}`} provider={provider} />

        <View style={[styles.demoBackBtn, { top: SAFE_TOP + 8 }]}>
          <Pressable style={styles.demoBackInner} onPress={() => setDemo(null)}>
            <Text style={styles.demoBackArrow}>{'‹'}</Text>
            <Text style={styles.demoBackLabel}>返回</Text>
          </Pressable>
        </View>

        <View style={styles.demoTitleBadge}>
          <Text style={styles.demoTitleText} numberOfLines={1}>
            {title}
          </Text>
        </View>

        <View style={styles.demoProviderBar}>
          <View style={styles.demoProviderInner}>
            {PROVIDERS.map((p) => {
              const active = provider === p.key;
              return (
                <Pressable
                  key={p.key}
                  style={[
                    styles.demoChip,
                    active && {
                      backgroundColor: p.color,
                      borderColor: p.color,
                    },
                  ]}
                  onPress={() => setProvider(p.key)}
                >
                  <Text
                    style={[
                      styles.demoChipText,
                      active ? styles.demoChipTextActive : { color: p.color },
                    ]}
                  >
                    {p.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        </View>
      </View>
    );
  }

  // ---- 主页列表 ----
  // RNOH 的 SafeAreaView 会异步更新 insets 导致滚动容器 frame 变化、
  // 滚动位置被重置（表现为闪一下跳回顶部），改用 View + 固定 paddingTop。
  const ListWrapper = IS_HARMONY ? View : SafeAreaView;

  // 标题 / 搜索 / Provider 选择作为 FlatList 头部
  const listHeader = (
    <>
      <View style={styles.header}>
        <Text style={styles.title}>CN Maps</Text>
        <Text style={styles.subtitle}>react-native-cn-maps 示例集</Text>
      </View>

      <View style={styles.searchWrap}>
        <Text style={styles.searchIcon}>{'🔍'}</Text>
        <TextInput
          style={styles.searchInput}
          placeholder="搜索示例..."
          placeholderTextColor="#94A3B8"
          value={search}
          onChangeText={setSearch}
          clearButtonMode="while-editing"
          returnKeyType="search"
        />
      </View>

      <View style={styles.providerSection}>
        <Text style={styles.providerLabel}>地图服务</Text>
        <View style={styles.providerRow}>
          {PROVIDERS.map((p) => {
            const active = provider === p.key;
            return (
              <Tap
                key={p.key}
                style={[
                  styles.providerChip,
                  active && {
                    backgroundColor: p.color,
                    borderColor: p.color,
                  },
                ]}
                onPress={() => setProvider(p.key)}
              >
                <Text
                  style={[
                    styles.providerChipText,
                    active ? styles.providerChipTextActive : { color: p.color },
                  ]}
                >
                  {p.label}
                </Text>
              </Tap>
            );
          })}
        </View>
      </View>
    </>
  );

  return (
    <View style={styles.fill}>
      <StatusBar barStyle="dark-content" backgroundColor={COLORS.bg} />
      <ListWrapper style={styles.safeArea}>
        <FlatList
          style={styles.scrollView}
          data={filteredCategories}
          keyExtractor={(cat) => cat.title}
          renderItem={({ item: cat }) => (
            <View style={styles.section}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionIcon}>{cat.icon}</Text>
                <Text style={styles.sectionTitle}>{cat.title}</Text>
                <View style={styles.sectionBadge}>
                  <Text style={styles.sectionBadgeText}>
                    {cat.items.length}
                  </Text>
                </View>
              </View>
              <View style={styles.card}>
                {cat.items.map(([Comp, itemTitle], i) => (
                  <Tap
                    key={itemTitle}
                    style={[
                      styles.row,
                      i < cat.items.length - 1 && styles.rowBorder,
                    ]}
                    pressedStyle={styles.rowPressed}
                    onPress={() => setDemo([Comp, itemTitle])}
                  >
                    <Text style={styles.rowText}>{itemTitle}</Text>
                    <Text style={styles.rowChevron}>{'›'}</Text>
                  </Tap>
                ))}
              </View>
            </View>
          )}
          ListHeaderComponent={listHeader}
          ListEmptyComponent={
            <View style={styles.empty}>
              <Text style={styles.emptyIcon}>{'🔍'}</Text>
              <Text style={styles.emptyText}>没有匹配的示例</Text>
            </View>
          }
          ListFooterComponent={
            <View style={styles.footer}>
              <Text style={styles.footerText}>共 {TOTAL_COUNT} 个示例</Text>
            </View>
          }
          contentContainerStyle={
            IS_HARMONY ? styles.scrollContentHarmony : styles.scrollContent
          }
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
          // 分类总共只有 9 个节点：一次全部渲染、关闭裁剪与虚拟化回收，
          // 避免 RNOH 上滚动中增删子树引发闪帧
          initialNumToRender={CATEGORIES.length}
          windowSize={21}
          removeClippedSubviews={false}
        />
      </ListWrapper>
    </View>
  );
}

// ---- 常量与样式 ----

// RNOH 的 Platform.OS 是 'harmony'
const IS_HARMONY = (Platform.OS as string) === 'harmony';

const SAFE_TOP = IS_HARMONY
  ? 44
  : Platform.OS === 'android'
    ? (StatusBar.currentHeight ?? 0)
    : 54;

const COLORS = {
  bg: '#F1F5F9',
  card: '#FFFFFF',
  textPrimary: '#0F172A',
  textSecondary: '#64748B',
  textTertiary: '#94A3B8',
  divider: '#F1F5F9',
  searchBg: '#E2E8F0',
  accent: '#3B82F6',
};

const SHADOW = Platform.select({
  ios: {
    shadowColor: '#64748B',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.06,
    shadowRadius: 6,
  },
  android: {
    elevation: 2,
  },
  default: {},
});

const styles = StyleSheet.create({
  fill: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  safeArea: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  scrollView: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  scrollContent: {
    paddingBottom: 48,
  },
  scrollContentHarmony: {
    paddingBottom: 48,
    paddingTop: SAFE_TOP,
  },

  // 标题
  header: {
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 4,
  },
  title: {
    fontSize: 34,
    fontWeight: '800',
    color: COLORS.textPrimary,
    letterSpacing: -0.5,
  },
  subtitle: {
    fontSize: 15,
    color: COLORS.textSecondary,
    marginTop: 4,
  },

  // 搜索
  searchWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.searchBg,
    borderRadius: 12,
    marginHorizontal: 20,
    marginTop: 20,
    paddingHorizontal: 12,
    height: 44,
  },
  searchIcon: {
    fontSize: 14,
    marginRight: 8,
    opacity: 0.6,
  },
  searchInput: {
    flex: 1,
    fontSize: 16,
    color: COLORS.textPrimary,
    padding: 0,
  },

  // Provider 选择
  providerSection: {
    paddingHorizontal: 20,
    marginTop: 24,
  },
  providerLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: COLORS.textSecondary,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginBottom: 10,
  },
  providerRow: {
    flexDirection: 'row',
    gap: 8,
  },
  providerChip: {
    paddingVertical: 8,
    paddingHorizontal: 18,
    borderRadius: 20,
    borderWidth: 1.5,
    borderColor: '#CBD5E1',
    backgroundColor: COLORS.card,
  },
  providerChipText: {
    fontSize: 14,
    fontWeight: '600',
  },
  providerChipTextActive: {
    color: '#FFFFFF',
  },

  // 分类
  section: {
    marginTop: 28,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    marginBottom: 10,
  },
  sectionIcon: {
    fontSize: 16,
    marginRight: 6,
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '700',
    color: '#475569',
    flex: 1,
  },
  sectionBadge: {
    backgroundColor: '#E2E8F0',
    borderRadius: 10,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  sectionBadgeText: {
    fontSize: 12,
    fontWeight: '600',
    color: COLORS.textSecondary,
  },
  card: {
    backgroundColor: COLORS.card,
    marginHorizontal: 16,
    borderRadius: 14,
    overflow: IS_HARMONY ? 'visible' : ('hidden' as const),
    ...SHADOW,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
  },
  rowPressed: {
    backgroundColor: '#F1F5F9',
  },
  rowBorder: {
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E2E8F0',
  },
  rowText: {
    flex: 1,
    fontSize: 16,
    color: COLORS.textPrimary,
  },
  rowChevron: {
    fontSize: 22,
    color: '#CBD5E1',
    fontWeight: '300',
    marginLeft: 8,
  },

  // 空状态
  empty: {
    alignItems: 'center',
    paddingVertical: 64,
  },
  emptyIcon: {
    fontSize: 40,
    marginBottom: 12,
    opacity: 0.5,
  },
  emptyText: {
    fontSize: 16,
    color: COLORS.textTertiary,
  },

  // 底部
  footer: {
    alignItems: 'center',
    paddingVertical: 24,
  },
  footerText: {
    fontSize: 13,
    color: COLORS.textTertiary,
  },

  // ---- 示例详情页 ----
  demoBackBtn: {
    position: 'absolute',
    left: 12,
    zIndex: 10,
  },
  demoBackInner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255,255,255,0.9)',
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius: 22,
    ...SHADOW,
  },
  demoBackArrow: {
    fontSize: 24,
    color: COLORS.accent,
    fontWeight: '300',
    marginRight: 4,
    marginTop: -2,
  },
  demoBackLabel: {
    fontSize: 15,
    color: COLORS.accent,
    fontWeight: '600',
  },
  demoTitleBadge: {
    position: 'absolute',
    top: SAFE_TOP + 8,
    left: 100,
    right: 16,
    zIndex: 10,
    alignItems: 'flex-end',
  },
  demoTitleText: {
    fontSize: 14,
    fontWeight: '600',
    color: COLORS.textPrimary,
    backgroundColor: 'rgba(255,255,255,0.9)',
    paddingVertical: 8,
    paddingHorizontal: 14,
    borderRadius: 18,
    overflow: 'hidden',
    ...SHADOW,
  },
  demoProviderBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingTop: 12,
    paddingBottom: Platform.OS === 'ios' ? 34 : 16,
    paddingHorizontal: 16,
    backgroundColor: 'rgba(255,255,255,0.92)',
  },
  demoProviderInner: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 8,
  },
  demoChip: {
    paddingVertical: 7,
    paddingHorizontal: 16,
    borderRadius: 18,
    borderWidth: 1.5,
    borderColor: '#E2E8F0',
    backgroundColor: 'rgba(255,255,255,0.95)',
  },
  demoChipText: {
    fontSize: 13,
    fontWeight: '600',
  },
  demoChipTextActive: {
    color: '#FFFFFF',
  },
});
