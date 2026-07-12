/*
 * Tencent (腾讯地图) implementation of CnMapAdapter for HarmonyOS (RNOH). ArkTS port
 * of tencent/android `TencentMapAdapter.kt`. Coordinates from JS are GCJ-02 (腾讯默认)。
 *
 * 覆盖物 / 相机 / 事件 / 投影 / 截图 全部对接 @tencentmap/map 真实 API：
 *   - 覆盖物：new Marker/Line/Polygon/Circle(Options) → controller.addMarker/addLine/... (收对象，返回 boolean)
 *     注意：腾讯「折线」类名是 Line（非 Polyline）；线颜色在 param.segments[].color。
 *   - 相机：setCenter(lat,lng,animate) + setScaleLevel(level,animate) / moveCamera(latLngs,padding,animate)
 *   - 投影：geoToScreen(lat,lng)→Point / screenToGeo(x,y)→LatLng（腾讯 LatLng 字段是 lat/lng）
 *   - 截图：screenshot(rect): Promise<PixelMap>
 *   - 事件：controller.addMapClickListener/addMapLongPressListener/addPoiClickListener/
 *     addOnRegionChangeListener；单 marker 点击 marker.setOnClickListener。marker 无拖拽 API。
 * 控制器异步经 MapComponent.onReady 到达，config/markers/overlays 先 BUFFER，attachController 后 flush。
 */
import common from '@ohos.app.ability.common';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import {
  CnAddress, CnCamera, CnCircleModel, CnEdgeInsets, CnLatLng, CnMapAdapter, CnMapAdapterDelegate,
  CnMapAdapterFactory, CnMapBuilder, CnMarkerEvent, CnMarkerModel, CnOverlayModel, CnPoi, CnPolygonModel,
  CnPolylineModel, CnPressKind, CnRegion, CnPoint, OverlayHandle, CnMapAdapterRegistry
} from 'rn-cn-maps';
import {
  RNPackage, TurboModulesFactory, TurboModule, TurboModuleContext, RNPackageContext
} from '@rnoh/react-native-openharmony/ts';
import hilog from '@ohos.hilog';
import bundleManager from '@ohos.bundle.bundleManager';
import { BusinessError } from '@ohos.base';
// 真实腾讯鸿蒙 SDK：base=基础库(AuthService.setKey)；map=地图(组件/控制器/隐私/覆盖物类)。
import { AuthService } from '@tencentmap/base';
import {
  MapComponent, MapController, Privacy,
  Marker, Line, Polygon, Circle, LatLng, LineType, ImageSourceType
} from '@tencentmap/map';
import type {
  MarkerOptions, LineOptions, PolygonOptions, CircleOptions, NormalLineExtraParam, ImageEntity
} from '@tencentmap/map';

// 腾讯 Key 存放在宿主 example 的 module.json5 metadata（与 Android meta-data 同名）。
const TENCENT_KEY_METADATA = 'TencentMapSDK';
// 隐私合规 + setKey 全局只做一次；成功后置 true。
let tencentInitialized = false;
// 腾讯地图类型常量（MapType）：普通=0，卫星=1，暗色=2。
const MAP_TYPE_NORMAL = 0;
const MAP_TYPE_SATELLITE = 1;
const MAP_TYPE_DARK = 2;

// 从宿主应用 module.json5 metadata 读取腾讯 Key（复用高德/百度已验证的读法）。
function readTencentKey(): string {
  try {
    const info = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA);
    const modules = info.hapModulesInfo;
    for (let i = 0; i < modules.length; i++) {
      const metas = modules[i].metadata;
      for (let j = 0; j < metas.length; j++) {
        if (metas[j].name === TENCENT_KEY_METADATA) {
          return metas[j].value;
        }
      }
    }
  } catch (e) {
    hilog.error(0x0000, 'cnmaps', 'read tencent key failed: %{public}s', JSON.stringify(e));
  }
  return '';
}

