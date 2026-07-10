/*
 * Descriptor / props types for the `RNMapsMapView` Fabric component on HarmonyOS.
 *
 * Mirrors the codegen-facing shape declared in core JS
 * `src/MapViewNativeComponent.ts` (NativeProps). When `codegen-harmony` runs over
 * the JS spec it generates the authoritative props type; this hand-written mirror
 * lets the host compile ahead of codegen and documents the exact prop surface.
 *
 * 查证: import path of `Descriptor`/`ViewBaseProps` for the pinned RNOH 0.72 line
 * (DevEco resolves them from `@rnoh/react-native-openharmony`). Replace this mirror
 * with the codegen-generated props type once `codegen-harmony` is wired (P1).
 */
import { Descriptor, ViewBaseProps } from '@rnoh/react-native-openharmony';

export interface NativeRegionProp {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
}

export interface NativeCameraProp {
  latitude: number;
  longitude: number;
  heading: number;
  pitch: number;
  zoom: number;
  altitude: number;
}

export interface NativeEdgePaddingProp {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

export interface RNMapsMapViewProps extends ViewBaseProps {
  provider: string;
  coordinateSystem: string;

  // Region / camera
  initialRegion?: NativeRegionProp;
  region?: NativeRegionProp;
  initialCamera?: NativeCameraProp;
  camera?: NativeCameraProp;

  // 以下带 WithDefault 的 prop 全部标为可选：RNOH 自定义 arkTS 组件不经生成的 PropsSelector，
  // descriptor.props 只带 JS 显式传入的字段，未传的到这里就是 undefined（与生成的 DirectRawProps
  // 一致，均为可选）。默认值由 CnMapHostController.applyProps 按 JS spec 补齐。

  // Appearance
  mapType?: string;
  customMapStyle?: string;
  userInterfaceStyle?: string;
  tintColor?: number;
  mapPadding?: NativeEdgePaddingProp;
  kmlSrc?: string;

  // Zoom
  minZoomLevel?: number;
  maxZoomLevel?: number;

  // Gesture toggles
  zoomEnabled?: boolean;
  zoomTapEnabled?: boolean;
  zoomControlEnabled?: boolean;
  scrollEnabled?: boolean;
  scrollDuringRotateOrZoomEnabled?: boolean;
  rotateEnabled?: boolean;
  pitchEnabled?: boolean;

  // Display toggles
  showsUserLocation?: boolean;
  showsMyLocationButton?: boolean;
  showsCompass?: boolean;
  showsScale?: boolean;
  showsTraffic?: boolean;
  showsBuildings?: boolean;
  showsIndoors?: boolean;
  showsIndoorLevelPicker?: boolean;
  showsPointsOfInterest?: boolean;

  // Loading state
  loadingEnabled?: boolean;
  loadingIndicatorColor?: number;
  loadingBackgroundColor?: number;

  // Android-only (accepted for parity; HarmonyOS aligns to AMap capability or ignores)
  toolbarEnabled?: boolean;
  liteMode?: boolean;
  cacheEnabled?: boolean;
}

// State is unused by this component (the provider map owns its own state).
export interface RNMapsMapViewState {}

export type RNMapsMapViewDescriptor = Descriptor<'RNMapsMapView', RNMapsMapViewProps, RNMapsMapViewState>;

export const RN_MAPS_MAP_VIEW_TYPE: string = 'RNMapsMapView';
