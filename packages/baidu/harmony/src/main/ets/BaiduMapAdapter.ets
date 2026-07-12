/*
 * Baidu (百度地图) implementation of CnMapAdapter for HarmonyOS (RNOH). ArkTS port
 * of baidu/android `BaiduMapAdapter.kt`.
 *
 * 覆盖物 / 相机 / 事件 / 投影 / 截图 全部对接 @bdmap/map 的真实鸿蒙 API：
 *   - 覆盖物：new Marker/Polyline/Polygon/Circle(IOption) → controller.addOverlay(overlay)
 *   - 相机：controller.setMapCenter(center, zoom, animate, time) / setViewport(points, opt)
 *   - 投影：controller.ll2pixel(latLng) / pixel2ll(x, y)
 *   - 截图：controller.snapshot() : Promise<PixelMap>
 *   - 事件：controller.addEventListener(MapEvent.*) / overlay.addEventListener(OverlayEvent.CLICK)
 * 控制器异步经 MapComponent.onReady 到达，故 config/markers/overlays 先 BUFFER，
 * attachController() 后再 flush。controller 声明为 ESObject（动态）：不存在的可选
 * UI setter 用 `?.()` 自然短路 no-op，不会抛错。
 *
 * 注意：JS 侧坐标为 GCJ-02，百度底图是 BD-09，存在约百米级偏移（坐标转换见 TODO）。
 */
import common from '@ohos.app.ability.common';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import bundleManager from '@ohos.bundle.bundleManager';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';
import {
  CnAddress, CnCamera, CnCircleModel, CnEdgeInsets, CnGroundOverlayModel, CnLatLng, CnMapAdapter,
  CnMapAdapterDelegate, CnMapAdapterFactory, CnMapBuilder, CnMarkerEvent, CnMarkerModel, CnOverlayModel,
  CnPoi, CnPolygonModel, CnPolylineModel, CnPressKind, CnRegion, CnUserLocation, CnPoint, OverlayHandle,
  CnMapAdapterRegistry
} from 'rn-cn-maps';
import {
  RNPackage, TurboModulesFactory, TurboModule, TurboModuleContext, RNPackageContext
} from '@rnoh/react-native-openharmony/ts';
// 百度鸿蒙地图 SDK 初始化 + 隐私合规入口（@bdmap/base）。
import { Initializer, MapSDKConfigBuilder, LatLng } from '@bdmap/base';
// 真实地图 ArkUI 组件 + 控制器 + 覆盖物类 + 事件枚举 + 图像类（均在 @bdmap/map Index.d.ets 导出）。
import {
  MapComponent, MapController, MapOptions, MapStatus,
  Marker, Polyline, Polygon, Circle, Stroke, OverlayEvent, MapEvent, ImageEntity
} from '@bdmap/map';
import type {
  IMarkerOption, IPolylineOption, IPolygonOption, ICircleOption, IStrokeOption
} from '@bdmap/map';

const CHILD_ID = 'cn_child_id';
// 百度地图类型常量（@bdmap/map SysEnum.MapType）：普通=1，卫星=2。
const MAP_TYPE_NORMAL = 1;
const MAP_TYPE_SATELLITE = 2;

// 百度 AK 存放在 example 的 module.json5 metadata 里（与 Android manifest meta-data 同名）。
const BAIDU_AK_METADATA = 'com.baidu.lbsapi.API_KEY';
// SDK 初始化只做一次；initialize 成功后置为 true，避免隐私声明多次触发重复初始化。
let baiduInitialized = false;
// 百度 MapController 为进程级单例（q10.d.ets static instance）：camera/region prop 变化会触发
// host CnMapHostComponent 重建 → 新 BaiduMapAdapter + 新 MapComponent，但新 MapComponent 的
// onReady 因单例已存在而不再触发 → 新 adapter 无 controller、地图空白。用模块级引用保存首个
// controller，re-mount 后新 adapter 复用它（见 ensureSharedController）。
let sharedBaiduController: ESObject = null;

