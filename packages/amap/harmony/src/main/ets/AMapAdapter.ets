/*
 * AMap (高德) implementation of CnMapAdapter for HarmonyOS (RNOH). ArkTS port of
 * amap/android `AMapAdapter.kt`. Owns the AMap HarmonyOS map controller + its
 * listeners and is the single place in the HarmonyOS layer that references the
 * AMap SDK in the map layer.
 *
 * STRUCTURAL ADAPTATION vs Android: on Android the MapView + AMap controller exist
 * synchronously at construction; on ArkUI the map is declarative and the controller
 * arrives asynchronously via the component's map-ready callback. So this adapter
 * BUFFERS config / viewport / markers / overlays until `attachController()` runs,
 * then flushes them. Pure geometry helpers are ported 1:1 from Kotlin.
 *
 * 查证 (verify against the real AMap HarmonyOS SDK `.d.ts`):
 *   - ohpm package name + import paths (placeholder '@amap/amap_lbs_map' below)
 *   - the ArkUI map component name + how it surfaces the controller (onMapReady)
 *   - controller / options method names (kept Android-consistent by AMap, but confirm)
 * SDK handles are typed `ESObject` so call sites stay dynamic until typed imports
 * are wired; replace with the real types during P3/P4.
 */
import common from '@ohos.app.ability.common';
import image from '@ohos.multimedia.image';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import http from '@ohos.net.http';
import {
  CnAddress, CnCamera, CnCircleModel, CnEdgeInsets, CnGroundOverlayModel, CnHeatmapModel, CnLatLng,
  CnLocalTileModel, CnMapAdapter, CnMapAdapterDelegate, CnMarkerEvent, CnMarkerModel, CnOverlayModel,
  CnPoi, CnPolygonModel, CnPolylineModel, CnPressKind, CnRegion, CnUrlTileModel, CnUserLocation,
  CnPoint, OverlayHandle
} from 'rn-cn-maps';
import { markerHue, rnRotationToAMap, wmsUrl } from './AMapMath';
import hilog from '@ohos.hilog';
// 真实高德鸿蒙 SDK 符号（@amap/amap_lbs_map3d，见 oh-package.json5）。仅相机/地图类型用
// 真实类型；controller 仍保持 ESObject——覆盖物/监听器等大量方法尚未逐一对齐真实 AMap API。
import {
  LatLng, CameraUpdateFactory, CameraPosition, MapType, MarkerOptions, PolylineOptions, PolygonOptions,
  CircleOptions, BitmapDescriptorFactory, GroundOverlayOptions, LatLngBounds,
  WeightedLatLng, HeatMapBuilder, HeatmapTileProvider, Gradient, TileOverlayOptions
} from '@amap/amap_lbs_map3d';

// 每个地图实例分配唯一 mapViewName，供 MapViewComponent 渲染 + MapViewManager 回调匹配。
let amapViewSeq = 0;

const MIN_DELTA = 0.000001;

export class AMapAdapter implements CnMapAdapter {
  private context: common.Context;
  private controller: ESObject = null; // AMap controller (Android: AMap); null until ready.
  delegate: CnMapAdapterDelegate | null = null;

  readonly providerName: string = 'amap';
  // 本实例的 MapViewComponent 名称（AMapHostView 用它渲染 + 匹配 MapViewManager 回调）。
  readonly mapViewName: string = `cnmaps_amap_${++amapViewSeq}`;

  // Buffered config (applied to the controller on attach + on change when ready).
  private mapTypeProp: string | null = null;
  private userInterfaceStyleProp: string | null = null;

  private pendingInitialRegion: CnRegion | null = null;
  private pendingInitialCamera: CnCamera | null = null;
  private didApplyInitialRegion = false;
  private didApplyInitialCamera = false;
  private isGesture = false;

  private markerHandles: OverlayHandle[] = [];
  private markerModels: Map<OverlayHandle, CnMarkerModel> = new Map();
  private overlayHandles: OverlayHandle[] = [];
  private overlayModels: Map<OverlayHandle, CnOverlayModel> = new Map();
  // Buffer for markers/overlays added before the controller is ready.
  private pendingAdds: OverlayHandle[] = [];
  // image uri → PixelMap 缓存（marker 图标 / 图片覆盖物），避免重复下载解码。
  private imageCache: Map<string, image.PixelMap> = new Map();

  constructor(context: common.Context) {
    this.context = context;
  }