// 腾讯 SDK 初始化：隐私合规(Privacy.setUserAgreePrivacy) + Key(AuthService.setKey)，必须在
// 地图组件挂载/鉴权前完成。幂等 once。
function ensureTencentInitialized(agreed: boolean): void {
  if (tencentInitialized) {
    return;
  }
  try {
    Privacy.setUserAgreePrivacy(agreed);
    if (!agreed) {
      return;
    }
    const key = readTencentKey();
    if (key.length === 0) {
      hilog.warn(0x0000, 'cnmaps', 'tencent key missing: 请在 module.json5 metadata 配置 TencentMapSDK');
      return;
    }
    AuthService.getInstance().setKey(key);
    tencentInitialized = true;
    hilog.info(0x0000, 'cnmaps', 'tencent SDK initialized (privacy agreed + key set)');
  } catch (e) {
    hilog.error(0x0000, 'cnmaps', 'tencent SDK init error: %{public}s', JSON.stringify(e));
  }
}

export class TencentMapAdapter implements CnMapAdapter {
  private context: common.Context;
  private controller: ESObject = null; // MapController；null until ready.
  private cachedDefaultIcon: ESObject = null; // 默认 marker 图标 PixelMap（从 rawfile 解码，缓存一次）。
  delegate: CnMapAdapterDelegate | null = null;

  readonly providerName: string = 'tencent';

  private pendingInitialRegion: CnRegion | null = null;
  private pendingInitialCamera: CnCamera | null = null;
  private didApplyInitialRegion = false;
  private didApplyInitialCamera = false;
  private isGesture = false;
  // MapComponent 的 onReady 可能多次回调，控制器只绑定一次。
  private didAttachController = false;

  private markerHandles: Map<string, OverlayHandle> = new Map();
  private overlayHandles: OverlayHandle[] = [];
  private markerModels: Map<OverlayHandle, CnMarkerModel> = new Map();
  private overlayModels: Map<OverlayHandle, CnOverlayModel> = new Map();
  private pendingAdds: OverlayHandle[] = [];

  constructor(context: common.Context) {
    this.context = context;
  }