// 从应用 module.json5 的 metadata 读取百度 AK。对应 Android 端由 SDKInitializer
// 自动读取 manifest 里的 com.baidu.lbsapi.API_KEY meta-data。
function readBaiduAk(): string {
  try {
    // 注意：metadata 挂在 hapModulesInfo 下，必须同时带 WITH_HAP_MODULE 才会被填充，
    // 只给 WITH_METADATA 会拿到空的 hapModulesInfo。
    const info = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA);
    const modules = info.hapModulesInfo;
    for (let i = 0; i < modules.length; i++) {
      const metas = modules[i].metadata;
      for (let j = 0; j < metas.length; j++) {
        if (metas[j].name === BAIDU_AK_METADATA) {
          return metas[j].value;
        }
      }
    }
  } catch (e) {
    hilog.error(0x0000, 'cnmaps', 'read baidu AK failed: %{public}s', JSON.stringify(e));
  }
  return '';
}

export class BaiduMapAdapter implements CnMapAdapter {
  private context: common.Context;
  private controller: ESObject = null; // MapController；null until ready.
  // 缓存初始 MapOptions：host build() 在 camera/region prop 变化时会重跑，若每次返回新
  // MapOptions 会让百度 MapComponent 重建、而重建后其 onReady 不再触发 → 地图空白。缓存后
  // 引用稳定，MapComponent 不重建，地图存活，视口移动交给 setCamera/animateToRegion。
  private cachedInitialMapOptions: MapOptions | null = null;
  delegate: CnMapAdapterDelegate | null = null;

  readonly providerName: string = 'baidu';

