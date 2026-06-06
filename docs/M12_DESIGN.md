# M12 设计:Overlay(图片覆盖物)

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M12(P0)。复用 M5/M11 的「子 host component 挂在 MapView 下、父地图拦截挂载」地基,把覆盖物换成**按地理 bounds 贴图的 ground overlay**。

## 架构

新增一个 codegen 子 host component `RNMapsOverlay`,挂在 `<MapView>` 下:

- **Android**:`OverlayView` 持有 `GroundOverlay` 句柄;`attachTo(aMap)` → `aMap.addGroundOverlay(GroundOverlayOptions)`;`detach()` → `groundOverlay.remove()`。`MapView.addFeature/removeFeatureAt/destroy` 增加识别。
- **iOS**:`RNMapsOverlay` 实现既有 `RNMapsOverlayView` 协议(`overlay` = `MAGroundOverlay`,`overlayRenderer` = `MAGroundOverlayRenderer`);父地图挂载/`rendererForOverlay:` 无需改。

> 图片是异步加载的。GroundOverlay 创建必须带图,所以**图未就绪不创建**,图到位后再 attach / rebuild(与 Marker 的 image 加载一致)。

## Props(对标 RNM)

| RNM prop | 处理 | Android | iOS |
|---|---|---|---|
| `image`(require/uri) | JS `Image.resolveAssetSource` → uri 字符串,native 异步加载(http/file/drawable) | ✅ | ✅ |
| `bounds: [LatLng, LatLng]` | JS 按 `coordinateSystem` 转 gcj02,算出 SW/NE,拍平成 4 个 double 传 native | ✅ | ✅ |
| `bearing` | 旋转角(度) | ✅(`.bearing`) | ⚠️ 待确认 |
| `opacity` | 透明度 | ✅(AMap 用 `transparency = 1 - opacity`) | ✅(renderer.alpha) |
| `zIndex` | 图层顺序 → `overlayZIndex` | ✅ | ⚠️ 按 add 顺序 |
| `tappable` / `onPress` | 接 prop | ❌ ground overlay 无原生点击 | ❌ |

### bounds 归一化(JS 层)
RNM 的 `bounds` 是两个角点,顺序不固定。JS facade 把两个角点各自转坐标后,取 `min/max` 得到 SW(`minLat,minLng`)和 NE(`maxLat,maxLng`),传 `swLatitude/swLongitude/neLatitude/neLongitude` 四个标量,native 端 `LatLngBounds(sw, ne)` / `MACoordinateBounds`。

## native 实现要点

- **Android**:
  - 图片加载复用 Marker 的套路(后台线程 decode http/file/drawable → Bitmap → `post` 回主线程)。
  - `GroundOverlayOptions().positionFromBounds(LatLngBounds(sw, ne)).image(BitmapDescriptorFactory.fromBitmap(bmp)).bearing(b).transparency(1-opacity).zIndex(z)`。
  - 图/bounds 变化重建 overlay;bearing/transparency/zIndex 可在句柄上原地改。
- **iOS**:
  - 异步加载 `UIImage`(asset/http/file),到位后 `MAGroundOverlay groundOverlayWithBounds:icon:` 创建并 `addOverlay:`。
  - `overlayRenderer` 返回 `MAGroundOverlayRenderer`(设 `alpha = opacity`)。

## 三层落点

- **JS**:新增 `OverlayNativeComponent.ts`;`MapOverlay.tsx` 从 stub 改为渲染 NativeComponent(保留 `__MAP_OVERLAY` sentinel + `Overlay.Animated`);坐标/bounds 转换在 facade。
- **iOS**:`RNMapsOverlay.{h,mm}`(实现 `RNMapsOverlayView`);父地图无需改。
- **Android**:`OverlayView.kt` + `OverlayManager.kt`;`MapsPackage` 注册;`MapView` 的 feature 识别加 `OverlayView`。
- **example**:新增 "Overlay (M12)" 开关,用一张图按 bounds 贴到地图上(对标 RNM `ImageOverlayWith*`)。
- **测试**:JS 单测断言 `<Overlay>` sentinel + `Overlay.Animated` 仍在;bounds→SW/NE 归一化的纯函数单测。

## 本期范围与 best-effort

- **核心保证**:本地/网络图片按 bounds 贴图 + bearing + opacity + zIndex,Android 双端(iOS 待真机验证)。
- **不支持(文档化)**:`tappable`/`onPress`(ground overlay 无原生点击)。

## 验收(同步回 RNM_PARITY_PLAN.md M12)

- [ ] 三层落地 + codegen/typecheck/lint/jest 通过
- [ ] 本地图片 + URL 图片两种来源
- [ ] `bearing` 旋转
- [ ] Android 真机验证 / iOS 真机验证
- [ ] 单测(sentinel + bounds 归一化)
