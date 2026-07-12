/*
 * 华为 Map Kit（鸿蒙自带地图 / Petal 地图引擎）实现的 CnMapAdapter。
 *
 * 与 amap/baidu/tencent 三家最大的不同：Map Kit 是 HarmonyOS 系统 SDK（`@kit.MapKit`），
 *   - 无需从 ohpm/厂商下 .har，import `@kit.MapKit` 即可（oh-package 不需要地图依赖）；
 *   - 无需 setApiKey / 隐私合规 init，鉴权走 AGC 的 client_id（写在宿主 module.json5 的
 *     metadata，系统自动读取；HarmonyOS 5.0.2(14)+ 甚至免配 client_id）；
 *   - 仅鸿蒙端存在（iOS/Android 无对应），故本包只有 harmony/。
 *
 * 因为是系统 SDK 且类型定义随 SDK 一起分发，本 adapter 直接对 `@kit.MapKit` 写**真实
 * 类型化 API**（map.MapComponentController / mapCommon.*），而非三家的 `ESObject` + 查证。
 *
 * 结构沿用三家的异步-控制器套路：MapComponent 通过 mapCallback 异步交付 controller，
 * config/markers/overlays 在 controller 就绪前 BUFFER，attachController 时 flush。
 * 注意 Map Kit 的 addMarker/addPolyline/... 返回 Promise（异步），故 handle.sdkObject
 * 是异步回填的（下同）。坐标系：Map Kit 国内展示用 GCJ-02，与高德/腾讯一致（JS 侧
 * PROVIDER_SYSTEM['mapkit']='gcj02'，coordinate 层已转好）。
 */
import common from '@ohos.app.ability.common';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import hilog from '@ohos.hilog';
import { BusinessError } from '@ohos.base';
import { mapCommon, map, MapComponent } from '@kit.MapKit';
import {
  CnAddress, CnCamera, CnCircleModel, CnEdgeInsets, CnLatLng, CnMapAdapter, CnMapAdapterDelegate,
  CnMapAdapterFactory, CnMapBuilder, CnMarkerEvent, CnMarkerModel, CnOverlayModel, CnPolygonModel,
  CnPolylineModel, CnPressKind, CnRegion, CnPoint, OverlayHandle, CnMapAdapterRegistry, tintedPinPixelMap
} from 'rn-cn-maps';
import {
  RNPackage, TurboModulesFactory, TurboModule, TurboModuleContext, RNPackageContext
} from '@rnoh/react-native-openharmony/ts';

// 由 region 的经度跨度估算 zoom：与三家一致的 log2(360/Δ)（视野比 Δ 略大，可后续微调）。
function zoomForRegion(region: CnRegion): number {
  const delta = Math.max(Math.abs(region.longitudeDelta), 1e-6);
  const zoom = Math.log2(360 / delta);
  return Math.max(3, Math.min(20, zoom));
}

// CnMapType 字符串 → mapCommon.MapType 枚举。
function mapTypeFor(value: string | null): mapCommon.MapType {
  switch (value) {
    case 'satellite': return mapCommon.MapType.SATELLITE;
    case 'hybrid': return mapCommon.MapType.HYBRID;
    case 'terrain': return mapCommon.MapType.TERRAIN;
    case 'none': return mapCommon.MapType.NONE;
    default: return mapCommon.MapType.STANDARD;
  }
}

export class MapKitAdapter implements CnMapAdapter {
  private context: common.Context;
  private controller: map.MapComponentController | null = null;
  delegate: CnMapAdapterDelegate | null = null;

  readonly providerName: string = 'mapkit';

  private pendingInitialRegion: CnRegion | null = null;
  private pendingInitialCamera: CnCamera | null = null;
  private didApplyInitialRegion = false;
  private didApplyInitialCamera = false;
  private isGesture = false;
  // mapCallback 可能多次回调，控制器只绑定一次。
  private didAttachController = false;

  private markerHandles: Map<string, OverlayHandle> = new Map();
  private overlayHandles: OverlayHandle[] = [];
  private markerModels: Map<OverlayHandle, CnMarkerModel> = new Map();
  private overlayModels: Map<OverlayHandle, CnOverlayModel> = new Map();
  private pendingAdds: OverlayHandle[] = [];

  constructor(context: common.Context) {
    this.context = context;
  }

