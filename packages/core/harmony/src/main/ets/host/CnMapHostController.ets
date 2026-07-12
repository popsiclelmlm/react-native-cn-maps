/*
 * Provider-agnostic host logic for `RNMapsMapView`. Owns child routing, command
 * handling and event emission; the map provider is encapsulated behind a
 * CnMapAdapter obtained from the registry, so this file carries zero SDK refs.
 *
 * ArkTS port of core/android `MapView.kt`. Because an ArkUI `@Component struct`
 * cannot implement an interface, the struct (CnMapHostComponent) stays thin and
 * delegates to this plain class, which implements CnMapAdapterDelegate. The struct
 * injects two RNOH-specific callbacks — `emit` (component events) and `getChildren`
 * (read child descriptors) — keeping all framework version specifics in the struct.
 */
import common from '@ohos.app.ability.common';
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import { CnMapAdapter, CnMapBuilder } from '../adapter/CnMapAdapter';
import { CnMapAdapterDelegate } from '../adapter/CnMapAdapterDelegate';
import { CnMapAdapterRegistry } from '../adapter/CnMapAdapterRegistry';
import {
  CnAddress, CnCamera, CnEdgeInsets, CnLatLng, CnMarkerEvent, CnPoi, CnPressKind, CnRegion,
  CnUserLocation, CnPoint, CN_EDGE_INSETS_ZERO
} from '../adapter/CnMapModels';
import { OverlayHandle } from '../adapter/OverlayHandle';
import { NativeCameraProp, NativeRegionProp, RNMapsMapViewProps } from './RNMapsMapViewDescriptor';
import { buildMarkerModel, buildOverlayModel, MARKER_COMPONENT_NAME, PropBag } from './ChildModelBuilder';
import {
  AddressDataP, BoundariesDataP, CameraDataP, CommandResultEventP, EMPTY_PAYLOAD, LatLngP,
  MarkerChildEventP, MarkerEventP, MarkerFrameP, OverlayPressEventP, PoiClickEventP, PositionP,
  PressEventP, RegionChangeEventP, SnapshotDataP, UserLocationChangeEventP
} from './EventPayloads';

// RNOH 0.72 会在某些 prop 变化（如 camera）时 re-create 自定义组件（CnMapHostComponent
// aboutToAppear 重跑 → 新 controller/adapter），使地图重置回 initialRegion、丢失用户已设的
// camera/region。用模块级缓存记住最后一次 controlled 视口，re-mount 后新地图据此恢复。
// （example 为单地图；多地图场景需按 tag 键分隔。）
let lastControlledCamera: CnCamera | null = null;
let lastControlledRegion: CnRegion | null = null;

export interface ChildNode {
  tag: number;
  componentName: string;
  props: PropBag;
}

// (eventName, payload) → RNOH component event. Payload is a typed object (see
// EventPayloads). 查证: emit API + event-name strings must match codegen output
// (see CnMapHostComponent where this is supplied).
export type EmitEventFn = (eventName: string, payload: Object) => void;

// 直接对某个子节点 tag 派发组件事件（用于 Marker 事件——它们发在 Marker 子节点上，
// 不是 host 上）。由 CnMapHostComponent 用 rnInstance.emitComponentEvent(childTag,…) 提供。
export type EmitChildEventFn = (childTag: number, eventName: string, payload: Object) => void;

interface TrackedChild {
  handle: OverlayHandle;
  isMarker: boolean;
  identifier: string | null;
  propsHash: string; // 上次同步时子 props 的快照，未变则跳过 update（避免滚动/无关刷新时重建覆盖物）
}

// CnMarkerEvent → Marker 的 codegen 规范事件名（generated/components/RNMapsMarker.ts 的
// EventPayloadByName：press/select/deselect/calloutPress/dragStart/drag/dragEnd）。
function markerChildEventName(event: CnMarkerEvent): string | null {
  switch (event) {
    case CnMarkerEvent.PRESS: return 'press';
    case CnMarkerEvent.SELECT: return 'select';
    case CnMarkerEvent.DESELECT: return 'deselect';
    case CnMarkerEvent.CALLOUT_PRESS: return 'calloutPress';
    case CnMarkerEvent.DRAG_START: return 'dragStart';
    case CnMarkerEvent.DRAG: return 'drag';
    case CnMarkerEvent.DRAG_END: return 'dragEnd';
    default: return null;
  }
}

