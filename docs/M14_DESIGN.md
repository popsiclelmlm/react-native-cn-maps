# M14 设计:Geojson(纯 JS 渲染)

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M14(P1)。**无新增原生代码**——把 GeoJSON 解析成已有的 `<Marker>`/`<Polyline>`/`<Polygon>` 子组件渲染。成本最低,作为热身。

## 架构

`<Geojson geojson={FeatureCollection} ... />` 在 JS 层:

1. **解析**:把 GeoJSON(FeatureCollection / Feature / Geometry / GeometryCollection)摊平成一组中性形状 `GeoShape`(point / line / polygon),坐标从 GeoJSON 的 `[经度, 纬度]` 顺序转成库内的 `{ latitude, longitude }`。
2. **渲染**:每个形状映射成对应子组件:
   - point / multipoint → `<Marker>`
   - linestring / multilinestring → `<Polyline>`
   - polygon / multipolygon → `<Polygon>`(第一个 ring 是外环,其余是内孔 `holes`)
3. **坐标系**:**不在 Geojson 层做 GCJ-02 转换**——交给子组件按 `<MapView coordinateSystem>` context 统一处理(全局「子组件转坐标」原则)。GeoJSON 规范是 WGS-84,使用方应设 `coordinateSystem="wgs84"`(文档说明)。

> 解析器 `flattenGeojson(geojson): GeoShape[]` 是**纯函数**,健壮处理畸形输入(返回 `[]`),单独成 `src/geojson.ts` 便于单测。

## Props 映射(对标 RNM)

| GeojsonProp | 作用对象 |
|---|---|
| `strokeColor` / `strokeWidth` / `lineDashPattern` | Polyline + Polygon 描边 |
| `fillColor` | Polygon 填充 |
| `zIndex` | 全部 |
| `tappable` + `onPress` | Polyline / Polygon / Marker(转发 MapPressEvent) |
| `markerComponent` | Point → `<Marker>` 的自定义内容(children) |
| `image` / `pinColor` / `title` | Point → Marker 外观 |

## 本期范围与 best-effort

- **支持的几何**:Point / MultiPoint / LineString / MultiLineString / Polygon / MultiPolygon / GeometryCollection / Feature / FeatureCollection。
- **best-effort / 文档化**:`onPress` 转发的是子组件的 `MapPressEvent`,**不附带被点的 GeoJSON feature**(RNM 会带 feature;本期从简)。`lineDashPhase` 接受但忽略。

## 三层落点

- **JS**:新增 `src/geojson.ts`(`flattenGeojson` 纯函数 + 类型);`MapGeojson.tsx` 从 stub 改为解析 + 渲染子组件(保留 `__MAP_GEOJSON` sentinel)。**无 Android/iOS 改动**。
- **example**:新增 "Geojson (M14)" 开关,喂一个含点/线/面的 FeatureCollection。
- **测试**:`flattenGeojson` 的单测(各几何类型 → 形状数量/类型/坐标顺序;畸形输入 → `[]`)+ sentinel。

## 验收(同步回 RNM_PARITY_PLAN.md M14)

- [ ] `flattenGeojson` 覆盖各几何类型 + 畸形输入
- [ ] Point / LineString / Polygon(含内孔)/ Multi* 渲染
- [ ] 样式 props 生效
- [ ] example 演示页 + 单测
- [ ] Android 真机验证(复用已验证的 Marker/Polyline/Polygon,风险低)
