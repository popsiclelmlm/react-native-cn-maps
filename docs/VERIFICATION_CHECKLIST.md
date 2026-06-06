# 真机/模拟器验证清单(M1–M18)

> ✅ **Android 真机验证全部通过(2026-06-06)** —— M1–M18(除暂缓 M8/M9/M19)在真机逐项确认。过程中修复 V1(离屏 marker/overlay `post` 不执行)、V2(热力图需 Jetifier)两个真机专属 bug。
>
> ✅ **iOS 首次编译 + 模拟器/真机全功能验证通过(2026-06-06)** —— M1–M18 在 iOS 逐项确认。bring-up 过程修复一串 iOS 库级 bug(onPress 事件 bubbling、空 oldProps 解引用、4 个组件未注册、initialRegion 时机、AMap arm64-sim 切片缺失、AMap API 误用、iOS 隐私、真机打包 Node ESM)——详见 `CODE_REVIEW_FINDINGS.md` 的「iOS bring-up findings」。

> 对照 example app 的控制面板逐项验证。每项标注:**操作** → **预期**。勾选通过项;不通过的记下现象。
>
> 说明:example 的 `<MapView coordinateSystem="gcj02">`。M14 Geojson / M12 Overlay / M17 Heatmap 的 demo 坐标按 gcj02 处理(WGS-84 源数据会有偏移,但仍应渲染在上海附近——本清单只验证"能否渲染")。

## 0. 预检(环境 / 前置)

- [ ] `~/.gradle/gradle.properties` 含 `AMAP_ANDROID_API_KEY=...`(否则地图鉴权失败,空白)
- [ ] JDK 17:`export JAVA_HOME="/Users/liumin/Library/Java/JavaVirtualMachines/corretto-17.0.16/Contents/Home"`
- [ ] `adb devices` 能看到设备;真机需 `adb reverse tcp:8081 tcp:8081`
- [ ] 终端A:`yarn example start`;终端B:`yarn example android`
- [ ] App 启动**不崩**、不白屏(隐私合规已在 `App.tsx` 启动时 `setPrivacyConsent`)
- [ ] 抓崩溃/JS 错误:`adb -s <设备> logcat -d | grep -iE "FATAL|ReactNativeJS|Exception"`

## 1. 基线(M1–M6,回归)

- [ ] 地图正常显示(高德底图,上海)
- [ ] **mapType** chips:standard / satellite / hybrid 切换有效
- [ ] **userInterfaceStyle: dark** 开关:夜间样式
- [ ] "Fly to Beijing (camera)" → 飞到北京(camera 受控)
- [ ] "Back to Shanghai (animate)" → animateToRegion 回上海
- [ ] "Display & gesture toggles" 各开关:showsTraffic / showsCompass / zoomEnabled / scrollEnabled / rotateEnabled / pitchEnabled 等行为符合
- [ ] 底部日志条:onMapReady / onMapLoaded / onPress / onPanDrag / region 文本在更新

## 2. Marker / Callout(M3 / M4,回归)

- [ ] 默认 pin、彩色 pin、image marker、自定义 React 视图 marker、可拖拽 marker 都显示
- [ ] 点 marker:`onPress`/`onSelect` 日志(**重点**:onSelect 之前修过事件冲突,确认不崩)
- [ ] 拖拽 marker:onDragStart/onDrag/onDragEnd 日志
- [ ] Callout 气泡显示;"Show callout (custom)" 按钮弹出自定义 callout
- [ ] "Bump custom label" → 自定义 marker 内容变化(tracksViewChanges 重绘)
- [ ] "Redraw custom" / "Animate draggable" 命令有效

## 3. 覆盖物(M5,回归)

- [ ] Polyline(红线)显示;点击有 `polyline onPress` 日志
- [ ] Polygon(蓝色围栏 + 填充)显示
- [ ] Circle(绿色范围圈)显示

## 4. M11 — UrlTile / LocalTile

- [ ] 打开 **"UrlTile: OSM raster overlay"** → OSM 栅格瓦片叠加显示(需网络;国内 OSM 可能慢/不通,若空白先换可达瓦片源排除网络)
- [ ] 关闭开关 → 瓦片消失
- [ ] (LocalTile 无 demo 开关;如需,可临时加 `<LocalTile pathTemplate=...>` 指向本地瓦片)

## 5. M12 — Overlay(图片覆盖物)

- [ ] 打开 **"Overlay: image ground overlay"** → 图片按 bounds 贴在上海区域(需网络取 tiny_logo.png)
- [ ] 关闭 → 图片消失
- [ ] (可选)改 `bearing` 看旋转

## 6. M13 — takeSnapshot

- [ ] 点 **"takeSnapshot"** 按钮 → 面板下方出现地图截图缩略图(`<Image>` 预览)
- [ ] 日志 `takeSnapshot → ok`;不为 empty/error

## 7. M14 — Geojson

- [ ] 打开 **"Geojson: point + line + polygon"** → 出现 1 个点 marker + 1 条线 + 1 个面
- [ ] 关闭 → 全部消失

## 8. M15 — 命令补全

- [ ] 点 **"setMapBoundaries"** → 地图可平移范围被限制在上海框内(拖到边界会被挡回)
- [ ] 点 **"getMarkersFrames"** → 日志输出各 marker 的 identifier(bund, square, default, image, custom, draggable)

## 9. M16 — Polyline 渐变

- [ ] 打开 **"Polyline: gradient (M16)"** → 红线变成 红→绿→蓝 渐变;线端/拐角为圆角(lineCap/lineJoin round)
- [ ] 关闭 → 回到单色红线

## 10. M17 — Heatmap

- [ ] 打开 **"Heatmap: weighted points (M17)"** → 上海区域出现热力图色块(权重不同浓淡不同)
- [ ] 关闭 → 消失

## 11. M18 — WMSTile

- [ ] 打开 **"WMSTile: OSM-WMS (M18)"** → WMS 图层叠加(terrestris OSM-WMS,需网络;不通则换 WMS 源)
- [ ] 关闭 → 消失

## 12. 稳定性

- [ ] 反复开关上述图层 10+ 次不崩、不泄漏(观察是否卡顿)
- [ ] 切到后台再回前台地图正常(onHostPause/Resume)
- [ ] 横竖屏切换地图正常

---

## iOS(✅ 全部通过 2026-06-06)

> ✅ 首次 `pod install` + 编译 + 模拟器/真机逐项验证全通过。bring-up 修复见 `CODE_REVIEW_FINDINGS.md`「iOS bring-up findings」。下列为复跑步骤 + 环境要点。

- [x] `cd example/ios && pod install`
- [x] AMap iOS key 写入 `Info.plist` 的 `AMapApiKey`;隐私合规由 `setPrivacyConsent`(iOS TurboModule 已实现)处理
- [x] 编译通过(模拟器 + 真机)
- [x] 逐项重复上面 1–12 —— **全通过**

**环境要点(host app 必读)**:
- **模拟器(Apple Silicon)**:AMap 无 arm64-sim 切片,Podfile `post_install` 需给所有 pod 加 `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64`(见 README);模拟器以 Rosetta/x86_64 运行。真机 arm64 不受影响。
- **真机打包**:JS bundle 阶段的 `NODE_BINARY`(`ios/.xcode.env.local`)需指向 **Node ≥ 22.12**(metro.config 的 `react-native-monorepo-config` 是 ESM)。

## 发现的问题(记录区)

| 项 | 平台 | 现象 | 状态 |
|---|---|---|---|
| | | | |