// childId 形如 "cn-<tag>"（见 syncChildren 里 addMarker(model, `cn-${child.tag}`)）→ 数字 tag。
function childTagOf(childId: string): number | null {
  const s = childId.startsWith('cn-') ? childId.substring(3) : childId;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

export class CnMapHostController implements CnMapAdapterDelegate {
  private context: common.Context;
  private emit: EmitEventFn;
  private emitOnChild: EmitChildEventFn;
  private getChildren: () => ChildNode[];

  private adapter: CnMapAdapter | null = null;
  private currentProvider: string | null = null;
  private density: number = 1;

  // Child bookkeeping, keyed by Fabric child tag.
  private tracked: Map<number, TrackedChild> = new Map();
  private markerHandlesByIdentifier: Map<string, OverlayHandle> = new Map();

  private prevRegionKey: string = '';
  private prevCameraKey: string = '';
  private didDestroy: boolean = false;
  // Last props seen, replayed once the map controller is ready (config/children set
  // before the async controller attached would otherwise be lost).
  private lastProps: RNMapsMapViewProps | null = null;
  // 诊断用实例标识（排查同一点击被多实例/多链路重复派发）
  private readonly instId: number = Math.floor(Math.random() * 100000);
  // press 去抖状态（见 onMapPress）
  private lastPressAt: number = 0;
  private lastPressKind: CnPressKind = CnPressKind.PAN_DRAG;

  constructor(context: common.Context, emit: EmitEventFn, getChildren: () => ChildNode[],
      emitOnChild: EmitChildEventFn) {
    this.context = context;
    this.emit = emit;
    this.emitOnChild = emitOnChild;
    this.getChildren = getChildren;
    try {
      this.density = display.getDefaultDisplaySync().densityPixels;
    } catch (_e) {
      this.density = 1;
    }
  }

  // Provider / adapter ---------------------------------------------------------

  // 缓存 WrappedBuilder：若每次 getter 都新建 wrapBuilder(...)，build() 重跑时 ArkUI 会因
  // 子树“标识变了”而重建地图 XComponent（表现为滚动/更新时地图重载）。provider 是 mount-fixed，
  // 缓存一份即可让地图子树在多次 build 间保持稳定。首个非空 builder 才落缓存（provider 未就绪时可重试）。
  private cachedMapBuilder: CnMapBuilder | null = null;
  get mapBuilder(): CnMapBuilder | null {
    if (this.cachedMapBuilder === null) {
      const factory = CnMapAdapterRegistry.factoryFor(this.currentProvider);
      this.cachedMapBuilder = factory !== null ? factory.mapBuilder() : null;
    }
    return this.cachedMapBuilder;
  }

  get currentAdapter(): CnMapAdapter | null {
    return this.adapter;
  }

  // Select the adapter for `provider`. Provider is "mount-fixed" (JS remounts on
  // change), so this runs once when props first arrive.
  applyProvider(provider: string | null): void {
    const requested = (provider !== null && provider.length > 0) ? provider : null;
    if (this.adapter !== null && (requested === null || this.currentProvider === requested)) {
      return;
    }
    const created = CnMapAdapterRegistry.createAdapter(this.context, requested);
    this.adapter = created;
    if (created === null) {
      this.currentProvider = null;
      console.error(
        `RNMaps: No map adapter registered for provider=${requested ?? '(default)'}. ` +
        'Register a provider package (e.g. AMapPackage) in your RNPackagesFactory.'
      );
      return;
    }
    this.currentProvider = created.providerName;
    created.delegate = this;
  }

  // Props ----------------------------------------------------------------------

  applyProps(props: RNMapsMapViewProps): void {
    this.lastProps = props;
    if (this.adapter === null) {
      this.applyProvider(props.provider);
    }
    const a = this.adapter;
    if (a === null) {
      return;
    }

    // Appearance / config (idempotent setters; safe to re-apply each update).
    // 关键：本组件是 arkTS 自定义组件，RNOH 不会走生成的 PropsSelector，descriptor.props 只带
    // JS 显式传入的字段——未传的 prop 到这里是 undefined，而非 JS spec（MapViewNativeComponent.ts
    // WithDefault）的默认值。若把 undefined 直接下发给 SDK（如 setScrollGesturesEnabled(undefined)），
    // 会被当成 false，导致未声明 scrollEnabled 的示例地图无法拖动/缩放。这里按 spec 补齐默认值，
    // 与生成的 PropsSelector 保持一致。
    a.setMapType(this.strProp(props.mapType, 'standard'));
    a.setUserInterfaceStyle(this.strProp(props.userInterfaceStyle, 'system'));
    a.setMinZoomLevel(this.numProp(props.minZoomLevel, 3));
    a.setMaxZoomLevel(this.numProp(props.maxZoomLevel, 20));
    a.setZoomEnabled(this.boolProp(props.zoomEnabled, true));
    a.setZoomControlEnabled(this.boolProp(props.zoomControlEnabled, false));
    a.setScrollEnabled(this.boolProp(props.scrollEnabled, true));
    a.setRotateEnabled(this.boolProp(props.rotateEnabled, true));
    a.setPitchEnabled(this.boolProp(props.pitchEnabled, true));
    a.setShowsUserLocation(this.boolProp(props.showsUserLocation, false));
    a.setShowsMyLocationButton(this.boolProp(props.showsMyLocationButton, true));
    a.setShowsCompass(this.boolProp(props.showsCompass, true));
    a.setShowsScale(this.boolProp(props.showsScale, false));
    a.setShowsTraffic(this.boolProp(props.showsTraffic, false));
    a.setShowsBuildings(this.boolProp(props.showsBuildings, true));
    a.setShowsIndoors(this.boolProp(props.showsIndoors, true));
    a.setShowsIndoorLevelPicker(this.boolProp(props.showsIndoorLevelPicker, false));
    a.setShowsPointsOfInterest(this.boolProp(props.showsPointsOfInterest, true));

    // Initial viewport（新 adapter 首次应用）。RNOH re-create 组件后也会走到这里；若用户之前
    // 已通过 camera/region 控制过视口，优先恢复它，避免地图回退到 initialRegion（见文件顶部说明）。
    if (lastControlledCamera !== null) {
      a.setInitialCamera(lastControlledCamera);
    } else if (lastControlledRegion !== null) {
      a.setInitialRegion(lastControlledRegion);
    } else {
      if (props.initialRegion !== undefined) {
        a.setInitialRegion(this.regionFromProp(props.initialRegion));
      }
      if (props.initialCamera !== undefined) {
        a.setInitialCamera(this.cameraFromProp(props.initialCamera));
      }
    }

    // Controlled viewport — only re-apply when it actually changed (so we don't
    // fight user gestures on every descriptor update). 记录到模块级缓存供 re-mount 恢复。
    if (props.region !== undefined) {
      const key = `${props.region.latitude},${props.region.longitude},${props.region.latitudeDelta},${props.region.longitudeDelta}`;
      if (key !== this.prevRegionKey) {
        this.prevRegionKey = key;
        const r = this.regionFromProp(props.region);
        a.setRegion(r);
        lastControlledRegion = r;
        lastControlledCamera = null;
      }
    }
    if (props.camera !== undefined) {
      const c = props.camera;
      const key = `${c.latitude},${c.longitude},${c.heading},${c.pitch},${c.zoom}`;
      if (key !== this.prevCameraKey) {
        this.prevCameraKey = key;
        const cam = this.cameraFromProp(c);
        a.setCamera(cam);
        lastControlledCamera = cam;
        lastControlledRegion = null;
      }
    }

    this.syncChildren();
  }

  // Children -------------------------------------------------------------------

  syncChildren(): void {
    const a = this.adapter;
    if (a === null) {
      return;
    }
    const children = this.getChildren();
    const seen: Set<number> = new Set();

    children.forEach((child) => {
      seen.add(child.tag);
      const existing = this.tracked.get(child.tag);
      const hash = JSON.stringify(child.props);
      // props 未变则跳过（子 descriptor 订阅可能因无关刷新触发 syncChildren）。
      if (existing !== undefined && existing.propsHash === hash) {
        return;
      }
      if (child.componentName === MARKER_COMPONENT_NAME) {
        const model = buildMarkerModel(child.props);
        if (existing === undefined) {
          const handle = a.addMarker(model, `cn-${child.tag}`);
          this.tracked.set(child.tag, { handle, isMarker: true, identifier: model.identifier, propsHash: hash });
          if (model.identifier !== null) {
            this.markerHandlesByIdentifier.set(model.identifier, handle);
          }
        } else {
          a.updateMarker(existing.handle, model);
          existing.identifier = model.identifier;
          existing.propsHash = hash;
          if (model.identifier !== null) {
            this.markerHandlesByIdentifier.set(model.identifier, existing.handle);
          }
        }
        return;
      }
      const overlayModel = buildOverlayModel(child.componentName, child.props);
      if (overlayModel === null) {
        return;
      }
      if (existing === undefined) {
        const handle = a.addOverlay(overlayModel, `cn-${child.tag}`);
        this.tracked.set(child.tag, { handle, isMarker: false, identifier: null, propsHash: hash });
      } else {
        a.updateOverlay(existing.handle, overlayModel);
        existing.propsHash = hash;
      }
    });

    // Remove children that disappeared.
    const toRemove: number[] = [];
    this.tracked.forEach((t, tag) => {
      if (!seen.has(tag)) {
        if (t.isMarker) {
          a.removeMarker(t.handle);
        } else {
          a.removeOverlay(t.handle);
        }
        toRemove.push(tag);
      }
    });
    toRemove.forEach((tag) => this.tracked.delete(tag));
  }

  private markerHandles(): OverlayHandle[] {
    const out: OverlayHandle[] = [];
    this.tracked.forEach((t) => {
      if (t.isMarker) {
        out.push(t.handle);
      }
    });
    return out;
  }

  // Commands -------------------------------------------------------------------

  handleCommand(command: string, args: Object[]): void {
    const a = this.adapter;
    if (a === null) {
      return;
    }
    switch (command) {
      case 'animateToRegion': {
        const r: CnRegion = { latitude: args[0] as number, longitude: args[1] as number, latitudeDelta: args[2] as number, longitudeDelta: args[3] as number };
        a.animateToRegion(r, args[4] as number);
        lastControlledRegion = r;
        lastControlledCamera = null;
        break;
      }
      case 'animateCamera': {
        const cam = this.cameraFrom(args, 0);
        a.applyCamera(cam, true, args[5] as number);
        lastControlledCamera = cam;
        lastControlledRegion = null;
        break;
      }
      case 'setCamera': {
        const cam = this.cameraFrom(args, 0);
        a.applyCamera(cam, false, 0);
        lastControlledCamera = cam;
        lastControlledRegion = null;
        break;
      }
      case 'fitToCoordinates':
        this.fitToCoordinates(args[0] as string, args[1] as string, args[2] as boolean);
        break;
      case 'fitToElements':
        this.fitToElements(args[0] as boolean);
        break;
      case 'fitToSuppliedMarkers':
        this.fitToSuppliedMarkers(args[0] as string, args[1] as string, args[2] as boolean);
        break;
      case 'getCamera':
        this.getCameraResult(args[0] as number);
        break;
      case 'getMapBoundaries':
        this.getMapBoundariesResult(args[0] as number);
        break;
      case 'pointForCoordinate':
        this.pointForCoordinateResult(args[0] as number, args[1] as number, args[2] as number);
        break;
      case 'coordinateForPoint':
        this.coordinateForPointResult(args[0] as number, args[1] as number, args[2] as number);
        break;
      case 'takeSnapshot': {
        const snapReqId = args[0] as number;
        a.takeSnapshot(args[1] as number, args[2] as number, args[3] as string, args[4] as number, args[5] as string,
          (uri) => {
            const data: SnapshotDataP = { uri };
            this.dispatchCommandResult(snapReqId, data);
          });
        break;
      }
      case 'setMapBoundaries':
        a.setMapBoundaries(
          { latitude: args[0] as number, longitude: args[1] as number },
          { latitude: args[2] as number, longitude: args[3] as number }
        );
        break;
      case 'getMarkersFrames':
        this.getMarkersFramesResult(args[0] as number, args[1] as boolean);
        break;
      case 'addressForCoordinate':
        // 查证: present on the Android host; confirm it is in the current JS command list.
        a.addressForCoordinate(args[1] as number, args[2] as number, (addr) =>
          this.dispatchCommandResult(args[0] as number, this.addressPayload(addr)));
        break;
      default:
        break;
    }
  }

  // 子节点（Marker）命令：RN 把 animateMarkerToCoordinate/showCallout/… 发在 Marker 子
  // 组件自己的 tag 上（见 MarkerNativeComponent Commands），host 须为每个子 tag 单独注册
  // 命令回调转发到此。与 onMarkerEvent（子事件）对称——子命令这一向此前完全没接。
  handleChildCommand(childTag: number, command: string, args: Object[]): void {
    const a = this.adapter;
    if (a === null) {
      return;
    }
    const t = this.tracked.get(childTag);
    if (t === undefined || !t.isMarker) {
      return;
    }
    switch (command) {
      case 'animateMarkerToCoordinate':
        a.animateMarker(t.handle, args[0] as number, args[1] as number, args[2] as number);
        break;
      case 'showCallout':
        a.showCallout(t.handle);
        break;
      case 'hideCallout':
        a.hideCallout(t.handle);
        break;
      case 'redrawCallout':
        a.redrawCallout(t.handle);
        break;
      case 'redraw':
        a.redrawCallout(t.handle);
        break;
      default:
        break;
    }
  }

  // Nominal-type bridges: descriptor props (NativeRegionProp/NativeCameraProp) are
  // structurally identical to the adapter models but ArkTS has no structural typing,
  // so rebuild them explicitly as CnRegion/CnCamera at the boundary.
  private regionFromProp(r: NativeRegionProp): CnRegion {
    return {
      latitude: r.latitude, longitude: r.longitude,
      latitudeDelta: r.latitudeDelta, longitudeDelta: r.longitudeDelta,
    };
  }

  private cameraFromProp(c: NativeCameraProp): CnCamera {
    return {
      latitude: c.latitude, longitude: c.longitude, heading: c.heading,
      pitch: c.pitch, zoom: c.zoom, altitude: c.altitude,
    };
  }

  private cameraFrom(args: Object[], base: number): CnCamera {
    return {
      latitude: args[base] as number,
      longitude: args[base + 1] as number,
      heading: args[base + 2] as number,
      pitch: args[base + 3] as number,
      zoom: args[base + 4] as number,
      altitude: 0,
    };
  }

  private fitToCoordinates(coordinatesJSON: string, edgePaddingJSON: string, animated: boolean): void {
    const coords = this.coordinatesFromJSON(coordinatesJSON);
    if (coords.length === 0) {
      return;
    }
    this.adapter?.fitToCoordinates(coords, this.edgeInsets(edgePaddingJSON), animated);
  }

  private fitToElements(animated: boolean): void {
    const handles = this.markerHandles();
    if (handles.length > 0) {
      this.adapter?.fitToMarkers(handles, CN_EDGE_INSETS_ZERO, animated);
    }
  }

  private fitToSuppliedMarkers(markerIDsJSON: string, edgePaddingJSON: string, animated: boolean): void {
    let ids: string[] = [];
    try {
      ids = JSON.parse(markerIDsJSON) as string[];
    } catch (_e) {
      ids = [];
    }
    if (ids.length === 0) {
      return;
    }
    const handles: OverlayHandle[] = [];
    ids.forEach((id) => {
      const h = this.markerHandlesByIdentifier.get(id);
      if (h !== undefined) {
        handles.push(h);
      }
    });
    if (handles.length > 0) {
      this.adapter?.fitToMarkers(handles, this.edgeInsets(edgePaddingJSON), animated);
    }
  }

  private getCameraResult(requestId: number): void {
    const camera = this.adapter?.currentCamera();
    if (camera === undefined) {
      this.dispatchCommandResult(requestId, EMPTY_PAYLOAD);
      return;
    }
    const data: CameraDataP = {
      latitude: camera.latitude, longitude: camera.longitude, heading: camera.heading,
      pitch: camera.pitch, zoom: camera.zoom, altitude: camera.altitude,
    };
    this.dispatchCommandResult(requestId, data);
  }

  private getMapBoundariesResult(requestId: number): void {
    const bounds = this.adapter?.mapBoundaries();
    if (bounds === undefined || bounds === null) {
      this.dispatchCommandResult(requestId, EMPTY_PAYLOAD);
      return;
    }
    const ne = bounds[0];
    const sw = bounds[1];
    const data: BoundariesDataP = {
      northEast: { latitude: ne.latitude, longitude: ne.longitude },
      southWest: { latitude: sw.latitude, longitude: sw.longitude },
    };
    this.dispatchCommandResult(requestId, data);
  }

  private pointForCoordinateResult(requestId: number, latitude: number, longitude: number): void {
    const point = this.adapter?.pointForCoordinate({ latitude, longitude });
    const data: PositionP = { x: (point?.x ?? 0) / this.density, y: (point?.y ?? 0) / this.density };
    this.dispatchCommandResult(requestId, data);
  }

  private coordinateForPointResult(requestId: number, x: number, y: number): void {
    const coordinate = this.adapter?.coordinateForPoint(Math.round(x * this.density), Math.round(y * this.density));
    const data: LatLngP = { latitude: coordinate?.latitude ?? 0, longitude: coordinate?.longitude ?? 0 };
    this.dispatchCommandResult(requestId, data);
  }

  private getMarkersFramesResult(requestId: number, onlyVisible: boolean): void {
    const out: Record<string, Object> = {};
    this.tracked.forEach((t) => {
      if (!t.isMarker || t.identifier === null) {
        return;
      }
      const screen = this.adapter?.markerScreenPoint(t.handle);
      if (screen === undefined || screen === null) {
        return;
      }
      const px = screen.x / this.density;
      const py = screen.y / this.density;
      if (onlyVisible && (screen.x < 0 || screen.y < 0)) {
        return;
      }
      // Keyed by marker identifier (parity with Android getMarkersFrames).
      const frame: MarkerFrameP = {
        point: { x: px, y: py },
        frame: { x: px, y: py, width: 0, height: 0 },
      };
      out[t.identifier] = frame;
    });
    this.dispatchCommandResult(requestId, out);
  }

  private addressPayload(addr: CnAddress | null): AddressDataP {
    return {
      name: addr?.name ?? '', thoroughfare: addr?.thoroughfare ?? '', subThoroughfare: addr?.subThoroughfare ?? '',
      locality: addr?.locality ?? '', subLocality: addr?.subLocality ?? '', administrativeArea: addr?.administrativeArea ?? '',
      subAdministrativeArea: addr?.subAdministrativeArea ?? '', postalCode: addr?.postalCode ?? '',
      countryCode: addr?.countryCode ?? '', country: addr?.country ?? '',
    };
  }

  // Lifecycle ------------------------------------------------------------------

  onResume(): void { if (!this.didDestroy) this.adapter?.onResume(); }
  onPause(): void { if (!this.didDestroy) this.adapter?.onPause(); }
  onSizeChanged(): void { this.adapter?.onSizeChanged(); this.adapter?.didLayout(); }

  destroy(): void {
    if (this.didDestroy) {
      return;
    }
    this.didDestroy = true;
    this.tracked.clear();
    this.markerHandlesByIdentifier.clear();
    this.adapter?.onDestroy();
  }

  // CnMapAdapterDelegate -------------------------------------------------------

  onMapReady(): void {
    // Controller is now attached — replay the latest props so config/children that
    // arrived before the async controller existed are flushed (the provider buffers
    // viewport + markers itself, but scalar config setters were no-ops until now).
    if (this.lastProps !== null) {
      this.applyProps(this.lastProps);
    }
    this.emit(EVT.MAP_READY, EMPTY_PAYLOAD);
    this.emit(EVT.MAP_LOADED, EMPTY_PAYLOAD);
  }

  // 由 host 的 ArkUI TapGesture/LongPressGesture/PanGesture 调用（RNOH 内嵌原生地图不会把
  // 单击/长按/拖动透传给 SDK 的 onMapClick，故在 ArkUI 层并行识别）。入参为组件本地坐标（vp）。
  handleTapAt(xVp: number, yVp: number, kind: CnPressKind): void {
    const a = this.adapter;
    if (a === null) {
      return;
    }
    const px = Math.round(xVp * this.density);
    const py = Math.round(yVp * this.density);
    hilog.info(0x0000, 'cnmaps', 'TAP inst=%{public}d kind=%{public}d x=%{public}d y=%{public}d',
      this.instId, kind as number, px, py);
    const ll = a.coordinateForPoint(px, py);
    if (ll !== null) {
      this.onMapPress(kind, ll, { x: px, y: py });
    }
  }

  onMapPress(kind: CnPressKind, coordinate: CnLatLng, screenPoint: CnPoint | null): void {
    // 同一次物理点击可能经两路到达：ArkUI 并行手势 + 各家 SDK 点击监听（真机证实并存），
    // 且手势层还可能因 build 重跑被叠加注册。统一在此去抖：300ms 内同 kind 视为同一次
    // 点击丢弃（PAN_DRAG 高频连续序列属正常语义，不去抖）。
    if (kind !== CnPressKind.PAN_DRAG) {
      const now = Date.now();
      if (kind === this.lastPressKind && now - this.lastPressAt < 300) {
        return;
      }
      this.lastPressAt = now;
      this.lastPressKind = kind;
    }
    const eventName = kind === CnPressKind.PRESS ? EVT.PRESS
      : kind === CnPressKind.LONG_PRESS ? EVT.LONG_PRESS
      : kind === CnPressKind.DOUBLE_PRESS ? EVT.DOUBLE_PRESS
      : EVT.PAN_DRAG;
    const payload: PressEventP = {
      coordinate: { latitude: coordinate.latitude, longitude: coordinate.longitude },
      position: { x: (screenPoint?.x ?? 0) / this.density, y: (screenPoint?.y ?? 0) / this.density },
    };
    this.emit(eventName, payload);
  }

  onRegionChange(complete: boolean, isGesture: boolean): void {
    const region = this.adapter?.currentRegion();
    if (region === undefined || region === null) {
      return;
    }
    const payload: RegionChangeEventP = {
      region: {
        latitude: region.latitude, longitude: region.longitude,
        latitudeDelta: region.latitudeDelta, longitudeDelta: region.longitudeDelta,
      },
      isGesture,
    };
    this.emit(complete ? EVT.REGION_CHANGE_COMPLETE : EVT.REGION_CHANGE, payload);
  }

  onPoiClick(poi: CnPoi): void {
    const point = this.adapter?.pointForCoordinate({ latitude: poi.latitude, longitude: poi.longitude });
    const payload: PoiClickEventP = {
      coordinate: { latitude: poi.latitude, longitude: poi.longitude },
      position: { x: (point?.x ?? 0) / this.density, y: (point?.y ?? 0) / this.density },
    };
    if (poi.placeId !== null) {
      payload.placeId = poi.placeId;
    }
    if (poi.name !== null) {
      payload.name = poi.name;
    }
    this.emit(EVT.POI_CLICK, payload);
  }

  onUserLocationChange(location: CnUserLocation): void {
    const payload: UserLocationChangeEventP = {
      coordinate: {
        latitude: location.latitude, longitude: location.longitude, altitude: location.altitude,
        accuracy: location.accuracy, speed: location.speed, heading: location.heading,
        isFromMockProvider: location.isFromMockProvider,
      },
    };
    this.emit(EVT.USER_LOCATION_CHANGE, payload);
  }

  onMarkerEvent(childId: string, event: CnMarkerEvent, coordinate: CnLatLng): void {
    // Marker 事件在 react-native-maps 里发在 Marker 子节点上（onPress/onCalloutPress…）。
    // 直接对子节点自己的 tag 用 Marker 的 codegen 规范事件名（press/select/…，见
    // generated/components/RNMapsMarker.ts）emitComponentEvent，而非发 host 级事件——MapView
    // codegen 里没有 marker 事件名，发在 host 上会被 RNOH 丢弃。childId 形如 "cn-<tag>"。
    const name = markerChildEventName(event);
    if (name === null) {
      return;
    }
    const childTag = childTagOf(childId);
    if (childTag === null) {
      return;
    }
    const payload: MarkerChildEventP = {
      coordinate: { latitude: coordinate.latitude, longitude: coordinate.longitude },
    };
    this.emitOnChild(childTag, name, payload);
  }

  onOverlayPress(childId: string): void {
    // Overlay（Polyline/Polygon/Circle）的 onPress 同 Marker：发在覆盖物子节点自己的 tag 上，
    // codegen 事件名 'press'、payload 为空（见 generated/components/RNMapsPolyline.ts）。发 host
    // 级事件（MapView 无此名）会被 RNOH 丢弃。
    const childTag = childTagOf(childId);
    if (childTag === null) {
      return;
    }
    this.emitOnChild(childTag, 'press', EMPTY_PAYLOAD);
  }

  infoWindowContentFor(childId: string): string | null {
    // MVP: default info window uses the marker title/snippet handled by the adapter.
    // Custom ArkUI callout content is a Phase 4 spike item.
    return null;
  }

  // Helpers --------------------------------------------------------------------

  // Prop 默认值补齐：descriptor.props 未带的字段是 undefined（arkTS 自定义组件不经 PropsSelector），
  // 按 JS spec 默认值兜底后再下发，避免 undefined 被 SDK 当成 false（见 applyProps 说明）。
  private boolProp(value: boolean | undefined, def: boolean): boolean {
    return value === undefined ? def : value;
  }

  private numProp(value: number | undefined, def: number): number {
    return value === undefined || Number.isNaN(value) ? def : value;
  }

  private strProp(value: string | undefined, def: string): string {
    return value === undefined || value.length === 0 ? def : value;
  }

  private dispatchCommandResult(requestId: number, data: Object): void {
    const payload: CommandResultEventP = { id: requestId, data: JSON.stringify(data) };
    this.emit(EVT.COMMAND_RESULT, payload);
  }

  private edgeInsets(json: string): CnEdgeInsets {
    let o: PropBag = {};
    try {
      o = JSON.parse(json) as PropBag;
    } catch (_e) {
      o = {};
    }
    const edge = (name: string): number => Math.round(((o[name] as number | undefined) ?? 0) * this.density);
    return { top: edge('top'), right: edge('right'), bottom: edge('bottom'), left: edge('left') };
  }

  private coordinatesFromJSON(json: string): CnLatLng[] {
    try {
      const arr = JSON.parse(json) as PropBag[];
      return arr.map((o): CnLatLng => ({ latitude: o['latitude'] as number, longitude: o['longitude'] as number }));
    } catch (_e) {
      return [];
    }
  }
}

// Event-name constants. 查证: align these with the codegen-generated event emitter
// names for RNMapsMapView (the JS spec registers onPress as Bubbling `topPress`,
// the rest as Direct). One place to reconcile during P1.
class Events {
  // RNOH emitComponentEvent 用的是 codegen 规范事件名（无 "on" 前缀、首字母小写，见
  // generated/components/RNMapsMapView.ts 的 EventPayloadByName）。此前误用 "onPress" 等
  // 带前缀名，RNOH 无法路由，导致所有地图事件（CB-1）不达 JS。
  readonly MAP_READY = 'mapReady';
  readonly MAP_LOADED = 'mapLoaded';
  readonly REGION_CHANGE = 'regionChange';
  readonly REGION_CHANGE_COMPLETE = 'regionChangeComplete';
  readonly PRESS = 'press';
  readonly LONG_PRESS = 'longPress';
  readonly DOUBLE_PRESS = 'doublePress';
  readonly PAN_DRAG = 'panDrag';
  readonly POI_CLICK = 'poiClick';
  readonly USER_LOCATION_CHANGE = 'userLocationChange';
  readonly COMMAND_RESULT = 'commandResult';
  // Marker/overlay child events (host-level fan-out carrying childId).
  readonly MARKER_PRESS = 'onMarkerPress';
  readonly MARKER_SELECT = 'onMarkerSelect';
  readonly MARKER_DESELECT = 'onMarkerDeselect';
  readonly CALLOUT_PRESS = 'onCalloutPress';
  readonly MARKER_DRAG_START = 'onMarkerDragStart';
  readonly MARKER_DRAG = 'onMarkerDrag';
  readonly MARKER_DRAG_END = 'onMarkerDragEnd';
  readonly OVERLAY_PRESS = 'onOverlayPress';
}

const EVT = new Events();
