/*
 * Builds provider-agnostic models from a child Fabric node's component name + raw
 * props. Mirrors the "dumb child" work done on Android by MarkerView.markerModel()
 * / the *View.overlayModel() implementations — but here the host reads each child's
 * descriptor props directly (the "host reads subtree" option from the plan, 02 §5)
 * rather than each child being a stateful native view.
 *
 * 查证: the exact native prop KEYS below must match each child's codegen spec
 * (`src/MarkerNativeComponent.ts`, `PolylineNativeComponent.ts`, ...). codegen may
 * flatten nested objects (e.g. coordinate → latitude/longitude) the same way the
 * MapView spec flattens region; align these readers during P1/P4 against the
 * generated props types. Reads are defensive (missing key → sensible default).
 */
import {
  CnCircleModel, CnGroundOverlayModel, CnHeatmapModel, CnHeatmapWeightedPoint, CnLatLng,
  CnLocalTileModel, CnMarkerModel, CnOverlayModel, CnPolygonModel, CnPolylineModel, CnUrlTileModel
} from '../adapter/CnMapModels';

// Loosely-typed prop bag as delivered by the descriptor registry.
export type PropBag = Record<string, Object>;

function num(props: PropBag, key: string, fallback: number): number {
  const v = props[key];
  return typeof v === 'number' ? v as number : fallback;
}

function str(props: PropBag, key: string): string | null {
  const v = props[key];
  return typeof v === 'string' ? v as string : null;
}

function bool(props: PropBag, key: string, fallback: boolean): boolean {
  const v = props[key];
  return typeof v === 'boolean' ? v as boolean : fallback;
}

function coord(props: PropBag): CnLatLng {
  // Supports either a nested `coordinate` object or flattened lat/lng.
  const c = props['coordinate'] as PropBag | undefined;
  if (c !== undefined) {
    return { latitude: num(c, 'latitude', 0), longitude: num(c, 'longitude', 0) };
  }
  return { latitude: num(props, 'latitude', 0), longitude: num(props, 'longitude', 0) };
}

function coordList(props: PropBag, key: string): CnLatLng[] {
  const arr = props[key];
  // RNOH 可能把未设置的数组 prop 传成非数组（如 {}）——`=== undefined` 挡不住，
  // 用 Array.isArray 兜底，否则 `.map` 会 "undefined is not callable"。
  if (!Array.isArray(arr)) {
    return [];
  }
  return (arr as Object[]).map((o): CnLatLng => {
    const p = o as PropBag;
    return { latitude: num(p, 'latitude', 0), longitude: num(p, 'longitude', 0) };
  });
}

function colorOr(props: PropBag, key: string, fallback: number): number {
  const v = props[key];
  return typeof v === 'number' ? v as number : fallback;
}

export function buildMarkerModel(props: PropBag): CnMarkerModel {
  const c = coord(props);
  const anchor = props['anchor'] as PropBag | undefined;
  return {
    identifier: str(props, 'identifier'),
    latitude: c.latitude,
    longitude: c.longitude,
    title: str(props, 'title'),
    snippet: str(props, 'description') ?? str(props, 'snippet'),
    pinColor: str(props, 'pinColor'),
    draggable: bool(props, 'draggable', false),
    anchorU: anchor !== undefined ? num(anchor, 'x', 0.5) : 0.5,
    anchorV: anchor !== undefined ? num(anchor, 'y', 1.0) : 1.0,
    opacity: num(props, 'opacity', 1.0),
    rotation: num(props, 'rotation', 0),
    flat: bool(props, 'flat', false),
    zIndex: num(props, 'zIndex', 0),
    // 查证: custom-children rasterization + `image` decode to PixelMap is a Phase 4
    // spike item (ArkUI component snapshot / image loader). Null for the MVP.
    customBitmap: null,
    iconBitmap: null,
    hasInfoWindowContent: (str(props, 'title') ?? '').length > 0,
  };
}

function buildPolyline(props: PropBag): CnPolylineModel {
  const strokeColors = (props['strokeColors'] as number[] | undefined) ?? [];
  return {
    kind: 'polyline',
    coordinates: coordList(props, 'coordinates'),
    strokeColor: colorOr(props, 'strokeColor', 0xff000000),
    strokeColors: strokeColors,
    strokeWidth: num(props, 'strokeWidth', 1),
    zIndex: num(props, 'zIndex', 0),
    geodesic: bool(props, 'geodesic', false),
    // RNM passes lineDashPattern; non-empty ⇒ dashed.
    dashed: ((props['lineDashPattern'] as number[] | undefined) ?? []).length > 0,
    lineCap: str(props, 'lineCap'),
    lineJoin: str(props, 'lineJoin'),
    tappable: bool(props, 'tappable', false),
  };
}