  attachController(controller: ESObject): void {
    if (this.didAttachController) {
      return;
    }
    this.didAttachController = true;
    this.controller = controller;
    // 各步骤独立 try：某一步 API 若因 SDK 版本差异抛错，不影响其余步骤，保证底图 + 已成功的
    // 覆盖物照常渲染。
    try {
      this.configureListeners();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'tencent listeners error: %{public}s', (e as BusinessError).message ?? String(e));
    }
    const buffered = this.pendingAdds.slice();
    this.pendingAdds = [];
    buffered.forEach((handle) => {
      try {
        const marker = this.markerModels.get(handle);
        if (marker !== undefined) {
          handle.sdkObject = this.createSdkMarker(marker, handle.childId);
          return;
        }
        const overlay = this.overlayModels.get(handle);
        if (overlay !== undefined) {
          handle.sdkObject = this.buildOverlay(overlay);
        }
      } catch (e) {
        hilog.warn(0x0000, 'cnmaps', 'tencent overlay/marker skipped: %{public}s', (e as BusinessError).message ?? String(e));
      }
    });
    try {
      this.applyPendingInitial();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'tencent initial camera error: %{public}s', (e as BusinessError).message ?? String(e));
    }
    try {
      this.delegate?.onMapReady();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'tencent onMapReady delegate error: %{public}s', (e as BusinessError).message ?? String(e));
    }
  }

  isReady(): boolean { return this.controller !== null; }

  onResume(): void {}
  onPause(): void {}
  onDestroy(): void { this.controller = null; }
  onSizeChanged(): void { this.applyPendingInitial(); }
  didLayout(): void { this.applyPendingInitial(); }

  reset(): void {
    this.markerHandles.forEach((h) => { this.controller?.removeMarker?.(h.sdkObject); });
    this.overlayHandles.forEach((h) => {
      const model = this.overlayModels.get(h);
      if (model !== undefined) {
        this.removeSdkOverlay(h.sdkObject, model.kind);
      }
    });
    this.markerHandles.clear();
    this.markerModels.clear();
    this.overlayHandles = [];
    this.overlayModels.clear();
  }

  // Configuration --------------------------------------------------------------
  setMapType(value: string | null): void {
    this.controller?.setMapType?.((value === 'satellite' || value === 'hybrid') ? MAP_TYPE_SATELLITE : MAP_TYPE_NORMAL);
  }
  setUserInterfaceStyle(value: string | null): void { if (value === 'dark') { this.controller?.setMapType?.(MAP_TYPE_DARK); } }
  setMinZoomLevel(value: number): void { this.controller?.setMinScaleLevel?.(Math.round(value)); }
  setMaxZoomLevel(value: number): void { this.controller?.setMaxScaleLevel?.(Math.round(value)); }
  // 手势开关：真实 API 为 set*GestureEnable（无统一 UiSettings）。
  setZoomEnabled(value: boolean): void { this.controller?.setPinchGestureEnable?.(value); }
  setZoomControlEnabled(_value: boolean): void { /* 缩放控件为独立 UI，无 controller 开关 */ }
  setScrollEnabled(value: boolean): void { this.controller?.setMoveGestureEnable?.(value); }
  setRotateEnabled(value: boolean): void { this.controller?.setRotatedGestureEnable?.(value); }
  setPitchEnabled(value: boolean): void { this.controller?.setSkewGestureEnable?.(value); }
  setShowsUserLocation(value: boolean): void { this.controller?.setMyLocationEnabled?.(value); }
  setShowsMyLocationButton(_value: boolean): void { /* no direct toggle */ }
  setShowsCompass(_value: boolean): void { /* 指南针为独立 UI，无 controller 开关 */ }
  setShowsScale(_value: boolean): void { /* 比例尺为独立 UI，无 controller 开关 */ }
  setShowsTraffic(value: boolean): void { this.controller?.setTrafficEnable?.(value); }
  setShowsBuildings(value: boolean): void { this.controller?.setBuilding3dEffectEnable?.(value); }
  setShowsIndoors(value: boolean): void { this.controller?.setIndoorEnabled?.(value); }
  setShowsIndoorLevelPicker(_value: boolean): void { /* no direct toggle */ }
  setShowsPointsOfInterest(_value: boolean): void { /* 腾讯无直接 POI 开关 */ }

  // Viewport -------------------------------------------------------------------
  setInitialRegion(region: CnRegion): void {
    if (this.didApplyInitialRegion || this.didApplyInitialCamera) {
      return;
    }
    this.pendingInitialRegion = region;
    this.applyPendingInitial();
  }
  setRegion(region: CnRegion): void { this.moveToRegion(region, false, 0); }
  setInitialCamera(camera: CnCamera): void {
    if (this.didApplyInitialCamera) {
      return;
    }
    this.pendingInitialCamera = camera;
    this.applyPendingInitial();
  }
  setCamera(camera: CnCamera): void { this.moveToCamera(camera, false, 0); }
  animateToRegion(region: CnRegion, duration: number): void { this.moveToRegion(region, true, duration); }
  applyCamera(camera: CnCamera, animated: boolean, duration: number): void {
    let resolved = camera;
    if (camera.latitude === 0 && camera.longitude === 0 && this.controller !== null) {
      const t: ESObject = this.controller.getCenter();
      if (t !== null && t !== undefined) {
        resolved = {
          latitude: t.lat, longitude: t.lng,
          heading: camera.heading, pitch: camera.pitch, zoom: camera.zoom, altitude: camera.altitude,
        };
      }
    }
    this.moveToCamera(resolved, animated, duration);
  }

  currentRegion(): CnRegion | null {
    if (this.controller === null) {
      return null;
    }
    const c: ESObject = this.controller.getCenter();
    if (c === null || c === undefined) {
      return null;
    }
    const level: number = this.controller.getScaleLevel();
    // 由 scaleLevel 反推经纬度跨度（近似）。
    const delta = 360 / Math.pow(2, Math.max(1, level));
    return { latitude: c.lat, longitude: c.lng, latitudeDelta: delta, longitudeDelta: delta };
  }

  currentCamera(): CnCamera {
    if (this.controller === null) {
      return { latitude: 0, longitude: 0, heading: 0, pitch: 0, zoom: 0, altitude: 0 };
    }
    const c: ESObject = this.controller.getCenter();
    const level: number = this.controller.getScaleLevel();
    const rotate: number = this.controller.getRotate();
    const lat = (c !== null && c !== undefined) ? (c.lat as number) : 0;
    const lng = (c !== null && c !== undefined) ? (c.lng as number) : 0;
    return { latitude: lat, longitude: lng, heading: rotate, pitch: 0, zoom: level, altitude: 0 };
  }

  mapBoundaries(): [CnLatLng, CnLatLng] | null {
    // 腾讯需 getVisibleMapRect（MapRect 非经纬度 bounds），暂返回 null（parity TODO）。
    return null;
  }

  fitToCoordinates(coordinates: CnLatLng[], edgePadding: CnEdgeInsets, animated: boolean): void {
    if (coordinates.length === 0 || this.controller === null) {
      return;
    }
    // 真实 API：controller.moveCamera(latLngs, padding, animate) 自动拟合多点。
    const pts: ESObject = coordinates.map((c): ESObject => this.latLng(c));
    const padding = Math.max(edgePadding.top, edgePadding.bottom, edgePadding.left, edgePadding.right);
    this.controller.moveCamera(pts, padding, animated);
  }

  fitToMarkers(handles: OverlayHandle[], edgePadding: CnEdgeInsets, animated: boolean): void {
    const coords: CnLatLng[] = [];
    handles.forEach((h) => {
      const pos = this.markerPosition(h);
      if (pos !== null) {
        coords.push(pos);
      }
    });
    if (coords.length > 0) {
      this.fitToCoordinates(coords, edgePadding, animated);
    }
  }

  setMapBoundaries(_ne: CnLatLng, _sw: CnLatLng): void {
    // 真实 API 为 setRestrictMapRect(MapRect)，构造较复杂，暂不实现（parity TODO）。
  }

  // Projection -----------------------------------------------------------------
  pointForCoordinate(coordinate: CnLatLng): CnPoint | null {
    if (this.controller === null) {
      return null;
    }
    const p: ESObject = this.controller.geoToScreen(coordinate.latitude, coordinate.longitude);
    return (p !== null && p !== undefined) ? { x: p.x, y: p.y } : null;
  }

  coordinateForPoint(xPx: number, yPx: number): CnLatLng | null {
    if (this.controller === null) {
      return null;
    }
    const ll: ESObject = this.controller.screenToGeo(xPx, yPx);
    return (ll !== null && ll !== undefined) ? { latitude: ll.lat, longitude: ll.lng } : null;
  }

  // Snapshot -------------------------------------------------------------------
  takeSnapshot(width: number, height: number, format: string, quality: number, result: string, completion: (uri: string) => void): void {
    if (this.controller === null) {
      completion('');
      return;
    }
    // 真实 API：controller.screenshot(rect): Promise<PixelMap | undefined>。
    const rect: ESObject = { left: 0, top: 0, right: width > 0 ? width : 1080, bottom: height > 0 ? height : 1920 };
    const p: ESObject = this.controller.screenshot(rect);
    if (p !== null && p !== undefined && typeof p.then === 'function') {
      p.then((pixelMap: image.PixelMap) => {
        if (pixelMap === undefined || pixelMap === null) {
          completion('');
          return;
        }
        this.encodeSnapshot(pixelMap, width, height, format, quality, result).then((uri) => completion(uri)).catch(() => completion(''));
      }).catch((_e: ESObject) => completion(''));
    } else {
      completion('');
    }
  }

  private async encodeSnapshot(pixelMap: image.PixelMap, _width: number, _height: number, format: string, quality: number, result: string): Promise<string> {
    try {
      const isJpg = format === 'jpg' || format === 'jpeg';
      const q = Math.round(Math.max(0, Math.min(1, quality)) * 100);
      const packer = image.createImagePacker();
      const opts: image.PackingOption = { format: isJpg ? 'image/jpeg' : 'image/png', quality: q };
      const data: ArrayBuffer = await packer.packing(pixelMap, opts);
      if (result === 'base64') {
        return new util.Base64Helper().encodeToStringSync(new Uint8Array(data));
      }
      const path = `${this.context.cacheDir}/map-snapshot-${Date.now()}.${isJpg ? 'jpg' : 'png'}`;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, data);
      fs.closeSync(file);
      return `file://${path}`;
    } catch (_e) {
      return '';
    }
  }

  addressForCoordinate(_latitude: number, _longitude: number, completion: (address: CnAddress | null) => void): void {
    completion(null); // No bundled geocoder in this adapter (parity with Kotlin).
  }

  // Markers --------------------------------------------------------------------
  addMarker(model: CnMarkerModel, childId: string): OverlayHandle {
    const handle = new OverlayHandle(childId);
    this.markerHandles.set(childId, handle);
    this.markerModels.set(handle, model);
    if (this.controller === null) {
      this.pendingAdds.push(handle);
    } else {
      handle.sdkObject = this.createSdkMarker(model, childId);
    }
    return handle;
  }

  private createSdkMarker(model: CnMarkerModel, childId: string): ESObject {
    // 真实 API：new Marker(MarkerOptions) → controller.addMarker(marker)。腾讯 marker 无 draggable。
    const opt: MarkerOptions = {
      position: this.latLng({ latitude: model.latitude, longitude: model.longitude }) as LatLng,
      rotate: model.rotation,
      alpha: model.opacity,
      clickable: true,
      zIndex: Math.round(model.zIndex),
    };
    const icon = this.descriptorFor(model);
    if (icon !== undefined) {
      opt.icon = icon;
    }
    const marker: ESObject = new Marker(opt);
    marker.setUserTag(childId);
    // 单个 marker 点击事件（真实 API：marker.setOnClickListener）。
    const coord: CnLatLng = { latitude: model.latitude, longitude: model.longitude };
    marker.setOnClickListener((_event: ESObject) => {
      this.delegate?.onMarkerEvent(childId, CnMarkerEvent.PRESS, coord);
      this.delegate?.onMarkerEvent(childId, CnMarkerEvent.SELECT, coord);
    });
    const ok: ESObject = this.controller.addMarker(marker);
    return marker;
  }

  updateMarker(handle: OverlayHandle, model: CnMarkerModel): void {
    // 腾讯 Marker 无位置/属性 setter，更新 = 移除旧的 + 重建。
    this.markerModels.set(handle, model);
    if (this.controller === null) {
      return;
    }
    const old: ESObject = handle.sdkObject;
    if (old !== null) {
      this.controller.removeMarker?.(old);
    }
    handle.sdkObject = this.createSdkMarker(model, handle.childId);
  }

  removeMarker(handle: OverlayHandle): void {
    this.controller?.removeMarker?.(handle.sdkObject);
    this.markerHandles.delete(handle.childId);
    this.markerModels.delete(handle);
  }

  showCallout(_handle: OverlayHandle): void { /* 腾讯 InfoWindow 需 marker.showInfoWindow + 配置，TODO */ }
  hideCallout(_handle: OverlayHandle): void { /* no-op until InfoWindow wired */ }
  redrawCallout(_handle: OverlayHandle): void { /* no-op until InfoWindow wired */ }

  animateMarker(handle: OverlayHandle, latitude: number, longitude: number, duration: number): void {
    const marker: ESObject = handle.sdkObject;
    const model = this.markerModels.get(handle);
    if (marker === null || this.controller === null || model === undefined) {
      return;
    }
    // 真实 API：moveAlong(marker, {paths, duration, distanceDelta}) 沿路径动画到目标点。
    const from: ESObject = this.latLng({ latitude: model.latitude, longitude: model.longitude });
    const to: ESObject = this.latLng({ latitude, longitude });
    this.controller.moveAlong?.(marker, { paths: [from, to], duration: Math.max(1, duration), distanceDelta: 0 });
  }

  markerScreenPoint(handle: OverlayHandle): CnPoint | null {
    const model = this.markerModels.get(handle);
    if (model === undefined || this.controller === null) {
      return null;
    }
    const p: ESObject = this.controller.geoToScreen(model.latitude, model.longitude);
    return (p !== null && p !== undefined) ? { x: p.x, y: p.y } : null;
  }

  markerPosition(handle: OverlayHandle): CnLatLng | null {
    // 腾讯 Marker 无 getPosition，从缓存的 model 取。
    const model = this.markerModels.get(handle);
    return model !== undefined ? { latitude: model.latitude, longitude: model.longitude } : null;
  }

  private descriptorFor(model: CnMarkerModel): ImageEntity | undefined {
    if (model.customBitmap !== null) {
      return { uri: model.customBitmap as image.PixelMap, type: ImageSourceType.PixelMap };
    }
    if (model.iconBitmap !== null) {
      return { uri: model.iconBitmap as image.PixelMap, type: ImageSourceType.PixelMap };
    }
    // ⚠️ 腾讯 SDK 无内置默认 pin，无 icon 的 marker 永不 LOADING_FINISH → 不可见。
    // RawFile uri 加载会报 nativeImageSource=null，改用从 rawfile 同步解码的 PixelMap 直传更可靠。
    const def: ESObject = this.defaultMarkerPixelMap();
    if (def !== null && def !== undefined) {
      return { uri: def as image.PixelMap, type: ImageSourceType.PixelMap };
    }
    return undefined;
  }

  // 从宿主 rawfile 同步解码默认 marker 图为 PixelMap（缓存一次）。
  private defaultMarkerPixelMap(): ESObject {
    if (this.cachedDefaultIcon !== null) {
      return this.cachedDefaultIcon;
    }
    try {
      const rm: ESObject = this.context.resourceManager;
      const data: ESObject = rm.getRawFileContentSync('cnmaps_default_marker.png');
      const source: ESObject = image.createImageSource(data.buffer as ArrayBuffer);
      this.cachedDefaultIcon = source.createPixelMapSync();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'tencent default marker load failed: %{public}s', (e as BusinessError).message ?? String(e));
    }
    return this.cachedDefaultIcon;
  }

  // Overlays -------------------------------------------------------------------
  addOverlay(model: CnOverlayModel, childId: string): OverlayHandle {
    const handle = new OverlayHandle(childId);
    this.overlayHandles.push(handle);
    this.overlayModels.set(handle, model);
    if (this.controller === null) {
      this.pendingAdds.push(handle);
    } else {
      handle.sdkObject = this.buildOverlay(model);
    }
    return handle;
  }

  updateOverlay(handle: OverlayHandle, model: CnOverlayModel): void {
    const oldModel = this.overlayModels.get(handle);
    if (oldModel !== undefined) {
      this.removeSdkOverlay(handle.sdkObject, oldModel.kind);
    }
    handle.sdkObject = this.controller !== null ? this.buildOverlay(model) : null;
    this.overlayModels.set(handle, model);
  }

  removeOverlay(handle: OverlayHandle): void {
    const model = this.overlayModels.get(handle);
    if (model !== undefined) {
      this.removeSdkOverlay(handle.sdkObject, model.kind);
    }
    this.overlayHandles = this.overlayHandles.filter((h) => h !== handle);
    this.overlayModels.delete(handle);
  }

  // 腾讯无泛型 removeOverlay，按类型调对应的 removeLine/removePolygon/removeCircle。
  private removeSdkOverlay(sdk: ESObject, kind: string): void {
    const c: ESObject = this.controller;
    if (c === null || sdk === null || sdk === undefined) {
      return;
    }
    if (kind === 'polyline') {
      c.removeLine?.(sdk);
    } else if (kind === 'polygon') {
      c.removePolygon?.(sdk);
    } else if (kind === 'circle') {
      c.removeCircle?.(sdk);
    }
  }

  private buildOverlay(model: CnOverlayModel): ESObject {
    switch (model.kind) {
      case 'polyline': return this.buildPolyline(model);
      case 'polygon': return this.buildPolygon(model);
      case 'circle': return this.buildCircle(model);
      // GroundOverlay / Heatmap / tiles 用版本相关 API — TODO（parity with Android）。
      default: return null;
    }
  }

  private buildPolyline(model: CnPolylineModel): ESObject {
    if (model.coordinates.length < 2) {
      return null;
    }
    // 真实 API：new Line(LineOptions) → controller.addLine。颜色在 param.segments[].color。
    const pts: ESObject = model.coordinates.map((c): ESObject => this.latLng(c));
    const col = model.strokeColors.length > 0 ? model.strokeColors[0] : model.strokeColor;
    const param: NormalLineExtraParam = { segments: [{ color: this.colorToHex(col) }] };
    const opt: LineOptions = {
      points: pts as LatLng[],
      width: Math.round(model.strokeWidth),
      lineType: LineType.NormalLine,
      param,
      zIndex: Math.round(model.zIndex),
    };
    const line: ESObject = new Line(opt);
    const ok: ESObject = this.controller.addLine(line);
    return line;
  }

  private buildPolygon(model: CnPolygonModel): ESObject {
    if (model.coordinates.length < 3) {
      return null;
    }
    // 真实 API：new Polygon(PolygonOptions{points, fillColor(必), strokeColor, strokeWidth}) → addPolygon。
    const pts: ESObject = model.coordinates.map((c): ESObject => this.latLng(c));
    const opt: PolygonOptions = {
      points: pts as LatLng[],
      fillColor: this.colorToHex(model.fillColor),
      strokeColor: this.colorToHex(model.strokeColor),
      strokeWidth: Math.round(model.strokeWidth),
      zIndex: Math.round(model.zIndex),
    };
    const poly: ESObject = new Polygon(opt);
    const ok: ESObject = this.controller.addPolygon(poly);
    return poly;
  }

  private buildCircle(model: CnCircleModel): ESObject {
    // 真实 API：new Circle(CircleOptions{center(必), radius(必), fillColor, strokeColor, strokeWidth}) → addCircle。
    const opt: CircleOptions = {
      center: this.latLng(model.center) as LatLng,
      radius: model.radius,
      fillColor: this.colorToHex(model.fillColor),
      strokeColor: this.colorToHex(model.strokeColor),
      strokeWidth: Math.round(model.strokeWidth),
      zIndex: Math.round(model.zIndex),
    };
    const circle: ESObject = new Circle(opt);
    const ok: ESObject = this.controller.addCircle(circle);
    return circle;
  }

  // Listeners ------------------------------------------------------------------
  private configureListeners(): void {
    const c: ESObject = this.controller;
    if (c === null) {
      return;
    }
    // 地图点击/长按（真实 API：addMapClickListener/addMapLongPressListener）。MapEvent.position 为 LatLng(lat/lng)。
    c.addMapClickListener((evt: ESObject) => {
      const pos: ESObject = evt?.position;
      if (pos !== undefined && pos !== null) {
        this.delegate?.onMapPress(CnPressKind.PRESS, { latitude: pos.lat, longitude: pos.lng }, this.screenPoint(pos));
      }
    });
    c.addMapLongPressListener((evt: ESObject) => {
      const pos: ESObject = evt?.position;
      if (pos !== undefined && pos !== null) {
        this.delegate?.onMapPress(CnPressKind.LONG_PRESS, { latitude: pos.lat, longitude: pos.lng }, this.screenPoint(pos));
      }
    });
    // POI 点击（MapPoi.position 为 LatLng）。
    c.addPoiClickListener((poi: ESObject) => {
      const pos: ESObject = poi?.position;
      if (pos !== undefined && pos !== null) {
        this.delegate?.onPoiClick({ placeId: poi.poiId ?? null, name: poi.name ?? null, latitude: pos.lat, longitude: pos.lng });
      }
    });
    // 相机/区域变化（回调带 animated + bGesture）。
    c.addOnRegionChangeListener({
      onRegionWillChangeAnimated: (_animated: boolean, bGesture: boolean) => this.delegate?.onRegionChange(false, bGesture),
      onRegionDidChangeAnimated: (_animated: boolean, bGesture: boolean) => this.delegate?.onRegionChange(true, bGesture),
    });
    // logo 合规强制显示（SDK 无隐藏 API，只能移位）：显式摆到左下角可见位置，避免默认位置被
    // XComponent 底部裁掉。PositionAnchor.BottomLeft = 1；margin 为像素。比例尺也放左下靠上。
    c.setLogoPosition?.(1, { x: 12, y: 24 });
    c.setScaleViewPosition?.(1, { x: 12, y: 72 });
    try {
      const lp: ESObject = c.getLogoPosition?.();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'tencent DIAG getLogoPosition err=%{public}s', (e as BusinessError).message ?? String(e));
    }
    // marker 点击已在 createSdkMarker 内逐个绑定（marker.setOnClickListener）；腾讯无 marker 拖拽 API。
  }

  // Helpers --------------------------------------------------------------------
  private applyPendingInitial(): void {
    if (this.controller === null) {
      return;
    }
    if (this.pendingInitialRegion !== null) {
      const region = this.pendingInitialRegion;
      this.pendingInitialRegion = null;
      this.didApplyInitialRegion = true;
      this.moveToRegion(region, false, 0);
    }
    if (this.pendingInitialCamera !== null) {
      const camera = this.pendingInitialCamera;
      this.pendingInitialCamera = null;
      this.didApplyInitialCamera = true;
      this.moveToCamera(camera, false, 0);
    }
  }

  private moveToRegion(region: CnRegion, animated: boolean, _duration: number): void {
    if (this.controller === null) {
      return;
    }
    // 真实 API：setCenter(lat, lng, animate) + setScaleLevel(level, animate)。level 由 delta 反推。
    this.controller.setCenter(region.latitude, region.longitude, animated);
    const level = this.scaleForDelta(region.longitudeDelta);
    this.controller.setScaleLevel(level, animated);
  }

  private moveToCamera(camera: CnCamera, animated: boolean, _duration: number): void {
    if (this.controller === null) {
      return;
    }
    this.controller.setCenter(camera.latitude, camera.longitude, animated);
    if (camera.zoom > 0) {
      this.controller.setScaleLevel(Math.round(camera.zoom), animated);
    }
  }

  private scaleForDelta(longitudeDelta: number): number {
    if (longitudeDelta <= 0) {
      return 16;
    }
    // 腾讯 scaleLevel 视野比 Google zoom 偏大（同 delta 更远），+2 校准让初始视野贴近 region。
    const level = Math.round(Math.log2(360 / longitudeDelta)) + 2;
    return Math.max(3, Math.min(20, level));
  }

  private screenPoint(ll: ESObject): CnPoint | null {
    if (this.controller === null || ll === null || ll === undefined) {
      return null;
    }
    const p: ESObject = this.controller.geoToScreen(ll.lat, ll.lng);
    return (p !== null && p !== undefined) ? { x: p.x, y: p.y } : null;
  }

  private latLng(c: CnLatLng): ESObject { return new LatLng(c.latitude, c.longitude); }

  // RN processColor 的 ARGB int → 腾讯/ArkUI 覆盖物要求的 "#AARRGGBB"（alpha 在前！）颜色字符串。
  // ⚠️ 不是 #RRGGBBAA——alpha 放末尾会被 SDK 当 #AARRGGBB 解析，默认不透明黑边框会变全透明而不可见。
  private colorToHex(argb: number): string {
    const a = (argb >>> 24) & 0xff;
    const r = (argb >>> 16) & 0xff;
    const g = (argb >>> 8) & 0xff;
    const b = argb & 0xff;
    return `#${this.hex2(a)}${this.hex2(r)}${this.hex2(g)}${this.hex2(b)}`;
  }

  private hex2(n: number): string {
    const s = n.toString(16);
    return s.length < 2 ? `0${s}` : s;
  }
}

