# M5 设计:Polyline / Polygon / Circle 覆盖物

> 对应 ROADMAP「M5 — 覆盖物」。复用 M3 的「子 host component 挂在 MapView 下、父地图拦截挂载」地基,只是子视图从 annotation 换成 overlay。

## 架构

新增三个 codegen 子 host component:`RNMapsPolyline` / `RNMapsPolygon` / `RNMapsCircle`,都挂在 `<MapView>` 下。父地图的挂载拦截(iOS `mountChildComponentView` / Android `ViewGroupManager.addView` → feature 列表)在 M3 已经能识别 marker,这里**扩展为也识别 overlay 视图**。

- **iOS**:每个 overlay 视图持有对应的 `MAPolyline`/`MAPolygon`/`MACircle` + 样式;`addToMap` = `[map addOverlay:]`。父地图实现 `mapView:rendererForOverlay:`,通过 `overlay → overlayView` 映射拿到样式,构造 `MAPolylineRenderer`/`MAPolygonRenderer`/`MACircleRenderer`(strokeColor/lineWidth/fillColor/lineDash)。坐标变化需重建 overlay(remove+add)。
- **Android**:每个 overlay 视图持有 `Polyline`/`Polygon`/`Circle` 句柄;`addToMap` 调 `aMap.addPolyline/Polygon/Circle(options)`,样式直接落在 options/对象上。

## Props(JS 层统一按 `<MapView coordinateSystem>` 把坐标转 gcj02)

- 公共:`strokeColor`、`strokeWidth`、`zIndex`、`tappable` + `onPress`、`lineDashPattern`(JSON 字符串传递,避开 codegen 数字数组限制)。
- Polyline:`coordinates`、`geodesic`。
- Polygon:`coordinates`、`fillColor`、`holes`(JSON 字符串,内孔)。
- Circle:`center`(拍平 latitude/longitude)、`radius`、`fillColor`。
- `coordinates` 用 codegen「对象数组」(M2 markers 已验证可行);`holes`/`lineDashPattern` 用 JSON 字符串。

## 事件 / 点击(best-effort)

- Android:`aMap.setOnPolylineClickListener` 原生支持 polyline 点击 → 路由到对应 view 的 `onPress`;Polygon/Circle 无原生点击回调,本期文档化为不支持。
- iOS:MAMapKit 无 overlay 原生点击;本期 `tappable`/`onPress` 接住 prop 但不做命中测试(文档化)。
- 渐变 polyline(`strokeColors`)本期接 prop 不实现。

## 三层落点

- JS:`{Polyline,Polygon,Circle}NativeComponent.ts` + 重写 `MapPolyline/MapPolygon/MapCircle.tsx`(context 转坐标)。
- iOS:`RNMaps{Polyline,Polygon,Circle}.{h,mm}` + `RNMapsMapView` 挂载拦截 & `rendererForOverlay:`。
- Android:`{Polyline,Polygon,Circle}View.kt` + manager + `MapsPackage` 注册 + `MapView.addFeature` 识别。