  // Called by the provider's mapBuilder once the AMap ArkUI map's controller is
  // ready. Provider-specific (not on the core interface).
  attachController(controller: ESObject): void {
    this.controller = controller;
    // 底图由 MapViewComponent 自渲染，不依赖以下步骤。监听器/覆盖物的方法名尚未逐一对齐
    // 真实 AMap 鸿蒙 API（configureListeners/createSdkMarker/buildOverlay 仍是 Android 形态），
    // 用分段 try/catch 兜住：让能成功的步骤（尤其初始定位）执行，失败只告警、不阻断底图。
    try {
      this.configureListeners();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'amap configureListeners pending real API: %{public}s', JSON.stringify(e));
    }
    try {
      this.applyMapType();
      // Materialize anything added before the controller existed.
      const buffered = this.pendingAdds.slice();
      this.pendingAdds = [];
      buffered.forEach((handle) => {
        const marker = this.markerModels.get(handle);
        if (marker !== undefined) {
          this.addSdkMarker(marker, handle);
          return;
        }
        const overlay = this.overlayModels.get(handle);
        if (overlay !== undefined) {
          this.materializeOverlay(overlay, handle);
        }
      });
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'amap overlay flush pending real API: %{public}s', JSON.stringify(e));
    }
    // 初始定位用真实 CameraUpdateFactory，独立兜底以确保底图居中到 RN initialRegion。
    try {
      this.applyPendingInitialCamera();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'amap initial camera error: %{public}s', JSON.stringify(e));
    }
    try {
      this.delegate?.onMapReady();
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'amap onMapReady delegate error: %{public}s', JSON.stringify(e));
    }
  }

  isReady(): boolean {
    return this.controller !== null;
  }

  // Lifecycle ------------------------------------------------------------------
  onResume(): void { /* 查证: controller.onResume() if the SDK requires it */ }
  onPause(): void { /* 查证: controller.onPause() */ }
  onDestroy(): void { this.controller = null; }
  onSizeChanged(): void { this.applyPendingInitialCamera(); }
  didLayout(): void { this.applyPendingInitialCamera(); }

  reset(): void {
    this.markerHandles.forEach((h) => this.removeSdkMarker(h.sdkObject));
    this.overlayHandles.forEach((h) => this.removeSdkOverlay(h.sdkObject));
    this.markerHandles = [];
    this.markerModels.clear();
    this.overlayHandles = [];
    this.overlayModels.clear();
  }

  // Configuration --------------------------------------------------------------
  setMapType(value: string | null): void { this.mapTypeProp = value; this.applyMapType(); }
  setUserInterfaceStyle(value: string | null): void { this.userInterfaceStyleProp = value; this.applyMapType(); }

  private applyMapType(): void {
    if (this.controller === null) {
      return;
    }
    if (this.mapTypeProp === 'satellite' || this.mapTypeProp === 'hybrid') {
      this.controller.setMapType(MapType.MAP_TYPE_SATELLITE);
    } else if (this.userInterfaceStyleProp === 'dark') {
      this.controller.setMapType(MapType.MAP_TYPE_NIGHT);
    } else {
      this.controller.setMapType(MapType.MAP_TYPE_NORMAL);
    }
  }

  // Direct setters — apply when the controller is ready, else no-op. The host
  // re-applies the full prop set on onMapReady (see CnMapHostController), so config
  // set before the controller attached is flushed centrally for every provider.
  // 查证: each maps to the AMap UiSettings / controller flag (kept consistent with
  // Android — isZoomGesturesEnabled, isScrollGesturesEnabled, etc.).
  setMinZoomLevel(value: number): void { this.controller?.setMinZoomLevel?.(value); }
  setMaxZoomLevel(value: number): void { this.controller?.setMaxZoomLevel?.(value); }
  setZoomEnabled(value: boolean): void { this.controller?.getUiSettings?.().setZoomGesturesEnabled(value); }
  setZoomControlEnabled(value: boolean): void { this.controller?.getUiSettings?.().setZoomControlsEnabled(value); }
  setScrollEnabled(value: boolean): void { this.controller?.getUiSettings?.().setScrollGesturesEnabled(value); }
  setRotateEnabled(value: boolean): void { this.controller?.getUiSettings?.().setRotateGesturesEnabled(value); }
  setPitchEnabled(value: boolean): void { this.controller?.getUiSettings?.().setTiltGesturesEnabled(value); }
  setShowsUserLocation(value: boolean): void { this.controller?.setMyLocationEnabled?.(value); }
  setShowsMyLocationButton(value: boolean): void { this.controller?.getUiSettings?.().setMyLocationButtonEnabled(value); }
  setShowsCompass(value: boolean): void { this.controller?.getUiSettings?.().setCompassEnabled(value); }
  setShowsScale(value: boolean): void { this.controller?.getUiSettings?.().setScaleControlsEnabled(value); }
  setShowsTraffic(value: boolean): void { this.controller?.setTrafficEnabled?.(value); }
  setShowsBuildings(value: boolean): void { this.controller?.showBuildings?.(value); }
  setShowsIndoors(value: boolean): void { this.controller?.showIndoorMap?.(value); }
  setShowsIndoorLevelPicker(value: boolean): void { this.controller?.getUiSettings?.().setIndoorSwitchEnabled(value); }
  setShowsPointsOfInterest(value: boolean): void { this.controller?.showMapText?.(value); }

  // Viewport -------------------------------------------------------------------
  setInitialRegion(region: CnRegion): void {
    if (this.didApplyInitialRegion || this.didApplyInitialCamera) {
      return;
    }
    this.pendingInitialRegion = region;
    this.applyPendingInitialCamera();
  }

  setRegion(region: CnRegion): void { this.moveToRegion(region, false, 0); }

  setInitialCamera(camera: CnCamera): void {
    if (this.didApplyInitialCamera) {
      return;
    }
    this.pendingInitialCamera = camera;
    this.applyPendingInitialCamera();
  }

  setCamera(camera: CnCamera): void { this.moveToCamera(camera, false, 0); }

  animateToRegion(region: CnRegion, duration: number): void { this.moveToRegion(region, true, duration); }

  applyCamera(camera: CnCamera, animated: boolean, duration: number): void {
    let resolved = camera;
    if (camera.latitude === 0 && camera.longitude === 0 && this.controller !== null) {
      const target: ESObject = this.controller.getCameraPosition().target; // 查证
      // ArkTS has no object spread — construct explicitly.
      resolved = {
        latitude: target.latitude, longitude: target.longitude,
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
      const bounds: ESObject = this.controller.getProjection().getVisibleRegion().latLngBounds; // 查证
      const target: ESObject = this.controller.getCameraPosition().target;
      return {
        latitude: target.latitude,
        longitude: target.longitude,
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
    const p: ESObject = this.controller.getCameraPosition();
    return {
      latitude: p.target.latitude, longitude: p.target.longitude,
      heading: p.bearing, pitch: p.tilt, zoom: p.zoom, altitude: 0,
    };
  }

  mapBoundaries(): [CnLatLng, CnLatLng] | null {
    if (this.controller === null) {
      return null;
    }
    try {
      const bounds: ESObject = this.controller.getProjection().getVisibleRegion().latLngBounds;
      return [
        { latitude: bounds.northeast.latitude, longitude: bounds.northeast.longitude },
        { latitude: bounds.southwest.latitude, longitude: bounds.southwest.longitude },
      ];
    } catch (_e) {
      return null;
    }
  }

  fitToCoordinates(coordinates: CnLatLng[], edgePadding: CnEdgeInsets, animated: boolean): void {
    if (coordinates.length === 0 || this.controller === null) {
      return;
    }
    // 查证: LatLngBounds.Builder() then CameraUpdateFactory.newLatLngBoundsRect.
    const bounds: ESObject = this.boundsFromCoordinates(coordinates);
    this.applyBounds(bounds, edgePadding, animated);
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
    if (this.controller === null) {
      return;
    }
    try {
      this.controller.setMapStatusLimits(this.latLngBounds(sw, ne)); // 查证
    } catch (_e) {
    }
  }

  // Projection -----------------------------------------------------------------
  pointForCoordinate(coordinate: CnLatLng): CnPoint | null {
    if (this.controller === null) {
      return null;
    }
    try {
      const p: ESObject = this.controller.getProjection().toScreenLocation(this.latLng(coordinate)); // 查证
      return { x: p.x, y: p.y };
    } catch (_e) {
      return null;
    }
  }

  coordinateForPoint(xPx: number, yPx: number): CnLatLng | null {
    if (this.controller === null) {
      return null;
    }
    try {
      // fromScreenLocation(point, callback) 是异步版；同步取值须用 fromScreenLocationSync。
      const ll: ESObject = this.controller.getProjection().fromScreenLocationSync({ x: xPx, y: yPx });
      return ll !== null && ll !== undefined ? { latitude: ll.latitude, longitude: ll.longitude } : null;
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
    // 真实签名 getMapScreenShot(listener: OnMapScreenShotListener)，listener 是对象
    // { onMapScreenShot: (bitmap?: PixelMap, status: number) => void }；此前传裸函数 SDK 收不到。
    this.controller.getMapScreenShot({
      onMapScreenShot: (bitmap: image.PixelMap | undefined, _status: number) => {
        if (bitmap === undefined) {
          completion('');
          return;
        }
        this.encodeSnapshot(bitmap, width, height, format, quality, result)
          .then((uri) => completion(uri))
          .catch(() => completion(''));
      },
    });
  }

  private async encodeSnapshot(pixelMap: image.PixelMap, width: number, height: number, format: string, quality: number, result: string): Promise<string> {
    try {
      const isJpg = format === 'jpg' || format === 'jpeg';
      const q = Math.round(Math.max(0, Math.min(1, quality)) * 100);
      const packer = image.createImagePacker();
      const data: ArrayBuffer = await packer.packing(pixelMap, {
        format: isJpg ? 'image/jpeg' : 'image/png',
        quality: q,
      });
      if (result === 'base64') {
        const base64 = new util.Base64Helper();
        return base64.encodeToStringSync(new Uint8Array(data));
      }
      const ext = isJpg ? 'jpg' : 'png';
      const path = `${this.context.cacheDir}/map-snapshot-${Date.now()}.${ext}`;
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      fs.writeSync(file.fd, data);
      fs.closeSync(file);
      return `file://${path}`;
    } catch (_e) {
      return '';
    }
  }

  // Reverse geocoding ----------------------------------------------------------
  // AMap HarmonyOS search SDK; coordinates are GCJ-02 (consistent with Android).
  addressForCoordinate(latitude: number, longitude: number, completion: (address: CnAddress | null) => void): void {
    try {
      // 查证: AMap HarmonyOS GeocodeSearch / RegeocodeQuery equivalents.
      const search: ESObject = this.controller?.createGeocodeSearch?.() ?? null;
      if (search === null) {
        completion(null);
        return;
      }
      search.setOnGeocodeSearchListener((result: ESObject, code: number) => {
        const addr: ESObject = result?.regeocodeAddress;
        if (code !== 1000 || addr === null || addr === undefined) {
          completion(null);
          return;
        }
        const city: string = (addr.city !== undefined && addr.city.length > 0) ? addr.city : (addr.province ?? '');
        completion({
          name: addr.formatAddress ?? '',
          thoroughfare: addr.streetNumber?.street ?? addr.township ?? '',
          subThoroughfare: addr.streetNumber?.number ?? '',
          locality: city,
          subLocality: addr.district ?? '',
          administrativeArea: addr.province ?? '',
          subAdministrativeArea: addr.district ?? '',
          postalCode: '',
          countryCode: 'CN',
          country: '中国',
        });
      });
      search.getFromLocationAsyn({ latitude, longitude, radius: 200 });
    } catch (_e) {
      completion(null);
    }
  }

  // Markers --------------------------------------------------------------------
  addMarker(model: CnMarkerModel, childId: string): OverlayHandle {
    const handle = new OverlayHandle(childId);
    this.markerHandles.push(handle);
    this.markerModels.set(handle, model);
    if (this.controller === null) {
      this.pendingAdds.push(handle);
    } else {
      this.addSdkMarker(model, handle);
    }
    return handle;
  }

  // marker 加到地图。custom/image 位图同步可取、直接 add；默认彩色图钉的位图必须用
  // applicationContext 异步 defaultMarkerASync 加载——传 uiAbilityContext 会 resolve 出无位图的
  // 空 descriptor（marker 加进去却不可见）。故默认图钉「先 await 取图标 → 再 addMarker」。
  private addSdkMarker(model: CnMarkerModel, handle: OverlayHandle): void {
    const options: ESObject = new MarkerOptions();
    options.setPosition(this.latLng({ latitude: model.latitude, longitude: model.longitude }));
    options.setDraggable(model.draggable);
    options.setAnchor(model.anchorU, model.anchorV);
    options.setAlpha(model.opacity);
    options.setFlat(model.flat);
    options.setRotateAngle(rnRotationToAMap(model.rotation));
    options.setZIndex(model.zIndex);
    options.setClickable(true);
    if (model.title !== null) options.setTitle(model.title);
    if (model.snippet !== null) options.setSnippet(model.snippet);
    this.resolveMarkerIcon(model).then((icon: ESObject) => {
      if (icon !== null && icon !== undefined) {
        options.setIcon(icon);
      }
      this.commitSdkMarker(options, handle);
    }).catch((e: ESObject) => {
      hilog.warn(0x0000, 'cnmaps', 'amap resolveMarkerIcon failed: %{public}s', JSON.stringify(e));
      this.commitSdkMarker(options, handle);
    });
  }

  private commitSdkMarker(options: ESObject, handle: OverlayHandle): void {
    if (this.controller === null) {
      return;
    }
    const marker: ESObject = this.controller.addMarker(options);
    marker.setObject(handle);
    handle.sdkObject = marker;
  }

  // 高德鸿蒙图标资源加载须用 applicationContext；uiAbilityContext 传给 defaultMarkerASync
  // 拿不到位图。回退到自身以防运行时无该方法。
  private applicationContext(): ESObject {
    const c: ESObject = this.context;
    return (c.getApplicationContext !== undefined) ? c.getApplicationContext() : c;
  }

  updateMarker(handle: OverlayHandle, model: CnMarkerModel): void {
    const marker: ESObject = handle.sdkObject;
    if (marker === null) {
      this.markerModels.set(handle, model);
      return;
    }
    const previous = this.markerModels.get(handle);
    marker.setPosition(this.latLng({ latitude: model.latitude, longitude: model.longitude }));
    marker.setTitle(model.title ?? '');
    marker.setSnippet(model.snippet ?? '');
    marker.setDraggable(model.draggable);
    marker.setAnchor(model.anchorU, model.anchorV);
    marker.setAlpha(model.opacity);
    marker.setFlat(model.flat);
    marker.setRotateAngle(rnRotationToAMap(model.rotation));
    marker.setZIndex(model.zIndex);
    if (previous === undefined ||
      previous.customBitmap !== model.customBitmap ||
      previous.iconBitmap !== model.iconBitmap ||
      previous.pinColor !== model.pinColor ||
      previous.imageUri !== model.imageUri) {
      this.resolveMarkerIcon(model).then((icon: ESObject) => {
        if (icon !== null && icon !== undefined) {
          marker.setIcon(icon);
        }
      }).catch(() => {});
    }
    this.markerModels.set(handle, model);
  }

  removeMarker(handle: OverlayHandle): void {
    this.removeSdkMarker(handle.sdkObject);
    this.markerHandles = this.markerHandles.filter((h) => h !== handle);
    this.markerModels.delete(handle);
  }

  showCallout(handle: OverlayHandle): void { (handle.sdkObject as ESObject)?.showInfoWindow?.(); }
  hideCallout(handle: OverlayHandle): void { (handle.sdkObject as ESObject)?.hideInfoWindow?.(); }
  redrawCallout(handle: OverlayHandle): void {
    const m: ESObject = handle.sdkObject;
    if (m !== null && m.isInfoWindowShown?.()) {
      m.showInfoWindow();
    }
  }

  animateMarker(handle: OverlayHandle, latitude: number, longitude: number, duration: number): void {
    const marker: ESObject = handle.sdkObject;
    if (marker === null) {
      return;
    }
    if (duration <= 0) {
      marker.setPosition(this.latLng({ latitude, longitude }));
      return;
    }
    // 查证: drive a value animation on the ArkUI side (no Android ValueAnimator).
    // Simple stepped interpolation over `duration` ms via setInterval as a placeholder.
    const start: CnLatLng = { latitude: marker.getPosition().latitude, longitude: marker.getPosition().longitude };
    const steps = 30;
    let i = 0;
    const id = setInterval(() => {
      i++;
      const t = i / steps;
      marker.setPosition(this.latLng({
        latitude: start.latitude + (latitude - start.latitude) * t,
        longitude: start.longitude + (longitude - start.longitude) * t,
      }));
      if (i >= steps) {
        clearInterval(id);
      }
    }, Math.max(1, Math.round(duration / steps)));
  }

  markerScreenPoint(handle: OverlayHandle): CnPoint | null {
    const marker: ESObject = handle.sdkObject;
    if (marker === null || this.controller === null) {
      return null;
    }
    try {
      const p: ESObject = this.controller.getProjection().toScreenLocation(marker.getPosition());
      return { x: p.x, y: p.y };
    } catch (_e) {
      return null;
    }
  }

  markerPosition(handle: OverlayHandle): CnLatLng | null {
    const marker: ESObject = handle.sdkObject;
    if (marker === null) {
      return null;
    }
    const pos: ESObject = marker.getPosition();
    return { latitude: pos.latitude, longitude: pos.longitude };
  }

  // 同步图标：只有已解码的 PixelMap（custom/image bitmap）能同步取 descriptor。
  private syncDescriptorFor(model: CnMarkerModel): ESObject {
    if (model.customBitmap !== null) return BitmapDescriptorFactory.fromPixelMapSync(model.customBitmap);
    if (model.iconBitmap !== null) return BitmapDescriptorFactory.fromPixelMapSync(model.iconBitmap);
    return null;
  }

  // 统一解析 marker 图标（异步）。优先级：custom/image 已解码位图(同步) > image uri(异步下载解码)
  // > 默认彩色图钉(applicationContext 异步 defaultMarkerASync)。image 加载失败则回退默认图钉。
  private async resolveMarkerIcon(model: CnMarkerModel): Promise<ESObject> {
    const sync: ESObject = this.syncDescriptorFor(model);
    if (sync !== null) {
      return sync;
    }
    if (model.imageUri !== null) {
      const pm = await this.loadPixelMapFromUri(model.imageUri);
      if (pm !== null) {
        return BitmapDescriptorFactory.fromPixelMapSync(pm);
      }
    }
    const hue = markerHue(model.pinColor);
    const factory: ESObject = BitmapDescriptorFactory;
    const appCtx: ESObject = this.applicationContext();
    return hue !== null ? await factory.defaultMarkerASync(appCtx, hue) : await factory.defaultMarkerASync(appCtx);
  }

  // RN image uri (asset:// | data: | http(s)://) → PixelMap；失败返回 null。带 uri 缓存。
  // Metro 模式下本地 require 图与网络图都是 http(s) URL，统一走 http 下载解码。
  private async loadPixelMapFromUri(uri: string): Promise<image.PixelMap | null> {
    const cached = this.imageCache.get(uri);
    if (cached !== undefined) {
      return cached;
    }
    let pm: image.PixelMap | null = null;
    try {
      if (uri.startsWith('asset://')) {
        const ctx: ESObject = this.context;
        const bytes: ESObject = ctx.resourceManager.getRawFileContentSync('assets/' + uri.substring(8));
        const src: ESObject = image.createImageSource(bytes.buffer);
        pm = src !== null ? await src.createPixelMap() : null;
      } else if (uri.startsWith('data:')) {
        const src: ESObject = image.createImageSource(uri);
        pm = src !== null ? await src.createPixelMap() : null;
      } else {
        // Metro dev：RNOH resolveAssetSource 生成的 asset uri 形如
        // `.../assets/../src/examples/assets/x.png`（路径相对 projectRoot=example/harmony、带
        // /assets/ 前缀），但 Metro serverRoot 是仓库根，需转成相对仓库根的
        // `.../example/src/examples/assets/x.png`（release bundle 用 asset://，不走此分支）。
        const fetchUri = uri.replace('/assets/..', '/example');
        const req = http.createHttp();
        const resp = await req.request(fetchUri, { expectDataType: http.HttpDataType.ARRAY_BUFFER });
        req.destroy();
        const body: ESObject = resp.result;
        if (body !== null && body !== undefined && (body as ArrayBuffer).byteLength > 0) {
          const src: ESObject = image.createImageSource(body as ArrayBuffer);
          pm = src !== null ? await src.createPixelMap() : null;
        }
      }
    } catch (e) {
      hilog.warn(0x0000, 'cnmaps', 'amap load image failed uri=%{public}s: %{public}s', uri, JSON.stringify(e));
      pm = null;
    }
    if (pm !== null) {
      this.imageCache.set(uri, pm);
    }
    return pm;
  }

  private removeSdkMarker(sdkObject: Object | null): void {
    (sdkObject as ESObject)?.remove?.();
  }

  // Overlays -------------------------------------------------------------------
  addOverlay(model: CnOverlayModel, childId: string): OverlayHandle {
    const handle = new OverlayHandle(childId);
    this.overlayHandles.push(handle);
    this.overlayModels.set(handle, model);
    if (this.controller === null) {
      this.pendingAdds.push(handle);
    } else {
      this.materializeOverlay(model, handle);
    }
    return handle;
  }

  updateOverlay(handle: OverlayHandle, model: CnOverlayModel): void {
    this.removeSdkOverlay(handle.sdkObject);
    handle.sdkObject = null;
    if (this.controller !== null) {
      this.materializeOverlay(model, handle);
    }
    this.overlayModels.set(handle, model);
  }

  removeOverlay(handle: OverlayHandle): void {
    this.removeSdkOverlay(handle.sdkObject);
    this.overlayHandles = this.overlayHandles.filter((h) => h !== handle);
    this.overlayModels.delete(handle);
  }

  private removeSdkOverlay(sdkObject: Object | null): void {
    (sdkObject as ESObject)?.remove?.();
  }

  // overlay 上图。groundOverlay 的图片位图若尚未解码但有 imageUri，则异步下载解码后再上图。
  private materializeOverlay(model: CnOverlayModel, handle: OverlayHandle): void {
    if (model.kind === 'groundOverlay') {
      const g = model as CnGroundOverlayModel;
      if (g.bitmap === null && g.imageUri !== null) {
        this.loadPixelMapFromUri(g.imageUri).then((pm: image.PixelMap | null) => {
          if (pm !== null && this.controller !== null) {
            g.bitmap = pm;
            try {
              handle.sdkObject = this.buildGroundOverlay(g);
            } catch (e) {
              hilog.warn(0x0000, 'cnmaps', 'amap groundOverlay build failed: %{public}s', JSON.stringify(e));
            }
          }
        }).catch((e: ESObject) => hilog.warn(0x0000, 'cnmaps', 'amap groundOverlay image load failed: %{public}s', JSON.stringify(e)));
        return;
      }
    }
    handle.sdkObject = this.buildOverlay(model);
  }

  private buildOverlay(model: CnOverlayModel): ESObject {
    switch (model.kind) {
      case 'polyline': return this.buildPolyline(model);
      case 'polygon': return this.buildPolygon(model);
      case 'circle': return this.buildCircle(model);
      case 'heatmap': return this.buildHeatmap(model);
      case 'urlTile': return this.buildUrlTile(model);
      case 'localTile': return this.buildLocalTile(model);
      case 'groundOverlay': return this.buildGroundOverlay(model);
      default: return null;
    }
  }

  // P5 overlays — ported from AMapAdapter.kt. 查证 AMap HarmonyOS support for
  // HeatmapTileProvider / UrlTileProvider / TileProvider / GroundOverlay.
  private buildHeatmap(model: CnHeatmapModel): ESObject {
    if (model.points.length === 0) {
      return null;
    }
    // 真实高德鸿蒙 SDK：new WeightedLatLng(latLng, intensity) → new HeatMapBuilder()
    // .weightedData().setRadius().setGradient() → new HeatmapTileProvider(builder) →
    // aMap.addTileOverlay(new TileOverlayOptions().tileProvider(provider))。
    // 早前用 controller.createXxx 系列（Android 港来的占位方法，鸿蒙 SDK 无）导致热力图不渲染。
    const weighted: ESObject[] = model.points.map((p): ESObject => new WeightedLatLng(this.latLng({ latitude: p.latitude, longitude: p.longitude }), p.weight));
    const builder: ESObject = new HeatMapBuilder();
    builder.weightedData(weighted);
    builder.setRadius(model.radius);
    const colors = model.gradientColors;
    const starts = model.gradientStartPoints;
    if (colors !== null && starts !== null && colors.length > 0 && colors.length === starts.length) {
      builder.setGradient(new Gradient(colors, starts));
    }
    const provider: ESObject = new HeatmapTileProvider(builder);
    return this.controller.addTileOverlay(new TileOverlayOptions().tileProvider(provider));
  }

  private buildUrlTile(model: CnUrlTileModel): ESObject {
    const template = model.urlTemplate;
    if (template === null) {
      return null;
    }
    // 查证: AMap HarmonyOS UrlTileProvider equivalent (an object that, given x/y/z,
    // returns a tile URL). The url-building logic below is ported 1:1 from Kotlin.
    const provider: ESObject = this.controller.createUrlTileProvider(model.tileSize, model.tileSize, (x: number, y: number, zoom: number): string | null => {
      if (zoom < model.minimumZ || zoom > model.maximumZ) {
        return null;
      }
      if (model.wms) {
        return wmsUrl(template, x, y, zoom, model.tileSize);
      }
      const yy = model.flipY ? (1 << zoom) - 1 - y : y;
      return template.replace('{x}', `${x}`).replace('{y}', `${yy}`).replace('{z}', `${zoom}`);
    });
    const options: ESObject = this.controller.createTileOverlayOptions().tileProvider(provider).zIndex(model.zIndex);
    if (model.diskCacheDir !== null && model.diskCacheDir.length > 0) {
      options.diskCacheEnabled(true).diskCacheDir(model.diskCacheDir);
    }
    return this.controller.addTileOverlay(options);
  }

  private buildLocalTile(model: CnLocalTileModel): ESObject {
    const template = model.pathTemplate;
    if (template === null) {
      return null;
    }
    // 查证: read tile bytes from rawfile (useAssets) via resourceManager, else from
    // the filesystem (@ohos.file.fs). The TileProvider returns the tile bytes.
    const provider: ESObject = this.controller.createTileProvider(model.tileSize, model.tileSize, (x: number, y: number, zoom: number): ArrayBuffer | null => {
      const path = template.replace('{x}', `${x}`).replace('{y}', `${y}`).replace('{z}', `${zoom}`);
      try {
        if (model.useAssets) {
          // 查证: this.context.resourceManager.getRawFileContentSync(path)
          return this.context.resourceManager.getRawFileContentSync(path).buffer as ArrayBuffer;
        }
        const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(path);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        fs.closeSync(file);
        return buf;
      } catch (_e) {
        return null;
      }
    });
    return this.controller.addTileOverlay(this.controller.createTileOverlayOptions().tileProvider(provider).zIndex(model.zIndex));
  }

  private buildGroundOverlay(model: CnGroundOverlayModel): ESObject {
    const sw = model.southWest;
    const ne = model.northEast;
    const bmp = model.bitmap;
    if (sw === null || ne === null || bmp === null) {
      return null; // 位图未解码完成（materializeOverlay 会异步解码后重新上图）。
    }
    // 鸿蒙 GroundOverlayOptions setter 为 setBearing/setZIndex/setTransparency（带 set 前缀）；
    // 早前误用无前缀的 bearing()/transparency()/zIndex() 才抛异常。核心用 image + positionFromBounds。
    const options: ESObject = new GroundOverlayOptions();
    options.image(BitmapDescriptorFactory.fromPixelMapSync(bmp));
    options.positionFromBounds(this.latLngBounds(sw, ne));
    options.visible(true);
    options.setZIndex(model.zIndex);
    const opacity = model.opacity;
    if (opacity >= 0 && opacity <= 1) options.setTransparency(1 - opacity);
    return this.controller.addGroundOverlay(options);
  }

  private buildPolyline(model: CnPolylineModel): ESObject {
    // 真实 AMap：new PolylineOptions().setPoints(LatLng[]).setXxx(...) → aMap.addPolyline。
    const options: ESObject = new PolylineOptions();
    options.setPoints(model.coordinates.map((c): ESObject => this.latLng(c)));
    options.setWidth(model.strokeWidth);
    options.setZIndex(model.zIndex);
    options.setGeodesic(model.geodesic);
    options.setDottedLine(model.dashed);
    if (model.strokeColors.length > 1) {
      // 真实 SDK setColorValues 收 Int32Array（非 number[]）；ARGB 值可能超 int32 正范围，
      // 用 `| 0` 折成有符号 32 位塞进 Int32Array。
      options.setColorValues(Int32Array.from(model.strokeColors.map((c): number => c | 0)));
      options.setGradient(true);
    } else if (model.strokeColors.length === 1) {
      options.setColor(model.strokeColors[0]);
    } else {
      options.setColor(model.strokeColor);
    }
    return this.controller.addPolyline(options);
  }

  private buildPolygon(model: CnPolygonModel): ESObject {
    const options: ESObject = new PolygonOptions();
    options.setPoints(model.coordinates.map((c): ESObject => this.latLng(c)));
    options.setStrokeColor(model.strokeColor);
    options.setFillColor(model.fillColor);
    options.setStrokeWidth(model.strokeWidth);
    options.setZIndex(model.zIndex);
    model.holes.forEach((ring) => { options.addHoles(ring.map((c): ESObject => this.latLng(c))); });
    return this.controller.addPolygon(options);
  }

  private buildCircle(model: CnCircleModel): ESObject {
    const options: ESObject = new CircleOptions();
    options.setCenter(this.latLng(model.center));
    options.setRadius(model.radius);
    options.setStrokeColor(model.strokeColor);
    options.setFillColor(model.fillColor);
    options.setStrokeWidth(model.strokeWidth);
    options.setZIndex(model.zIndex);
    return this.controller.addCircle(options);
  }

  // Listeners ------------------------------------------------------------------
  private configureListeners(): void {
    const c: ESObject = this.controller;
    if (c === null) {
      return;
    }
    // 真实 AMap 监听器（方法名/回调形式据 AMap.d.ets：onMapClick/onMapLongClick 传
    // (point:LatLng)=>void 函数；markerClick 传 (marker)=>boolean；camera/drag 传对象；
    // POI 是 addOnPOIClickListener 而非 set*）。每个监听器单独兜底：某个 API 不符只跳过它，
    // 不影响其余注册（此前 setOnPOIClickListener 不存在会抛错、中断整段注册）。
    // 每个监听器单独 try：某 API 不符只跳过它，不影响其余注册（此前 setOnPOIClickListener
    // 不存在会抛错、中断整段）。setOnXxx 直接作为语句调用（非箭头表达式体，避开 ArkTS 返回类型推断）。
    try {
      c.setOnCameraChangeListener({
        onCameraChange: () => this.delegate?.onRegionChange(false, this.isGesture),
        onCameraChangeFinish: () => { this.delegate?.onRegionChange(true, this.isGesture); this.isGesture = false; },
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap cameraChange listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.setOnMapClickListener((ll: ESObject) => {
        if (ll !== null) {
          this.delegate?.onMapPress(CnPressKind.PRESS, { latitude: ll.latitude, longitude: ll.longitude }, this.screenPointFor(ll));
        }
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap mapClick listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.setOnMapLongClickListener((ll: ESObject) => {
        if (ll !== null) {
          this.delegate?.onMapPress(CnPressKind.LONG_PRESS, { latitude: ll.latitude, longitude: ll.longitude }, this.screenPointFor(ll));
        }
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap mapLongClick listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.addOnPOIClickListener((poi: ESObject) => {
        const coord: ESObject = poi?.coordinate;
        if (coord !== undefined && coord !== null) {
          this.delegate?.onPoiClick({ placeId: poi.poiId ?? null, name: poi.name ?? null, latitude: coord.latitude, longitude: coord.longitude });
        }
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap poiClick listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.setOnMyLocationChangeListener((loc: ESObject) => {
        if (loc !== null) {
          this.delegate?.onUserLocationChange({
            latitude: loc.latitude, longitude: loc.longitude, altitude: loc.altitude ?? 0,
            accuracy: loc.accuracy ?? 0, speed: loc.speed ?? 0, heading: loc.bearing ?? 0,
            isFromMockProvider: loc.isFromMockProvider ?? false,
          });
        }
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap myLocation listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.setOnMarkerClickListener((marker: ESObject): boolean => {
        const handle = marker.getObject() as OverlayHandle | null;
        const coordinate: CnLatLng = { latitude: marker.getPosition().latitude, longitude: marker.getPosition().longitude };
        if (handle !== null) {
          this.delegate?.onMarkerEvent(handle.childId, CnMarkerEvent.PRESS, coordinate);
          this.delegate?.onMarkerEvent(handle.childId, CnMarkerEvent.SELECT, coordinate);
          if (this.markerModels.get(handle)?.hasInfoWindowContent === true) {
            marker.showInfoWindow();
          }
        }
        return true;
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap markerClick listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.setOnMarkerDragListener({
        onMarkerDragStart: (m: ESObject) => this.deliverDrag(m, CnMarkerEvent.DRAG_START),
        onMarkerDrag: (m: ESObject) => this.deliverDrag(m, CnMarkerEvent.DRAG),
        onMarkerDragEnd: (m: ESObject) => this.deliverDrag(m, CnMarkerEvent.DRAG_END),
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap markerDrag listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.setOnInfoWindowClickListener((m: ESObject) => {
        const handle = m?.getObject() as OverlayHandle | null;
        if (handle !== null) {
          this.delegate?.onMarkerEvent(handle.childId, CnMarkerEvent.CALLOUT_PRESS, { latitude: m.getPosition().latitude, longitude: m.getPosition().longitude });
        }
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap infoWindowClick listener skipped: %{public}s', JSON.stringify(e)); }
    try {
      c.setOnPolylineClickListener((clicked: ESObject) => {
        this.overlayHandles.forEach((handle) => {
          if (handle.sdkObject === clicked) {
            const model = this.overlayModels.get(handle);
            if (model !== undefined && model.kind === 'polyline' && model.tappable) {
              this.delegate?.onOverlayPress(handle.childId);
            }
          }
        });
      });
    } catch (e) { hilog.warn(0x0000, 'cnmaps', 'amap polylineClick listener skipped: %{public}s', JSON.stringify(e)); }
    // onPanDrag / onDoublePress 已在 host 层用并行 PanGesture / TapGesture(count:2) 接上
    // （见 CnMapHostComponent，AMap 本身无对应回调，故在 ArkUI 手势层补齐）。
  }

  private deliverDrag(marker: ESObject, event: CnMarkerEvent): void {
    const handle = marker?.getObject() as OverlayHandle | null;
    if (handle !== null) {
      this.delegate?.onMarkerEvent(handle.childId, event, { latitude: marker.getPosition().latitude, longitude: marker.getPosition().longitude });
    }
  }

  // Camera helpers (ported 1:1 from Kotlin) ------------------------------------
  private applyPendingInitialCamera(): void {
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
    // CnRegion(center + delta) → 真实 CameraUpdateFactory.newLatLngZoom（由经度跨度估算 zoom）。
    const center: ESObject = new LatLng(region.latitude, region.longitude);
    const update: ESObject = CameraUpdateFactory.newLatLngZoom(center, this.zoomForRegion(region));
    this.applyCameraUpdate(update, animated, duration);
  }

  // 由经度跨度估算高德 zoom（整个世界 360° ≈ zoom 1，跨度每减半 zoom+1），钳制到 3~20。
  private zoomForRegion(region: CnRegion): number {
    const delta: number = Math.max(region.longitudeDelta, MIN_DELTA);
    const zoom: number = Math.log2(360 / delta);
    return Math.max(3, Math.min(20, zoom));
  }

  private moveToCamera(camera: CnCamera, animated: boolean, duration: number): void {
    if (this.controller === null) {
      return;
    }
    const cur: ESObject = this.controller.getCameraPosition();
    const zoom: number = camera.zoom > 0 ? camera.zoom : (cur !== null && cur !== undefined ? cur.zoom as number : 10);
    const target: ESObject = new LatLng(camera.latitude, camera.longitude);
    // 完整应用 center + zoom + tilt(pitch) + bearing(heading)——否则相机命令的旋转/俯仰不生效
    // （CameraPosition 构造参数顺序为 target, zoom, tilt, bearing）。
    const pos: ESObject = new CameraPosition(target, zoom, camera.pitch, camera.heading);
    const update: ESObject = CameraUpdateFactory.newCameraPosition(pos);
    this.applyCameraUpdate(update, animated, duration);
  }

  private applyCameraUpdate(update: ESObject, animated: boolean, duration: number): void {
    if (animated) {
      // 真实签名 animateCamera(update, callback?, duration?)：duration 是第 3 个参数，第 2 个
      // 是 CancelableCallback（传 undefined）。此前误把 duration 当 callback，导致动画不生效。
      this.controller.animateCamera(update, undefined, duration);
    } else {
      this.controller.moveCamera(update);
    }
  }

  private applyBounds(bounds: ESObject, edgePadding: CnEdgeInsets, animated: boolean): void {
    // 真实 SDK：CameraUpdateFactory.newLatLngBoundsRect（静态），非 controller.newLatLngBoundsRect。
    const update: ESObject = CameraUpdateFactory.newLatLngBoundsRect(bounds, edgePadding.left, edgePadding.right, edgePadding.top, edgePadding.bottom);
    this.applyCameraUpdate(update, animated, 300);
  }

  // SDK value constructors (查证 — map to real AMap HarmonyOS types) -------------
  private latLng(c: CnLatLng): ESObject { return new LatLng(c.latitude, c.longitude); }
  private latLngBounds(sw: CnLatLng, ne: CnLatLng): ESObject { return new LatLngBounds(this.latLng(sw), this.latLng(ne)); }
  private cameraPosition(lat: number, lng: number, zoom: number, tilt: number, bearing: number): ESObject {
    return this.controller.createCameraPosition(this.latLng({ latitude: lat, longitude: lng }), zoom, tilt, bearing);
  }
  private boundsFromCoordinates(coords: CnLatLng[]): ESObject {
    // 真实 SDK：LatLngBounds.builder() 静态工厂，非 controller.createLatLngBoundsBuilder。
    const builder: ESObject = LatLngBounds.builder();
    coords.forEach((c) => { builder.include(this.latLng(c)); });
    return builder.build();
  }

  // Pure helpers (ported 1:1 from Kotlin) --------------------------------------
  private regionToBounds(region: CnRegion): ESObject {
    const halfLat = Math.max(region.latitudeDelta, MIN_DELTA) / 2.0;
    const halfLon = Math.max(region.longitudeDelta, MIN_DELTA) / 2.0;
    const sw: CnLatLng = { latitude: Math.max(-90, region.latitude - halfLat), longitude: Math.max(-180, region.longitude - halfLon) };
    const ne: CnLatLng = { latitude: Math.min(90, region.latitude + halfLat), longitude: Math.min(180, region.longitude + halfLon) };
    return this.latLngBounds(sw, ne);
  }

  private screenPointFor(ll: ESObject): CnPoint | null {
    try {
      const p: ESObject = this.controller.getProjection().toScreenLocation(ll);
      return { x: p.x, y: p.y };
    } catch (_e) {
      return null;
    }
  }

}