// ArkUI builder：渲染真实腾讯地图（@tencentmap/map MapComponent），onReady 交付 MapController。
@Builder
function tencentMapBuilder(adapter: CnMapAdapter) {
  MapComponent({
    // AsyncCallback<MapController>：地图就绪交付控制器。底图由 MapComponent 自渲染，不依赖
    // attachController；onReady 个别带 err 仅告警不阻断（attachController 内部再幂等保护）。
    onReady: (err: BusinessError, controller: MapController) => {
      if (err) {
        hilog.warn(0x0000, 'cnmaps', 'tencent MapComponent onReady error (map still renders): %{public}s',
          err.message ?? String(err));
        return;
      }
      (adapter as TencentMapAdapter).attachController(controller);
    },
    // 鉴权结果回调：便于诊断 Key 是否有效（ok=false 表示鉴权失败，会白屏）。
    onAuthCallback: (err: BusinessError, ok: boolean) => {
      hilog.info(0x0000, 'cnmaps', 'tencent auth callback: ok=%{public}s err=%{public}s',
        ok ? 'true' : 'false', err ? (err.message ?? String(err)) : 'none');
    },
  })
    .width('100%')
    .height('100%')
}

class TencentFactory implements CnMapAdapterFactory {
  readonly providerName: string = 'tencent';