  // 供 @Builder 读取的初始 MapOptions（MapComponent 挂载时读一次）。position 必填，
  // 从 pending 初始 region/camera 推导；controller 就绪后 applyPendingInitial 再 move 一次
  // （幂等），覆盖「region 在 build 之后才设置」的时序。
  buildMapOptions(): mapCommon.MapOptions {
    let position: mapCommon.CameraPosition = { target: { latitude: 0, longitude: 0 }, zoom: 3 };
    if (this.pendingInitialCamera !== null) {
      const c = this.pendingInitialCamera;
      position = { target: { latitude: c.latitude, longitude: c.longitude }, zoom: c.zoom, tilt: c.pitch, bearing: c.heading };
    } else if (this.pendingInitialRegion !== null) {
      const r = this.pendingInitialRegion;
      position = { target: { latitude: r.latitude, longitude: r.longitude }, zoom: zoomForRegion(r) };
    }
    const options: mapCommon.MapOptions = { position };
    return options;
  }

  attachController(controller: map.MapComponentController): void {
    if (this.didAttachController) {
      return;
    }
    this.didAttachController = true;
    this.controller = controller;
    // 底图由 MapComponent 自渲染，不依赖以下步骤；分段 try/catch 兜住：让能成功的步骤
    // （尤其初始定位）执行，失败只告警、不阻断底图。
    try {
      this.configureListeners();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'mapkit listeners pending: %{public}s', JSON.stringify(e));
    }
    try {
      const buffered = this.pendingAdds.slice();
      this.pendingAdds = [];
      buffered.forEach((handle) => {
        const marker = this.markerModels.get(handle);
        if (marker !== undefined) {
          this.addMarkerToMap(handle, marker);
          return;
        }
        const overlay = this.overlayModels.get(handle);
        if (overlay !== undefined) {
          this.addOverlayToMap(handle, overlay);
        }
      });
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'mapkit overlay flush error: %{public}s', JSON.stringify(e));
    }
    try {
      this.applyPendingInitial();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'mapkit initial camera error: %{public}s', JSON.stringify(e));
    }
    try {
      this.delegate?.onMapReady();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'mapkit onMapReady delegate error: %{public}s', JSON.stringify(e));
    }
  }

  isReady(): boolean { return this.controller !== null; }

  onResume(): void {}
  onPause(): void {}
  onDestroy(): void { this.controller = null; }
  onSizeChanged(): void { this.applyPendingInitial(); }
  didLayout(): void { this.applyPendingInitial(); }

  reset(): void {
    this.markerHandles.forEach((h) => { (h.sdkObject as map.Marker | null)?.remove(); });
    this.overlayHandles.forEach((h) => { this.removeSdkOverlay(h); });
    this.markerHandles.clear();
    this.markerModels.clear();
    this.overlayHandles = [];
    this.overlayModels.clear();
  }

  // Configuration — 直接 setter；host 在 onMapReady 后会重新 apply 一遍。-----------------
  setMapType(value: string | null): void { this.controller?.setMapType(mapTypeFor(value)); }
  setUserInterfaceStyle(value: string | null): void {
    if (this.controller === null) {
      return;
    }
    const mode = value === 'dark' ? mapCommon.DayNightMode.NIGHT
      : (value === 'light' ? mapCommon.DayNightMode.DAY : mapCommon.DayNightMode.AUTO);
    this.controller.setDayNightMode(mode);
  }
  setMinZoomLevel(value: number): void { this.controller?.setMinZoom(value); }
  setMaxZoomLevel(value: number): void { this.controller?.setMaxZoom(value); }
  setZoomEnabled(value: boolean): void { this.controller?.setZoomGesturesEnabled(value); }
  setZoomControlEnabled(value: boolean): void { this.controller?.setZoomControlsEnabled(value); }
  setScrollEnabled(value: boolean): void { this.controller?.setScrollGesturesEnabled(value); }
  setRotateEnabled(value: boolean): void { this.controller?.setRotateGesturesEnabled(value); }
  setPitchEnabled(value: boolean): void { this.controller?.setTiltGesturesEnabled(value); }
  setShowsUserLocation(value: boolean): void { this.controller?.setMyLocationEnabled(value); }
  setShowsMyLocationButton(value: boolean): void { this.controller?.setMyLocationControlsEnabled(value); }
  setShowsCompass(value: boolean): void { this.controller?.setCompassControlsEnabled(value); }
  setShowsScale(value: boolean): void { this.controller?.setScaleControlsEnabled(value); }
  setShowsTraffic(value: boolean): void { this.controller?.setTrafficEnabled(value); }
  setShowsBuildings(value: boolean): void { this.controller?.setBuildingEnabled(value); }
  setShowsIndoors(value: boolean): void { this.controller?.setIndoorMapEnabled(value); }
  setShowsIndoorLevelPicker(_value: boolean): void { /* Map Kit 无独立楼层选择器开关 */ }
  setShowsPointsOfInterest(_value: boolean): void { /* 查证: Map Kit POI 显隐开关（暂无直接 API） */ }

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
      const t = this.controller.getCameraPosition().target;
      resolved = {
        latitude: t.latitude, longitude: t.longitude,
        heading: camera.heading, pitch: camera.pitch, zoom: camera.zoom, altitude: camera.altitude,
      };
    }
    this.moveToCamera(resolved, animated, duration);
  }

  currentRegion(): CnRegion | null {
    if (this.controller === null) {
      return null;
    }
    try {
      const cam = this.controller.getCameraPosition();
      const bounds = this.controller.getProjection().getVisibleRegion().bounds;
      return {
        latitude: cam.target.latitude, longitude: cam.target.longitude,
        latitudeDelta: Math.abs(bounds.northeast.latitude - bounds.southwest.latitude),
        longitudeDelta: Math.abs(bounds.northeast.longitude - bounds.southwest.longitude),
      };
    } catch (_e) {
      return null;
    }
  }

  currentCamera(): CnCamera {
    if (this.controller === null) {
      return { latitude: 0, longitude: 0, heading: 0, pitch: 0, zoom: 0, altitude: 0 };
    }
    const p = this.controller.getCameraPosition();
    return {
      latitude: p.target.latitude, longitude: p.target.longitude,
      heading: p.bearing ?? 0, pitch: p.tilt ?? 0, zoom: p.zoom, altitude: 0,
    };
  }

  mapBoundaries(): [CnLatLng, CnLatLng] | null {
    if (this.controller === null) {
      return null;
    }
    try {
      const b = this.controller.getProjection().getVisibleRegion().bounds;
      const ne: CnLatLng = { latitude: b.northeast.latitude, longitude: b.northeast.longitude };
      const sw: CnLatLng = { latitude: b.southwest.latitude, longitude: b.southwest.longitude };
      return [ne, sw];
    } catch (_e) {
      return null;
    }
  }

  fitToCoordinates(coordinates: CnLatLng[], edgePadding: CnEdgeInsets, animated: boolean): void {
    if (coordinates.length === 0 || this.controller === null) {
      return;
    }
    const bounds = this.boundsOf(coordinates);
    const padding: mapCommon.Padding = {
      left: edgePadding.left, top: edgePadding.top, right: edgePadding.right, bottom: edgePadding.bottom,
    };
    const update = map.newLatLngBounds(bounds, padding);
    this.applyCameraUpdate(update, animated, 0);
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

  setMapBoundaries(ne: CnLatLng, sw: CnLatLng): void {
    const bounds: mapCommon.LatLngBounds = {
      northeast: { latitude: ne.latitude, longitude: ne.longitude },
      southwest: { latitude: sw.latitude, longitude: sw.longitude },
    };
    this.controller?.setLatLngBounds(bounds);
  }

  // Projection -----------------------------------------------------------------
  pointForCoordinate(coordinate: CnLatLng): CnPoint | null {
    if (this.controller === null) {
      return null;
    }
    try {
      const p = this.controller.getProjection().toScreenLocation(this.latLng(coordinate));
      return { x: p.positionX, y: p.positionY };
    } catch (_e) {
      return null;
    }
  }

  coordinateForPoint(xPx: number, yPx: number): CnLatLng | null {
    if (this.controller === null) {
      return null;
    }
    try {
      const point: mapCommon.MapPoint = { positionX: xPx, positionY: yPx };
      const ll = this.controller.getProjection().fromScreenLocation(point);
      return { latitude: ll.latitude, longitude: ll.longitude };
    } catch (_e) {
      return null;
    }
  }

  // Snapshot -------------------------------------------------------------------
  takeSnapshot(width: number, height: number, format: string, quality: number, result: string, completion: (uri: string) => void): void {
    if (this.controller === null) {
      completion('');
      return;
    }
    this.controller.snapshot()
      .then((pixelMap: image.PixelMap) => {
        this.encodeSnapshot(pixelMap, width, height, format, quality, result)
          .then((uri) => completion(uri)).catch(() => completion(''));
      })
      .catch(() => completion(''));
  }

  private async encodeSnapshot(pixelMap: image.PixelMap, _width: number, _height: number, format: string, quality: number, result: string): Promise<string> {
    try {
      const isJpg = format === 'jpg' || format === 'jpeg';
      const q = Math.round(Math.max(0, Math.min(1, quality)) * 100);
      const packer = image.createImagePacker();
      const data: ArrayBuffer = await packer.packing(pixelMap, { format: isJpg ? 'image/jpeg' : 'image/png', quality: q });
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
    // 查证: Map Kit 自带逆地理编码在 `@hms.core.map.site`（site.reverseGeocode）。首版与
    // baidu/tencent 保持一致返回 null；后续可用 site 模块实现真实地址查询。
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
      this.addMarkerToMap(handle, model);
    }
    return handle;
  }

  // addMarker 返回 Promise，handle.sdkObject 异步回填。
  private addMarkerToMap(handle: OverlayHandle, model: CnMarkerModel): void {
    if (this.controller === null) {
      return;
    }
    this.controller.addMarker(this.markerOptions(model))
      .then((marker: map.Marker) => {
        handle.sdkObject = marker;
        marker.setTag(handle.childId);
      })
      .catch((e: BusinessError) => hilog.warn(0x0000, 'cnmaps', 'mapkit addMarker error: %{public}s', JSON.stringify(e)));
  }

  private markerOptions(model: CnMarkerModel): mapCommon.MarkerOptions {
    const icon = this.iconFor(model);
    const options: mapCommon.MarkerOptions = {
      position: { latitude: model.latitude, longitude: model.longitude },
      rotation: model.rotation,
      alpha: model.opacity,
      anchorU: model.anchorU,
      anchorV: model.anchorV,
      draggable: model.draggable,
      flat: model.flat,
      clickable: true,
      title: model.title ?? undefined,
      snippet: model.snippet ?? undefined,
    };
    if (icon !== null) {
      options.icon = icon;
    }
    return options;
  }

  updateMarker(handle: OverlayHandle, model: CnMarkerModel): void {
    this.markerModels.set(handle, model);
    const marker = handle.sdkObject as map.Marker | null;
    if (marker === null) {
      return;
    }
    marker.setPosition({ latitude: model.latitude, longitude: model.longitude });
    marker.setAlpha(model.opacity);
    marker.setRotation(model.rotation);
    marker.setDraggable(model.draggable);
    const icon = this.iconFor(model);
    if (icon !== null) {
      marker.setIcon(icon);
    }
  }

  removeMarker(handle: OverlayHandle): void {
    (handle.sdkObject as map.Marker | null)?.remove();
    this.markerHandles.delete(handle.childId);
    this.markerModels.delete(handle);
  }

  showCallout(handle: OverlayHandle): void { (handle.sdkObject as map.Marker | null)?.setInfoWindowVisible(true); }
  hideCallout(handle: OverlayHandle): void { (handle.sdkObject as map.Marker | null)?.setInfoWindowVisible(false); }
  redrawCallout(handle: OverlayHandle): void {
    const m = handle.sdkObject as map.Marker | null;
    if (m !== null && m.isInfoWindowVisible()) {
      m.setInfoWindowVisible(true);
    }
  }

  animateMarker(handle: OverlayHandle, latitude: number, longitude: number, _duration: number): void {
    // 查证: Map Kit 有 TranslateAnimation 可做补间；首版直接 setPosition（与三家一致）。
    (handle.sdkObject as map.Marker | null)?.setPosition({ latitude, longitude });
  }

  markerScreenPoint(handle: OverlayHandle): CnPoint | null {
    const marker = handle.sdkObject as map.Marker | null;
    if (marker === null || this.controller === null) {
      return null;
    }
    try {
      const p = this.controller.getProjection().toScreenLocation(marker.getPosition());
      return { x: p.positionX, y: p.positionY };
    } catch (_e) {
      return null;
    }
  }

  markerPosition(handle: OverlayHandle): CnLatLng | null {
    const marker = handle.sdkObject as map.Marker | null;
    if (marker === null) {
      return null;
    }
    const pos = marker.getPosition();
    return { latitude: pos.latitude, longitude: pos.longitude };
  }

  // MarkerOptions.icon 直接接受 PixelMap（无需像百度那样合成默认图钉）。null → Map Kit 默认图钉。
  private iconFor(model: CnMarkerModel): image.PixelMap | null {
    if (model.customBitmap !== null) {
      return model.customBitmap;
    }
    if (model.iconBitmap !== null) {
      return model.iconBitmap;
    }
    // pinColor：Map Kit 默认图钉不可调色，用共享自绘着色 pin。
    if (model.pinColor !== null) {
      return tintedPinPixelMap(model.pinColor);
    }
    return null;
  }

  // Overlays -------------------------------------------------------------------
  addOverlay(model: CnOverlayModel, childId: string): OverlayHandle {
    const handle = new OverlayHandle(childId);
    this.overlayHandles.push(handle);
    this.overlayModels.set(handle, model);
    if (this.controller === null) {
      this.pendingAdds.push(handle);
    } else {
      this.addOverlayToMap(handle, model);
    }
    return handle;
  }

  updateOverlay(handle: OverlayHandle, model: CnOverlayModel): void {
    this.removeSdkOverlay(handle);
    this.overlayModels.set(handle, model);
    if (this.controller !== null) {
      this.addOverlayToMap(handle, model);
    }
  }

  removeOverlay(handle: OverlayHandle): void {
    this.removeSdkOverlay(handle);
    this.overlayHandles = this.overlayHandles.filter((h) => h !== handle);
    this.overlayModels.delete(handle);
  }

  private removeSdkOverlay(handle: OverlayHandle): void {
    const obj = handle.sdkObject as map.BaseOverlay | null;
    obj?.remove();
    handle.sdkObject = null;
  }

  // 覆盖物同样异步（addPolyline/... 返回 Promise），sdkObject 异步回填。
  private addOverlayToMap(handle: OverlayHandle, model: CnOverlayModel): void {
    const p = this.overlayPromise(model);
    if (p === null) {
      return;
    }
    p.then((overlay: map.BaseOverlay) => { handle.sdkObject = overlay; })
      .catch((e: BusinessError) => hilog.warn(0x0000, 'cnmaps', 'mapkit addOverlay error: %{public}s', JSON.stringify(e)));
  }

  private overlayPromise(model: CnOverlayModel): Promise<map.BaseOverlay> | null {
    if (this.controller === null) {
      return null;
    }
    switch (model.kind) {
      case 'polyline': return this.buildPolyline(model);
      case 'polygon': return this.buildPolygon(model);
      case 'circle': return this.buildCircle(model);
      // heatmap / urlTile / localTile / groundOverlay 走 addHeatmap/addTileOverlay/
      // addImageOverlay（Map Kit 均有 typed API），首版先不接（与 tencent/android 同范围），
      // 后续迭代补齐。
      default: return null;
    }
  }

  private buildPolyline(model: CnPolylineModel): Promise<map.BaseOverlay> | null {
    if (model.coordinates.length < 2 || this.controller === null) {
      return null;
    }
    const options: mapCommon.MapPolylineOptions = {
      points: model.coordinates.map((c): mapCommon.LatLng => this.latLng(c)),
      width: model.strokeWidth,
      clickable: model.tappable,
      geodesic: model.geodesic,
    };
    if (model.strokeColors.length > 0) {
      options.colors = model.strokeColors;
      options.gradient = true;
    } else {
      options.color = model.strokeColor;
    }
    // dashed → PatternItem 虚线（DASH/GAP 交替），Map Kit 4.1+ 原生支持。
    if (model.dashed) {
      const dash: mapCommon.PatternItem = { type: mapCommon.PatternItemType.DASH, length: 20 };
      const gap: mapCommon.PatternItem = { type: mapCommon.PatternItemType.GAP, length: 10 };
      options.patterns = [dash, gap];
    }
    return this.controller.addPolyline(options);
  }

  private buildPolygon(model: CnPolygonModel): Promise<map.BaseOverlay> | null {
    if (model.coordinates.length < 3 || this.controller === null) {
      return null;
    }
    const options: mapCommon.MapPolygonOptions = {
      points: model.coordinates.map((c): mapCommon.LatLng => this.latLng(c)),
      holes: model.holes.map((hole): mapCommon.LatLng[] => hole.map((c): mapCommon.LatLng => this.latLng(c))),
      fillColor: model.fillColor,
      strokeColor: model.strokeColor,
      strokeWidth: model.strokeWidth,
    };
    return this.controller.addPolygon(options);
  }

  private buildCircle(model: CnCircleModel): Promise<map.BaseOverlay> | null {
    if (this.controller === null) {
      return null;
    }
    const options: mapCommon.MapCircleOptions = {
      center: this.latLng(model.center),
      radius: model.radius,
      fillColor: model.fillColor,
      strokeColor: model.strokeColor,
      strokeWidth: model.strokeWidth,
    };
    return this.controller.addCircle(options);
  }

  // Listeners ------------------------------------------------------------------
  private configureListeners(): void {
    const c = this.controller;
    if (c === null) {
      return;
    }
    c.on('mapClick', (ll: mapCommon.LatLng) => {
      this.delegate?.onMapPress(CnPressKind.PRESS, { latitude: ll.latitude, longitude: ll.longitude }, this.screenPoint(ll));
    });
    c.on('mapLongClick', (ll: mapCommon.LatLng) => {
      this.delegate?.onMapPress(CnPressKind.LONG_PRESS, { latitude: ll.latitude, longitude: ll.longitude }, this.screenPoint(ll));
    });
    c.on('mapLoad', () => this.delegate?.onMapReady());
    c.on('poiClick', (poi: mapCommon.Poi) => {
      this.delegate?.onPoiClick({ placeId: poi.id, name: poi.name, latitude: poi.position.latitude, longitude: poi.position.longitude });
    });
    c.on('cameraMoveStart', (reason: number) => { this.isGesture = reason === 1; });
    c.on('cameraChange', (_ll: mapCommon.LatLng) => this.delegate?.onRegionChange(false, this.isGesture));
    c.on('cameraIdle', () => this.delegate?.onRegionChange(true, this.isGesture));
    c.on('markerClick', (marker: map.Marker) => this.deliverMarker(marker, CnMarkerEvent.PRESS, true));
    c.on('markerDragStart', (marker: map.Marker) => this.deliverMarker(marker, CnMarkerEvent.DRAG_START, false));
    c.on('markerDrag', (marker: map.Marker) => this.deliverMarker(marker, CnMarkerEvent.DRAG, false));
    c.on('markerDragEnd', (marker: map.Marker) => this.deliverMarker(marker, CnMarkerEvent.DRAG_END, false));
  }

  private deliverMarker(marker: map.Marker, event: CnMarkerEvent, alsoSelect: boolean): void {
    // getTag() 返回 Object；tag 是 addMarker 时 setTag 的 childId 字符串。
    const tag = marker.getTag();
    const childId = typeof tag === 'string' ? tag : '';
    if (childId.length === 0) {
      return;
    }
    const pos = marker.getPosition();
    const coord: CnLatLng = { latitude: pos.latitude, longitude: pos.longitude };
    this.delegate?.onMarkerEvent(childId, event, coord);
    if (alsoSelect) {
      this.delegate?.onMarkerEvent(childId, CnMarkerEvent.SELECT, coord);
    }
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
    // 显式构造 LatLng：不能把 CnRegion 直接当 CnLatLng 传（ArkTS 禁结构化类型）。
    const target: mapCommon.LatLng = { latitude: region.latitude, longitude: region.longitude };
    const update = map.newLatLng(target, zoomForRegion(region));
    this.applyCameraUpdate(update, animated, duration);
  }

  private moveToCamera(camera: CnCamera, animated: boolean, duration: number): void {
    if (this.controller === null) {
      return;
    }
    // JS setCamera 部分更新时未传字段填 0（哨兵=保持不变），用当前相机值兜底——
    // 否则 setCamera({heading}) 会把 zoom/pitch 一并归零（真机曾出现 zoom 10→3 全亚洲视野）。
    const cur = this.currentCamera();
    const position: mapCommon.CameraPosition = {
      target: {
        latitude: camera.latitude !== 0 ? camera.latitude : cur.latitude,
        longitude: camera.longitude !== 0 ? camera.longitude : cur.longitude,
      },
      zoom: camera.zoom > 0 ? camera.zoom : cur.zoom,
      tilt: camera.pitch > 0 ? camera.pitch : cur.pitch,
      bearing: camera.heading > 0 ? camera.heading : cur.heading,
    };
    this.applyCameraUpdate(map.newCameraPosition(position), animated, duration);
  }

  private applyCameraUpdate(update: map.CameraUpdate, animated: boolean, duration: number): void {
    if (this.controller === null) {
      return;
    }
    if (animated) {
      this.controller.animateCamera(update, duration);
    } else {
      this.controller.moveCamera(update);
    }
  }

  private boundsOf(coords: CnLatLng[]): mapCommon.LatLngBounds {
    let minLat = coords[0].latitude;
    let maxLat = coords[0].latitude;
    let minLng = coords[0].longitude;
    let maxLng = coords[0].longitude;
    coords.forEach((c) => {
      minLat = Math.min(minLat, c.latitude);
      maxLat = Math.max(maxLat, c.latitude);
      minLng = Math.min(minLng, c.longitude);
      maxLng = Math.max(maxLng, c.longitude);
    });
    return { northeast: { latitude: maxLat, longitude: maxLng }, southwest: { latitude: minLat, longitude: minLng } };
  }

  private screenPoint(ll: mapCommon.LatLng): CnPoint | null {
    if (this.controller === null) {
      return null;
    }
    try {
      const p = this.controller.getProjection().toScreenLocation(ll);
      return { x: p.positionX, y: p.positionY };
    } catch (_e) {
      return null;
    }
  }

  private latLng(c: CnLatLng): mapCommon.LatLng {
    return { latitude: c.latitude, longitude: c.longitude };
  }
}