  private pendingInitialRegion: CnRegion | null = null;
  private pendingInitialCamera: CnCamera | null = null;
  private didApplyInitialRegion = false;
  private didApplyInitialCamera = false;
  // MapComponent 的 onReady/onLoad 可能多次回调，控制器只绑定一次。
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
    sharedBaiduController = controller;
    // 各步骤独立 try：某一步真实 API 若因 SDK 版本差异抛错，不影响其余步骤，保证底图 + 已成功
    // 的覆盖物照常渲染。
    try {
      this.configureListeners();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'baidu listeners error: %{public}s', (e as BusinessError).message ?? String(e));
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
        hilog.warn(0x0000, 'cnmaps', 'baidu overlay/marker skipped: %{public}s', (e as BusinessError).message ?? String(e));
      }
    });
    try {
      this.applyPendingInitial();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'baidu initial camera error: %{public}s', (e as BusinessError).message ?? String(e));
    }
    try {
      this.delegate?.onMapReady();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'baidu onMapReady delegate error: %{public}s',
        (e as BusinessError).message ?? String(e));
    }
  }

  // 供 builder 构造真实地图的初始状态（MapOptions）。优先用 pending 的 initialRegion/
  // Camera；latitudeDelta → 近似 zoom（百度 zoom 范围约 3–21）。
  buildInitialMapOptions(): MapOptions {
    if (this.cachedInitialMapOptions !== null) {
      return this.cachedInitialMapOptions;
    }
    let lat = 39.914935;
    let lng = 116.403119;
    let zoom = 11;
    const region = this.pendingInitialRegion;
    const camera = this.pendingInitialCamera;
    if (region !== null) {
      lat = region.latitude;
      lng = region.longitude;
      zoom = this.zoomForDelta(region.longitudeDelta);
    } else if (camera !== null) {
      lat = camera.latitude;
      lng = camera.longitude;
      if (camera.zoom > 0) {
        zoom = camera.zoom;
      }
    }
    const opts: MapOptions = new MapOptions({ mapStatus: new MapStatus({ center: new LatLng(lat, lng), zoom }) });
    this.cachedInitialMapOptions = opts;
    return opts;
  }

  private zoomForDelta(longitudeDelta: number): number {
    if (longitudeDelta <= 0) {
      return 13;
    }
    // 百度 zoom 级别比 Google/高德偏小（同一经度跨度视野更大），+2 校准让视野贴近 region。
    const z = Math.round(Math.log2(360 / longitudeDelta)) + 2;
    return Math.max(4, Math.min(21, z));
  }

  isReady(): boolean { return this.controller !== null; }

  onResume(): void {}
  onPause(): void {}
  onDestroy(): void {
    // 释放百度地图实例：re-mount 时若旧 MapComponent 未释放会占用 SDK 资源，导致新实例 onReady 不触发。
    (this.controller as ESObject)?.onWillDisappear?.();
    this.controller = null;
  }
  onSizeChanged(): void { this.ensureSharedController(); this.applyPendingInitial(); }
  didLayout(): void { this.ensureSharedController(); this.applyPendingInitial(); }

  // re-mount 后新 adapter 的 MapComponent onReady 不触发（百度 controller 单例）：复用模块级
  // controller，重新 flush 覆盖物 + 恢复视口（attachController 内的 didAttachController 幂等保护）。
  private ensureSharedController(): void {
    if (this.controller === null && sharedBaiduController !== null) {
      // re-mount（camera/region prop 变化触发 host 组件重建）后，新 MapComponent 的 onReady 不再
      // 触发（百度 MapController 是进程级单例）：复用模块级 controller，让命令式相机 + 覆盖物在
      // 新 adapter 上继续可用（Back to Shanghai 等命令依赖此复用）。
      // ⚠️ 已知限制：声明式 camera/region prop 变化触发的 re-mount，其即时视口无法可靠渲染新
      // surface（SDK 单例 + RNOH 重建冲突，实测延迟重试 / isAnimate / refresh 均不稳定，会出现
      // 空白或黑屏）。受控相机请改用命令式 animateCamera / animateToRegion（不触发 re-mount，正常）。
      this.attachController(sharedBaiduController);
    }
  }

  reset(): void {
    this.markerHandles.forEach((h) => { (h.sdkObject as ESObject)?.remove?.(); });
    this.overlayHandles.forEach((h) => { (h.sdkObject as ESObject)?.remove?.(); });
    this.markerHandles.clear();
    this.markerModels.clear();
    this.overlayHandles = [];
    this.overlayModels.clear();
  }

  // Configuration --------------------------------------------------------------
  setMapType(value: string | null): void {
    // controller 为 ESObject：setMapType 接受 MapType（number），直接传常量。
    this.controller?.setMapType?.((value === 'satellite' || value === 'hybrid') ? MAP_TYPE_SATELLITE : MAP_TYPE_NORMAL);
  }
  setUserInterfaceStyle(_value: string | null): void { /* Baidu night needs a custom style file */ }
  setMinZoomLevel(value: number): void { this.controller?.setMinZoom?.(value); }
  setMaxZoomLevel(value: number): void { this.controller?.setMaxZoom?.(value); }
  // 手势开关：真实 API 为 enableGestures*/disableGestures*（无统一 UiSettings）。
  setZoomEnabled(value: boolean): void { if (value) { this.controller?.enableGesturesZoom?.(); } else { this.controller?.disableGesturesZoom?.(); } }
  setZoomControlEnabled(_value: boolean): void { /* 缩放控件为独立 UI（BMScaleBarView 之类），无 controller 开关 */ }
  setScrollEnabled(value: boolean): void { if (value) { this.controller?.enableGesturesDrag?.(); } else { this.controller?.disableGesturesDrag?.(); } }
  setRotateEnabled(value: boolean): void { if (value) { this.controller?.enableGesturesRotate?.(); } else { this.controller?.disableGesturesRotate?.(); } }
  setPitchEnabled(value: boolean): void { if (value) { this.controller?.enableGesturesPich?.(); } else { this.controller?.disableGesturesPich?.(); } }
  setShowsUserLocation(_value: boolean): void { /* 定位图层需 setLocation(ILocation) 提供实时坐标，此处不实现（parity TODO） */ }
  setShowsMyLocationButton(_value: boolean): void { /* no direct Baidu toggle */ }
  setShowsCompass(_value: boolean): void { /* 指南针为独立图层，无 controller 开关 */ }
  setShowsScale(_value: boolean): void { /* 比例尺为独立 UI，无 controller 开关 */ }
  setShowsTraffic(value: boolean): void { this.controller?.showTrafficMap?.(value); }
  setShowsBuildings(value: boolean): void { this.controller?.setHouseHeightEnable?.(value); }
  setShowsIndoors(value: boolean): void { this.controller?.showBaseIndoorMap?.(value); }
  setShowsIndoorLevelPicker(_value: boolean): void { /* no direct toggle */ }
  setShowsPointsOfInterest(value: boolean): void { this.controller?.showPoiMarkerPop?.(value); }

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
    const zoom: number = this.controller.getZoom();
    // zoomForDelta 的逆运算：由 zoom 反推经纬度跨度（近似值）。
    const delta = 360 / Math.pow(2, Math.max(1, zoom - 2));
    return { latitude: c.lat, longitude: c.lng, latitudeDelta: delta, longitudeDelta: delta };
  }

  currentCamera(): CnCamera {
    if (this.controller === null) {
      return { latitude: 0, longitude: 0, heading: 0, pitch: 0, zoom: 0, altitude: 0 };
    }
    const c: ESObject = this.controller.getCenter();
    const zoom: number = this.controller.getZoom();
    const rotate: number = this.controller.getRotate();
    const lat: number = (c !== null && c !== undefined) ? (c.lat as number) : 0;
    const lng: number = (c !== null && c !== undefined) ? (c.lng as number) : 0;
    return { latitude: lat, longitude: lng, heading: rotate, pitch: 0, zoom, altitude: 0 };
  }

  mapBoundaries(): [CnLatLng, CnLatLng] | null {
    // 百度无直接“可视范围 bounds”查询 API（getMapStatus 是 Android 形态），暂返回 null。
    return null;
  }

  fitToCoordinates(coordinates: CnLatLng[], _edgePadding: CnEdgeInsets, animated: boolean): void {
    if (coordinates.length === 0 || this.controller === null) {
      return;
    }
    // 真实 API：controller.setViewport(points, IViewportOption) 自动计算最佳中心 + 级别。
    const pts: ESObject = coordinates.map((c): ESObject => this.latLng(c));
    this.controller.setViewport(pts as LatLng[], { isAnimate: animated } as ESObject);
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
    // 真实 API 为 setGeoRoundLimit(Bounds)，Bounds 构造较复杂，暂不实现（parity TODO）。
  }

  // Projection -----------------------------------------------------------------
  pointForCoordinate(coordinate: CnLatLng): CnPoint | null {
    if (this.controller === null) {
      return null;
    }
    const px: ESObject = this.controller.ll2pixel(this.latLng(coordinate));
    return (px !== null && px !== undefined) ? { x: px[0], y: px[1] } : null;
  }

  coordinateForPoint(xPx: number, yPx: number): CnLatLng | null {
    if (this.controller === null) {
      return null;
    }
    // 百度 LatLng 字段是 lat/lng（非 latitude/longitude），读错字段会得 undefined。
    const ll: ESObject = this.controller.pixel2ll(xPx, yPx);
    return (ll !== null && ll !== undefined) ? { latitude: ll.lat, longitude: ll.lng } : null;
  }

  // Snapshot -------------------------------------------------------------------
  takeSnapshot(width: number, height: number, format: string, quality: number, result: string, completion: (uri: string) => void): void {
    if (this.controller === null) {
      completion('');
      return;
    }
    // 真实 API：controller.snapshot(region?) 返回 Promise<PixelMap>（旧代码误用 callback 形态）。
    const p: ESObject = this.controller.snapshot();
    if (p !== null && p !== undefined && typeof p.then === 'function') {
      p.then((pixelMap: image.PixelMap) => {
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

  // Baidu ships no bundled geocoder in this adapter — return null (parity w/ Kotlin).
  addressForCoordinate(_latitude: number, _longitude: number, completion: (address: CnAddress | null) => void): void {
    completion(null);
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
    // 真实 API：new Marker(IMarkerOption) → controller.addOverlay(marker)。
    const opt: IMarkerOption = {
      position: this.latLng({ latitude: model.latitude, longitude: model.longitude }) as LatLng,
      rotate: model.rotation,
      alpha: model.opacity,
      isDraggable: model.draggable,
      isClickable: true,
      zIndex: Math.round(model.zIndex),
    };
    const icon = this.descriptorFor(model);
    if (icon !== undefined) {
      opt.icon = icon;
    }
    const marker: ESObject = new Marker(opt);
    // ArkTS 无计算属性名——先建 Record 再赋值。
    const info: Record<string, string> = {};
    info[CHILD_ID] = childId;
    marker.setExtraInfo(info);
    // 单个 marker 点击事件（真实 API：Overlay.addEventListener(OverlayEvent.CLICK)）。
    const coord: CnLatLng = { latitude: model.latitude, longitude: model.longitude };
    marker.addEventListener(OverlayEvent.CLICK, () => {
      this.delegate?.onMarkerEvent(childId, CnMarkerEvent.PRESS, coord);
      this.delegate?.onMarkerEvent(childId, CnMarkerEvent.SELECT, coord);
    });
    this.controller.addOverlay(marker);
    return marker;
  }

  updateMarker(handle: OverlayHandle, model: CnMarkerModel): void {
    const marker: ESObject = handle.sdkObject;
    this.markerModels.set(handle, model);
    if (marker === null) {
      return;
    }
    marker.changePosition?.(this.latLng({ latitude: model.latitude, longitude: model.longitude }));
    marker.setAlpha?.(model.opacity);
    marker.setRotate?.(model.rotation);
    marker.setDraggable?.(model.draggable);
    const icon = this.descriptorFor(model);
    if (icon !== undefined) {
      marker.setIcon?.(icon);
    }
  }

  removeMarker(handle: OverlayHandle): void {
    (handle.sdkObject as ESObject)?.remove?.();
    this.markerHandles.delete(handle.childId);
    this.markerModels.delete(handle);
  }

  showCallout(_handle: OverlayHandle): void { /* Baidu InfoWindow via PopView; custom callout TODO */ }
  hideCallout(_handle: OverlayHandle): void { /* no-op until custom InfoWindow wired */ }
  redrawCallout(_handle: OverlayHandle): void { /* no-op until custom InfoWindow wired */ }

  animateMarker(handle: OverlayHandle, latitude: number, longitude: number, _duration: number): void {
    // Baidu has no built-in marker tween; set position (parity with Kotlin).
    (handle.sdkObject as ESObject)?.changePosition?.(this.latLng({ latitude, longitude }));
  }

  markerScreenPoint(handle: OverlayHandle): CnPoint | null {
    const marker: ESObject = handle.sdkObject;
    if (marker === null || this.controller === null) {
      return null;
    }
    const px: ESObject = this.controller.ll2pixel(marker.getPosition());
    return (px !== null && px !== undefined) ? { x: px[0], y: px[1] } : null;
  }

  markerPosition(handle: OverlayHandle): CnLatLng | null {
    const marker: ESObject = handle.sdkObject;
    if (marker === null) {
      return null;
    }
    const pos: ESObject = marker.getPosition();
    return (pos !== null && pos !== undefined) ? { latitude: pos.lat, longitude: pos.lng } : null;
  }

  private descriptorFor(model: CnMarkerModel): ImageEntity | undefined {
    // 自定义/图标位图 → ImageEntity(PixelMap)；无则返回 undefined，Marker 用 SDK 默认图标。
    try {
      if (model.customBitmap !== null) {
        return new ImageEntity(model.customBitmap as image.PixelMap);
      }
      if (model.iconBitmap !== null) {
        return new ImageEntity(model.iconBitmap as image.PixelMap);
      }
    } catch (_e) {
      return undefined;
    }
    return undefined;
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
    (handle.sdkObject as ESObject)?.remove?.();
    handle.sdkObject = this.controller !== null ? this.buildOverlay(model) : null;
    this.overlayModels.set(handle, model);
  }

  removeOverlay(handle: OverlayHandle): void {
    (handle.sdkObject as ESObject)?.remove?.();
    this.overlayHandles = this.overlayHandles.filter((h) => h !== handle);
    this.overlayModels.delete(handle);
  }

  private buildOverlay(model: CnOverlayModel): ESObject {
    switch (model.kind) {
      case 'polyline': return this.buildPolyline(model);
      case 'polygon': return this.buildPolygon(model);
      case 'circle': return this.buildCircle(model);
      case 'groundOverlay': return this.buildGroundOverlay(model);
      // Baidu heatmap (addHeatMap) and tiles (addTileLayer) are not Overlay objects —
      // TODO (parity with Android's BaiduMapAdapter which also leaves these out).
      default: return null;
    }
  }

  private buildPolyline(model: CnPolylineModel): ESObject {
    if (model.coordinates.length < 2) {
      return null;
    }
    // 真实 @bdmap：new Polyline(IPolylineOption) → controller.addOverlay。线色用 setColor
    // （IPolylineOption.fillcolor 语义偏“纹理填充”，线本身颜色走 color/setColor 更直观）。
    const pts: ESObject = model.coordinates.map((c): ESObject => this.latLng(c));
    const opt: IPolylineOption = {
      points: pts as LatLng[],
      width: Math.round(model.strokeWidth),
      dottedline: model.dashed,
      zIndex: Math.round(model.zIndex),
    };
    const line: ESObject = new Polyline(opt);
    const col = model.strokeColors.length > 0 ? model.strokeColors[0] : model.strokeColor;
    line.setColor?.(col);
    this.controller.addOverlay(line);
    return line;
  }

  private buildPolygon(model: CnPolygonModel): ESObject {
    if (model.coordinates.length < 3) {
      return null;
    }
    // 真实 @bdmap：new Polygon(IPolygonOption)，边框 stroke: new Stroke(IStrokeOption)、填充 fillcolor。
    const pts: ESObject = model.coordinates.map((c): ESObject => this.latLng(c));
    const strokeOpt: IStrokeOption = { strokeWidth: Math.round(model.strokeWidth), color: model.strokeColor };
    const opt: IPolygonOption = {
      points: pts as LatLng[],
      stroke: new Stroke(strokeOpt),
      fillcolor: model.fillColor,
      zIndex: Math.round(model.zIndex),
    };
    const poly: ESObject = new Polygon(opt);
    this.controller.addOverlay(poly);
    return poly;
  }

  private buildCircle(model: CnCircleModel): ESObject {
    // 真实 @bdmap：new Circle(ICircleOption)，center/radius + stroke + fillcolor。
    const strokeOpt: IStrokeOption = { strokeWidth: Math.round(model.strokeWidth), color: model.strokeColor };
    const opt: ICircleOption = {
      center: this.latLng(model.center) as LatLng,
      radius: Math.round(model.radius),
      stroke: new Stroke(strokeOpt),
      fillcolor: model.fillColor,
      zIndex: Math.round(model.zIndex),
    };
    const circle: ESObject = new Circle(opt);
    this.controller.addOverlay(circle);
    return circle;
  }

  private buildGroundOverlay(_model: CnGroundOverlayModel): ESObject {
    // 真实 API 为 Ground 覆盖物类（@bdmap/map 导出 Ground），构造 + 图片绑定较复杂，
    // 暂不实现，返回 null 以免阻断其它覆盖物 flush（parity TODO）。
    return null;
  }

  // Listeners ------------------------------------------------------------------
  private configureListeners(): void {
    const c: ESObject = this.controller;
    if (c === null) {
      return;
    }
    // 地图单击/长按（真实 API：controller.addEventListener(MapEvent.*)）。事件 e 为 EventBundle，
    // 含 geo(LatLng) + left/top 屏幕坐标；不同事件字段名略有差异，做防御式取值。
    c.addEventListener(MapEvent.CLICK, (e: ESObject) => {
      const geo: ESObject = this.eventGeo(e);
      if (geo !== null && geo !== undefined) {
        this.delegate?.onMapPress(CnPressKind.PRESS, { latitude: geo.latitude, longitude: geo.longitude }, this.screenPoint(geo));
      }
    });
    c.addEventListener(MapEvent.LONG_PRESS, (e: ESObject) => {
      const geo: ESObject = this.eventGeo(e);
      if (geo !== null && geo !== undefined) {
        this.delegate?.onMapPress(CnPressKind.LONG_PRESS, { latitude: geo.latitude, longitude: geo.longitude }, this.screenPoint(geo));
      }
    });
    // 相机/地图状态变化（进行中 / 结束）。
    c.addEventListener(MapEvent.MAPSTATUSCHANGE, () => this.delegate?.onRegionChange(false, true));
    c.addEventListener(MapEvent.MAPSTATUSCHANGEFINISH, () => this.delegate?.onRegionChange(true, true));
    // POI 点击（IMapClickListener.onClickedMapObj）与 marker 拖拽（OverlayDragListener）字段结构
    // 未完全明确，后续按需接入（parity TODO）。marker 点击已在 createSdkMarker 内逐个绑定。
  }

  // 从地图事件回调对象里提取经纬度（EventBundle 的 geo；兼容 latLng/point 命名）。
  private eventGeo(e: ESObject): ESObject {
    if (e === null || e === undefined) {
      return null;
    }
    if (e.geo !== undefined && e.geo !== null) {
      return e.geo;
    }
    if (e.latLng !== undefined && e.latLng !== null) {
      return e.latLng;
    }
    if (e.point !== undefined && e.point !== null) {
      return e.point;
    }
    return null;
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

  private moveToRegion(region: CnRegion, animated: boolean, duration: number): void {
    if (this.controller === null) {
      return;
    }
    // 真实 API：setViewport(4 角点, IViewportOption) 拟合 region 到最佳中心 + 级别。
    const sw: ESObject = this.latLng({ latitude: region.latitude - region.latitudeDelta / 2, longitude: region.longitude - region.longitudeDelta / 2 });
    const ne: ESObject = this.latLng({ latitude: region.latitude + region.latitudeDelta / 2, longitude: region.longitude + region.longitudeDelta / 2 });
    this.controller.setViewport([sw, ne], { isAnimate: animated, animationTime: Math.max(0, duration) } as ESObject);
  }

  private moveToCamera(camera: CnCamera, animated: boolean, duration: number): void {
    if (this.controller === null) {
      return;
    }
    // 注意：controller.setMapCenter 在本 SDK 上会让底图渲染空白（真机复现），改走 setViewport
    // ——由 zoom 反推经纬度跨度构造两角点，setViewport 自动拟合中心 + 级别（与 moveToRegion 同路径）。
    // rotate/overlook 暂不支持（需 BaseMap.setMapStatus，parity TODO）。
    const zoom: number = camera.zoom > 0 ? camera.zoom : (this.controller.getZoom() as number);
    const delta = 360 / Math.pow(2, Math.max(1, zoom - 2));
    const sw: ESObject = this.latLng({ latitude: camera.latitude - delta / 2, longitude: camera.longitude - delta / 2 });
    const ne: ESObject = this.latLng({ latitude: camera.latitude + delta / 2, longitude: camera.longitude + delta / 2 });
    this.controller.setViewport([sw, ne], { isAnimate: animated, animationTime: Math.max(0, duration) } as ESObject);
  }

  private screenPoint(ll: ESObject): CnPoint | null {
    if (this.controller === null) {
      return null;
    }
    const px: ESObject = this.controller.ll2pixel(ll);
    return (px !== null && px !== undefined) ? { x: px[0], y: px[1] } : null;
  }

  private latLng(c: CnLatLng): ESObject { return new LatLng(c.latitude, c.longitude); }
}

// ArkUI builder rendering the real Baidu map (@bdmap/map MapComponent) and binding
// its controller to the adapter via onReady.
@Builder
function baiduMapBuilder(adapter: CnMapAdapter) {
  MapComponent({
    mapOptions: (adapter as BaiduMapAdapter).buildInitialMapOptions(),
    gestureListener: undefined,
    // AsyncCallback<MapController>：地图就绪后把控制器交给 adapter。onReady/onLoad 可能
    // 多次回调、个别带 err；底图由 MapComponent 自渲染（不依赖 attachController），故 err
    // 仅告警不阻断，控制器仅首次有效时绑定（attachController 内部再幂等保护）。
    onReady: (err: BusinessError, controller: MapController) => {
      if (err) {
        hilog.warn(0x0000, 'cnmaps', 'baidu MapComponent onReady reported error (map still renders): %{public}s',
          err.message ?? String(err));
        return;
      }
      (adapter as BaiduMapAdapter).attachController(controller);
    },
  })
    .width('100%')
    .height('100%')
}

class BaiduFactory implements CnMapAdapterFactory {
  readonly providerName: string = 'baidu';

  create(context: common.Context): CnMapAdapter {
    return new BaiduMapAdapter(context);
  }

  mapBuilder(): CnMapBuilder {
    return wrapBuilder(baiduMapBuilder);
  }

  applyPrivacyConsent(context: common.Context, agreed: boolean, _contains: boolean, _shown: boolean): void {
    // 参考 Android BaiduMapAdapter.applyPrivacyConsent：
    //   SDKInitializer.setAgreePrivacy(context, agreed)  →  SDKInitializer.initialize(context)
    // 鸿蒙对应 API（@bdmap/base）：先 Initializer.configure(privacyAgreed) 声明隐私合规，
    // 再 Initializer.getInstance().initialize(ak, context) 初始化一次（幂等）。
    // 注意：必须走 configure()，否则 initialize 报 "Privacy mode is not set"。
    if (baiduInitialized) {
      return;
    }
    const uiCtx = context as common.UIAbilityContext;
    const config = new MapSDKConfigBuilder().setPrivacyAgreed(agreed).build();
    Initializer.configure(config)
      .then(() => {
        if (!agreed) {
          return;
        }
        const ak = readBaiduAk();
        if (ak.length === 0) {
          hilog.warn(0x0000, 'cnmaps',
            'baidu AK missing: 请在 module.json5 metadata 配置 com.baidu.lbsapi.API_KEY');
          return;
        }
        Initializer.getInstance().initialize(ak, uiCtx)
          .then((ok: boolean) => {
            baiduInitialized = ok;
            hilog.info(0x0000, 'cnmaps', 'baidu SDK initialize -> %{public}s', ok ? 'true' : 'false');
          })
          .catch((err: Object) => {
            // BusinessError 直接 JSON.stringify 会得到 {}，单独取 code/message。
            const e = err as BusinessError;
            hilog.error(0x0000, 'cnmaps', 'baidu SDK initialize error: code=%{public}d msg=%{public}s',
              e && e.code !== undefined ? e.code : -1, e && e.message ? e.message : String(err));
          });
      })
      .catch((err: Object) => {
        const e = err as BusinessError;
        hilog.error(0x0000, 'cnmaps', 'baidu SDK configure error: code=%{public}d msg=%{public}s',
          e && e.code !== undefined ? e.code : -1, e && e.message ? e.message : String(err));
      });
  }
}

export const BaiduMapAdapterFactory: CnMapAdapterFactory = new BaiduFactory();

class EmptyTurboModulesFactory extends TurboModulesFactory {
  createTurboModule(_name: string): TurboModule | null { return null; }
  hasTurboModule(_name: string): boolean { return false; }
}

export class BaiduPackage extends RNPackage {
  constructor(ctx: RNPackageContext) {
    super(ctx);
    CnMapAdapterRegistry.register(BaiduMapAdapterFactory);
  }

  createTurboModulesFactory(ctx: TurboModuleContext): TurboModulesFactory {
    return new EmptyTurboModulesFactory(ctx);
  }
}
