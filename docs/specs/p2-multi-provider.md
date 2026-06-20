# P2: 多 provider 接入(高德 / 百度 / 腾讯)

> 状态:**已实现,核心+高德构建验证通过;百度/腾讯包待 SDK 接入后编译验证**
> 上游设计:[`../MULTI_PROVIDER_ARCHITECTURE.md`](../MULTI_PROVIDER_ARCHITECTURE.md)(方案 B)
> 基础:P1(M1 适配层 + M2 monorepo 拆包)已完成,本阶段在其上加 provider 选择 + 两个新厂商包。

---

## 1. 做了什么

| # | 内容 | 验证 |
|---|---|---|
| P2-1 | 原生注册表**按 provider 名**注册/查找;Host(iOS `RNMapsMapView`、Android `MapView`)读 `provider` prop 选 adapter(默认创建、显式 provider 不同则重建并迁移子组件);adapter 暴露 `providerName`。AMap = "amap"。 | ✅ iOS+Android 全量 app 构建(amap)通过 |
| P2-2 | JS 坐标层 **provider-aware**:`PROVIDER_SYSTEM`(amap/tencent=gcj02,**baidu=bd09**),以 GCJ-02 为枢纽中转;`MapView` 解除 amap-only 限制,经 `MapProviderContext` 把 provider 下发给子组件。 | ✅ jest 44/44、tsc、eslint 全绿 |
| P2-3 | **百度包** `packages/baidu`(`react-native-cn-maps-baidu`):iOS `CNBaiduMapAdapter`(BMKMapView)、Android `BaiduMapAdapter`(com.baidu.mapapi)+ podspec/build.gradle/manifest/Package/+load 注册。 | ⏳ 无 SDK,未编译 |
| P2-4 | **腾讯包** `packages/tencent`(`react-native-cn-maps-tencent`):iOS `CNTencentMapAdapter`(QMapKit)、Android `TencentMapAdapter`(com.tencent.tencentmap)+ 同套打包/注册。 | ⏳ 无 SDK,未编译 |

依赖方向不变:**厂商包 → core**;core 不依赖任何厂商包。每个厂商包仅一个 Adapter + SDK 依赖 + 一行注册,自动 autolink(iOS `+load`,Android `*Package`)。

---

## 2. 怎么用(宿主 App)

1. **装核心包 + 想要的厂商包**(可装多家):
   ```sh
   yarn add react-native-cn-maps react-native-cn-maps-amap     # 高德
   yarn add react-native-cn-maps-baidu                          # 百度(可选)
   yarn add react-native-cn-maps-tencent                        # 腾讯(可选)
   ```
2. **配置各 SDK 的 Key / 隐私合规**(各厂商各自要求,见各包 native 配置)。隐私统一经 `setPrivacyConsent()` JS API → 注册表 fan-out 到所有已装厂商。
3. **选 provider**:
   ```tsx
   <MapView provider="baidu" /* 或 "amap" / "tencent" */ />
   ```
   - provider **挂载即固定**;运行时改 `provider` 等价重挂载(给 `MapView` 换 `key`)。
   - 装了多家时,`provider` 决定用哪家;未指定默认第一个注册的(通常 amap)。
4. **坐标系自动处理**:JS 按 provider 把坐标转到原生系(高德/腾讯 GCJ-02,百度 BD-09)。`coordinateSystem` prop 声明你**输入**的坐标系(wgs84/gcj02/bd09)。

---

## 3. 待验证 / 已知缺口(`先不测试` 后续逐项过)

百度/腾讯 Adapter 是**对照各 SDK API 编写但未经编译**(example 未装这两家 SDK)。接入 SDK 后需逐项核对——源码内已用 `// VERIFY:` 标注。重点:

- **iOS**:`BaiduMapKit` / `QMapKit` 的 pod 版本与具体 API 名(隐私入口、快照、覆盖物 renderer 初始化、拖拽枚举值、init-complete 回调名)。
- **Android**:`com.baidu.lbsyun:*` / `com.tencent.map:tencent-map-vector-sdk` 的 artifact 坐标与版本;`setAgreePrivacy` 入口;`min/maxZoom`、indoor/poi 开关方法名。
- **功能缺口(各厂商 SDK 限制)**:
  - 百度 `BMKPolygon` / Android `PolygonOptions` **不支持孔洞**(holes 丢弃)。
  - **热力图 / 瓦片图层**:百度、腾讯均非 `Overlay` 对象(各自专用类),当前 Adapter 留 TODO,未接入。
  - 百度无原生夜间底图(需自定义 style 文件);腾讯夜间用 `MAP_TYPE_DARK`(待核)。
  - marker 坐标动画:百度/腾讯无内建补间,当前为直接 set(待接入各自动画 API)。
- **行为回归矩阵**:三家都需各自 Key + 真机/模拟器实跑(高德同样待你提供 iOS key)。

---

## 4. 验证命令

```sh
# JS(全 provider 共用,已绿)
yarn jest && yarn typecheck && yarn lint

# 核心 + 高德(已绿)
cd example/ios && LANG=en_US.UTF-8 pod install && \
  xcodebuild -workspace CnMapsExample.xcworkspace -scheme CnMapsExample -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
cd example/android && ./gradlew :app:assembleDebug

# 百度/腾讯:在 example 里加对应 workspace 依赖 + 各 SDK,配 Key,再按上面构建
```
