# 真机/模拟器验证清单

> ✅ **Android 真机验证全部通过(2026-06-06)** —— 全功能在真机逐项确认。过程中修复 V1(离屏 marker/overlay `post` 不执行)、V2(热力图需 Jetifier)两个真机专属 bug。
>
> ✅ **iOS 首次编译 + 模拟器/真机全功能验证通过(2026-06-06)** —— 全功能在 iOS 逐项确认。bring-up 过程修复一串 iOS 库级 bug(onPress 事件 bubbling、空 oldProps 解引用、4 个组件未注册、initialRegion 时机、AMap arm64-sim 切片缺失、AMap API 误用、iOS 隐私、真机打包 Node ESM)——详见 `CODE_REVIEW_FINDINGS.md` 的「iOS bring-up findings」。

> 对照 example app 的控制面板逐项验证。每项标注:**操作** → **预期**。勾选通过项;不通过的记下现象。
>
> 说明:example 的 `<MapView coordinateSystem="gcj02">`。Geojson / Overlay / Heatmap 的 demo 坐标按 gcj02 处理(WGS-84 源数据会有偏移,但仍应渲染在上海附近——本清单只验证"能否渲染")。

## 0. 预检(环境 / 前置)

- [ ] Android:`~/.gradle/gradle.properties` 含 `AMAP_ANDROID_API_KEY=...`;iOS:`example/ios/CnMapsExample/Info.plist` 的 `AMapApiKey` 已填(否则地图鉴权失败、空白)
- [ ] Android:JDK 17 + `adb reverse tcp:8081 tcp:8081`(真机);iOS:模拟器(Apple Silicon)需 Podfile post_install `EXCLUDED_ARCHS[sim]=arm64`,真机 Debug 需 `.xcode.env.local` 指向 Node ≥ 22.12
- [ ] 终端A:`yarn example start`;终端B:`yarn example android` 或 `yarn example ios`
- [ ] App 启动**不崩**、不白屏(隐私合规已在 `App.tsx` 启动时 `setPrivacyConsent`)

## 1. 基线 — MapView / 相机 / 区域

- [ ] 地图正常显示(高德底图,初始视野在上海)
- [ ] **mapType** chips:standard / satellite / hybrid 切换有效
- [ ] **userInterfaceStyle: dark** 开关:夜间样式
- [ ] "Fly to Beijing (camera)" → 飞到北京(camera 受控)
- [ ] "Back to Shanghai (animate)" → animateToRegion 回上海
- [ ] 各显示/手势开关:showsTraffic / showsCompass / showsScale / zoomEnabled / scrollEnabled / rotateEnabled / pitchEnabled 等行为符合
- [ ] 底部日志条:onMapReady / onMapLoaded / onPress / onPanDrag / region 文本在更新

## 2. Marker / Callout

- [ ] 默认 pin、彩色 pin、image marker、自定义 React 视图 marker、可拖拽 marker 都显示
- [ ] 点 marker:`onPress`/`onSelect` 日志
- [ ] 拖拽 marker:onDragStart/onDrag/onDragEnd 日志
- [ ] Callout 气泡显示;"Show callout (custom)" 按钮弹出自定义 callout
- [ ] "Bump custom label" → 自定义 marker 内容变化(tracksViewChanges 重绘)
- [ ] "Redraw custom" / "Animate draggable" 命令有效

## 3. 矢量覆盖物

- [ ] Polyline(红线)显示;`tappable` 时点击有 `polyline onPress` 日志
- [ ] Polygon(蓝色围栏 + 填充)显示
- [ ] Circle(绿色范围圈)显示

## 4. UrlTile / LocalTile

- [ ] 打开 **"UrlTile"** → 栅格瓦片叠加显示
- [ ] 关闭开关 → 瓦片消失
- [ ] (LocalTile 无 demo 开关;如需,可临时加 `<LocalTile pathTemplate=...>` 指向本地瓦片)

## 5. Overlay(图片覆盖物)

- [ ] 打开 **"Overlay"** → 图片按 bounds 贴在上海区域
- [ ] 关闭 → 图片消失
- [ ] (可选)改 `bearing` 看旋转

## 6. takeSnapshot

- [ ] 点 **"takeSnapshot"** 按钮 → 面板下方出现地图截图缩略图(`<Image>` 预览)
- [ ] 日志 `takeSnapshot → ok`;不为 empty/error

## 7. Geojson

- [ ] 打开 **"Geojson"** → 出现 1 个点 marker + 1 条线 + 1 个面
- [ ] 关闭 → 全部消失

## 8. 命令补全

- [ ] 点 **"setMapBoundaries"** → 地图可平移范围被限制在上海框内(拖到边界会被挡回)
- [ ] 点 **"getMarkersFrames"** → 日志输出各 marker 的 identifier(bund, square, default, image, custom, draggable)

## 9. Polyline 渐变 + 线型

- [ ] 打开 **"Polyline: gradient"** → 红线变成 红→绿→蓝 渐变;线端/拐角为圆角(lineCap/lineJoin round)
- [ ] 关闭 → 回到单色红线

## 10. Heatmap

- [ ] 打开 **"Heatmap: weighted points"** → 上海区域出现热力图色块(权重不同浓淡不同)
- [ ] 关闭 → 消失

## 11. WMSTile

- [ ] 打开 **"WMSTile: OSM-WMS"** → WMS 图层叠加(terrestris OSM-WMS,需网络;不通则换 WMS 源)
- [ ] 关闭 → 消失

## 12. 稳定性

- [ ] 反复开关上述图层 10+ 次不崩、不泄漏(观察是否卡顿)
- [ ] 切到后台再回前台地图正常(onHostPause/Resume)
- [ ] 横竖屏切换地图正常

---

## 平台环境要点(host app 必读)

**Android**
- `~/.gradle/gradle.properties` 配 `AMAP_ANDROID_API_KEY`(或在 host AndroidManifest meta-data 设)
- 使用 `<Heatmap>` 时,host `android/gradle.properties` 加 `android.enableJetifier=true`(AMap 热力图依赖旧 Support 库)

**iOS**
- `Info.plist` 的 `AMapApiKey` 填高德 iOS key(注意 iOS key 与 Android key 不通用)
- 模拟器(Apple Silicon):Podfile `post_install` 给所有 pod 加 `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64`(AMap framework 无 arm64-模拟器切片;真机 arm64 不受影响)
- 真机 Debug 打包:`ios/.xcode.env.local` 把 `NODE_BINARY` 指向 Node ≥ 22.12

## 发现的问题(记录区)

| 项 | 平台 | 现象 | 状态 |
|---|---|---|---|
| | | | |