// ArkUI builder：渲染真实华为 Map Kit（@kit.MapKit MapComponent），mapCallback 异步交付
// MapComponentController。无状态 @Builder（初始视口从 adapter.buildMapOptions() 读）。
// 查证: 官方示例在 @Entry 页里用 onPageShow/onPageHide 显隐地图；本处地图内嵌在 RNOH 自定义
// 组件里、无页面生命周期，若某些设备上底图不出，需在此桥接可见性（on-device 再定）。
@Builder
function mapKitMapBuilder(adapter: CnMapAdapter) {
  MapComponent({
    mapOptions: (adapter as MapKitAdapter).buildMapOptions(),
    mapCallback: (err: BusinessError, controller: map.MapComponentController) => {
      if (err) {
        hilog.warn(0x0000, 'cnmaps', 'mapkit MapComponent callback error: %{public}s', err.message ?? JSON.stringify(err));
        return;
      }
      (adapter as MapKitAdapter).attachController(controller);
    },
  })
    .width('100%')
    .height('100%')
}

class MapKitFactory implements CnMapAdapterFactory {
  readonly providerName: string = 'mapkit';

  create(context: common.Context): CnMapAdapter {
    // Map Kit 无需 setApiKey / 隐私 init：鉴权走 AGC client_id（宿主 module.json5 metadata，
    // 系统自动读）。故此处不做任何 SDK 初始化。
    return new MapKitAdapter(context);
  }

  mapBuilder(): CnMapBuilder {
    return wrapBuilder(mapKitMapBuilder);
  }

  applyPrivacyConsent(_context: common.Context, _agreed: boolean, _contains: boolean, _shown: boolean): void {
    // Map Kit 无独立隐私合规接口（不同于百度 SDKInitializer.setAgreePrivacy）；此处 no-op。
  }
}

export const MapKitMapAdapterFactory: CnMapAdapterFactory = new MapKitFactory();

class EmptyTurboModulesFactory extends TurboModulesFactory {
  createTurboModule(_name: string): TurboModule | null { return null; }
  hasTurboModule(_name: string): boolean { return false; }
}

export class MapKitPackage extends RNPackage {
  constructor(ctx: RNPackageContext) {
    super(ctx);
    CnMapAdapterRegistry.register(MapKitMapAdapterFactory);
  }

  createTurboModulesFactory(ctx: TurboModuleContext): TurboModulesFactory {
    return new EmptyTurboModulesFactory(ctx);
  }
}