function buildPolygon(props: PropBag): CnPolygonModel {
  // holes 是嵌套数组（Array<Array<LatLng>>）；RNOH 对未设置的嵌套数组 prop 可能传成
  // 非数组值，故用 Array.isArray 逐层兜底，避免 `.map` 崩溃（undefined is not callable）。
  const holesRaw = props['holes'];
  const holes: CnLatLng[][] = Array.isArray(holesRaw)
    ? (holesRaw as Object[]).map((ring): CnLatLng[] => {
        const r = Array.isArray(ring) ? (ring as Object[]) : [];
        return r.map((o): CnLatLng => {
          const p = o as PropBag;
          return { latitude: num(p, 'latitude', 0), longitude: num(p, 'longitude', 0) };
        });
      })
    : [];
  return {
    kind: 'polygon',
    coordinates: coordList(props, 'coordinates'),
    holes: holes,
    strokeColor: colorOr(props, 'strokeColor', 0xff000000),
    fillColor: colorOr(props, 'fillColor', 0x00000000),
    strokeWidth: num(props, 'strokeWidth', 1),
    zIndex: num(props, 'zIndex', 0),
  };
}

function buildCircle(props: PropBag): CnCircleModel {
  return {
    kind: 'circle',
    center: coord(props),
    radius: num(props, 'radius', 0),
    strokeColor: colorOr(props, 'strokeColor', 0xff000000),
    fillColor: colorOr(props, 'fillColor', 0x00000000),
    strokeWidth: num(props, 'strokeWidth', 1),
    zIndex: num(props, 'zIndex', 0),
  };
}

function buildHeatmap(props: PropBag): CnHeatmapModel {
  // `points` / `gradient` cross as JSON strings (parsed natively, per the JS spec).
  let points: CnHeatmapWeightedPoint[] = [];
  try {
    const raw = JSON.parse(str(props, 'points') ?? '[]') as PropBag[];
    points = raw.map((o): CnHeatmapWeightedPoint => ({
      latitude: num(o, 'latitude', 0), longitude: num(o, 'longitude', 0), weight: num(o, 'weight', 1),
    }));
  } catch (_e) {
    points = [];
  }
  // gradient: { colors:number[], startPoints:number[] }. 查证 the exact JS facade
  // shape (colors may arrive as ints or hex strings).
  let colors: number[] | null = null;
  let startPoints: number[] | null = null;
  try {
    const g = JSON.parse(str(props, 'gradient') ?? 'null') as PropBag | null;
    if (g !== null) {
      const c = g['colors'] as number[] | undefined;
      const s = g['startPoints'] as number[] | undefined;
      if (c !== undefined && typeof c[0] === 'number') {
        colors = c;
      }
      if (s !== undefined) {
        startPoints = s;
      }
    }
  } catch (_e) {
  }
  return {
    kind: 'heatmap',
    points,
    radius: num(props, 'radius', 20),
    gradientColors: colors,
    gradientStartPoints: startPoints,
  };
}

function buildUrlTile(props: PropBag): CnUrlTileModel {
  return {
    kind: 'urlTile',
    urlTemplate: str(props, 'urlTemplate'),
    minimumZ: num(props, 'minimumZ', 0),
    maximumZ: num(props, 'maximumZ', 25),
    tileSize: num(props, 'tileSize', 256),
    flipY: bool(props, 'flipY', false),
    wms: bool(props, 'wms', false),
    zIndex: num(props, 'overlayZIndex', 0),
    diskCacheDir: str(props, 'tileCachePath'),
  };
}

function buildLocalTile(props: PropBag): CnLocalTileModel {
  return {
    kind: 'localTile',
    pathTemplate: str(props, 'pathTemplate'),
    tileSize: num(props, 'tileSize', 256),
    useAssets: bool(props, 'useAssets', false),
    zIndex: num(props, 'overlayZIndex', 0),
  };
}

function buildGroundOverlay(props: PropBag): CnGroundOverlayModel {
  return {
    kind: 'groundOverlay',
    southWest: { latitude: num(props, 'swLatitude', 0), longitude: num(props, 'swLongitude', 0) },
    northEast: { latitude: num(props, 'neLatitude', 0), longitude: num(props, 'neLongitude', 0) },
    // 查证 Phase 4: decode the `image` URI → PixelMap (async, via an image loader,
    // like marker icons). Null until wired ⇒ the ground overlay is skipped by the adapter.
    bitmap: null,
    bearing: num(props, 'bearing', 0),
    opacity: num(props, 'opacity', 1),
    zIndex: num(props, 'overlayZIndex', 0),
  };
}

// Maps a child component type → overlay model. Markers are handled separately
// (they are not overlays). Returns null for unsupported children.
export function buildOverlayModel(componentName: string, props: PropBag): CnOverlayModel | null {
  switch (componentName) {
    case 'RNMapsPolyline':
      return buildPolyline(props);
    case 'RNMapsPolygon':
      return buildPolygon(props);
    case 'RNMapsCircle':
      return buildCircle(props);
    case 'RNMapsHeatmap':
      return buildHeatmap(props);
    case 'RNMapsUrlTile':
      return buildUrlTile(props);
    case 'RNMapsLocalTile':
      return buildLocalTile(props);
    case 'RNMapsOverlay':
      return buildGroundOverlay(props);
    default:
      return null;
  }
}

export const MARKER_COMPONENT_NAME: string = 'RNMapsMarker';