  create(context: common.Context): CnMapAdapter {
    // 腾讯 SDK 初始化(隐私+Key)必须在地图组件鉴权前；adapter 创建早于组件挂载，这里兜底一次。
    ensureTencentInitialized(true);
    return new TencentMapAdapter(context);
  }

  mapBuilder(): CnMapBuilder {
    return wrapBuilder(tencentMapBuilder);
  }

  applyPrivacyConsent(_context: common.Context, agreed: boolean, _contains: boolean, _shown: boolean): void {
    // 腾讯：隐私合规(Privacy.setUserAgreePrivacy) + Key(AuthService.setKey)。由 JS 侧
    // setPrivacyConsent 经 CnMapAdapterRegistry 分发触发；与 create() 双保险，幂等只跑一次。
    ensureTencentInitialized(agreed);
  }
}

export const TencentMapAdapterFactory: CnMapAdapterFactory = new TencentFactory();

class EmptyTurboModulesFactory extends TurboModulesFactory {
  createTurboModule(_name: string): TurboModule | null { return null; }
  hasTurboModule(_name: string): boolean { return false; }
}

export class TencentPackage extends RNPackage {
  constructor(ctx: RNPackageContext) {
    super(ctx);
    CnMapAdapterRegistry.register(TencentMapAdapterFactory);
  }

  createTurboModulesFactory(ctx: TurboModuleContext): TurboModulesFactory {
    return new EmptyTurboModulesFactory(ctx);
  }
}
