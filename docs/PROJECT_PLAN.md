# react-native-cn-maps 项目计划(开发 / 文档 / 发布 / 推广 / 运营)

> 覆盖从「基线验证」到「1.0 + 推广」的完整流程。按阶段(Phase)组织,每阶段有目标、任务、产出、退出标准。里程碑细节见 [ROADMAP.md](ROADMAP.md),迁移支持状态见 [MIGRATION_FROM_RN_MAPS.md](MIGRATION_FROM_RN_MAPS.md)。

## 总览:阶段与节奏

| 阶段 | 主题 | 目标版本 | 退出标准 |
|------|------|----------|----------|
| **P0** | 基线验证 | `0.1.0-alpha` | iOS/Android 真机编译跑通,M1–M7/M10 行为回归通过 |
| **P1** | 补齐常用能力 | `0.2.0` | 覆盖物/样式/缺口补齐,常用迁移场景 90% 可用 |
| **P2** | 多 provider | `0.3.0` | 百度/腾讯接入,provider 抽象稳定 |
| **P3** | Web + 打磨 | `0.4.0` | web 最小可用,性能/生命周期压测过 |
| **P4** | 稳定 & 1.0 | `1.0.0` | 文档完备、CI 全绿、社区有反馈闭环 |

---

## 一、开发计划

### P0 — 基线验证(最高优先,阻塞一切)
- [ ] `pod install` + iOS build;gradle build(让 codegen 重生成 5 个新组件 + commands/events)
- [ ] 修盲写 native 的编译/运行期 bug(预计一轮:API 签名、AMap 方法名、callout 定位、Promise 往返)
- [ ] example 逐项回归:5 类 marker / callout / 3 种 overlay / 相机命令 / 投影命令
- [ ] CI 的 `build-android` / `build-ios` job 真正跑绿(可能要在 CI 注入 AMap 测试 key)
- **产出**:可运行的 alpha;一份「已知问题」清单
- **最不确定、要重点查的几处**:iOS callout `addSubview` 到 annotationView 的定位;Android InfoWindowAdapter 返回无 parent 的 view;M6 Promise 往返;AMap overlay 的 click/object 能力

### P1 — 补齐常用能力(`0.2.0`)
- [ ] 未实现组件:`Overlay`(图片覆盖物)、`Geojson`、`Heatmap`、`UrlTile`/`WMSTile`/`LocalTile`
- [ ] 缺口:`customMapStyle`(AMap 二进制样式)、Polygon `holes`(Android)、Polyline `strokeColors` 渐变、`CalloutSubview` 子项点击、Android `onDeselect`
- [ ] M6 漏的 ref:`setMapBoundaries` / `getMarkersFrames` / `setIndoorActiveLevelIndex` / `addressForCoordinate`
- [ ] 被忽略的 prop 补 native(`mapPadding` 等有 AMap 对应的)

### P2 — 多 provider(`0.3.0`,M8/M9)
- [ ] `coordinateSystem="bd09"` + bd09↔gcj02↔wgs84 三向转换
- [ ] iOS:podspec subspec(`react-native-cn-maps/Baidu`、`/Tencent`)让用户只引自己用的 SDK
- [ ] Android:gradle flavor/variant 同上
- [ ] native 端 `provider` prop dispatch(运行时或编译期)
- [ ] 三家跑同一套 M2–M5 功能矩阵做回归 → 回头重构 provider 抽象层(三家都跑过才抽,避免过早抽象)

### P3 — Web + 打磨(`0.4.0`)
- [ ] `MapView.web` 接 AMap JS API 最小子集(initialRegion / Marker / Polyline)
- [ ] 性能 & 生命周期压测:切页、横竖屏、快速 mount/unmount、大量 marker

### 测试策略(贯穿)
| 层 | 工具 | 内容 |
|----|------|------|
| 单测 | jest | 坐标转换、AnimatedRegion、JS facade 纯逻辑 |
| 快照 | jest + 渲染器 | 组件 props→native props 映射(需补 react-test-renderer 或 RTL) |
| E2E | Detox/Maestro | 例子页关键交互(后期,可选) |
| 手测矩阵 | 真机 | iOS/Android × provider × 功能 的回归表 |

---

## 二、文档计划

| 文档 | 内容 | 优先级 |
|------|------|--------|
| README(中英) | 卖点、安装、最小示例、支持矩阵徽章 | P0 |
| 快速开始 | 安装 → AMap key 配置(iOS/Android 分步)→ 第一个地图 | P0 |
| 迁移指南(已起草) | 逐 API ✅/⚠️/❌ 表 + 迁移最小三步(import + key + coordinateSystem) | P0 |
| API Reference | 自动生成(typedoc)+ 手写差异说明 | P1 |
| 组件示例 | 每个组件一段可复制代码 + 截图/GIF | P1 |
| 故障排查 FAQ | 坐标偏移、白屏(key 错)、marker 不显示、callout 不弹 | P1 |
| 贡献指南 | 架构图(map→marker→callout 拦截模型)、codegen 流程、PR 规范 | P2 |
| CHANGELOG | release-it + conventional-changelog 自动生成 | P0 起 |

> 建议用 Docusaurus/VitePress 建独立文档站,比纯 README 更利于 SEO 和推广。

---

## 三、发布计划

- **语义化版本**:0.x 阶段允许破坏性变更;1.0 后严格 semver。
- **节奏**:alpha(P0)→ beta(P1)→ 0.2/0.3/0.4 稳定小版本 → 1.0。
- **自动化**:`release-it` + conventional-changelog 已配好;打 tag → 自动 changelog + npm publish + GitHub release。
- **质量门禁**:发版前 CI 必须全绿(lint/typecheck/jest/android/ios/web build)。
- **npm 包**:`react-native-cn-maps`,关键词补 `amap`/`baidu-map`/`高德`/`react-native-maps`/`fabric`。

---

## 四、推广计划

### 定位 & 差异化(一句话)
> 「react-native-maps 的 API,国内地图的内核——改 import 就能把 RN 项目从 Google Maps 迁到高德/百度/腾讯,只适配新架构(Fabric)。」

核心卖点:**API 对齐 RNM + 新架构原生 + 多国内 provider + 坐标转换内置**。

### 渠道与内容
| 渠道 | 内容形态 |
|------|----------|
| 掘金 / 思否 / 知乎 | 技术长文:「把 RN 地图从 Google 迁到高德」「Fabric 下子 host component 拦截实现 Marker」 |
| V2EX / Reddit r/reactnative / RN 中文社区 | 发布帖 + Demo GIF |
| X/Twitter、RN Radar、This Week In React | 简讯投稿 |
| GitHub | 高质量 README + Topics + `awesome-react-native` PR |
| react-native-maps issues | 在「国内地图」相关 issue 下友善留链接(克制,别 spam) |
| 视频(B站/YouTube) | 5 分钟迁移演示 |

### 内容资产(配合发布)
- [ ] 对比表:cn-maps vs react-native-amap3d vs 自封装(API 兼容性 / 新架构 / provider 数)
- [ ] 一个真实可跑的示例 App(扫码体验 / Expo 兼容说明)
- [ ] 架构博客(拿 M3/M4/M5 设计文档改写)

### 社区运营
- [ ] Issue/PR 模板、`good first issue` 标签
- [ ] Discussions 或微信/Discord 群
- [ ] 响应 SLA(目标:issue 48h 内首次回应)

---

## 五、运营 / 维护(长期)
- 跟进 RN 版本(每个大版本验证 codegen 兼容)
- 跟进高德/百度/腾讯 SDK 版本
- 安全:key 不入库、示例用占位 key + 文档提醒
- 看板:用 GitHub Projects 跟踪 P0–P4

---

## 六、风险 & 对策

| 风险 | 对策 |
|------|------|
| native 盲写 bug 多 | P0 设备验证前置,留足修复时间 |
| 多 provider SDK 体积/key 复杂 | subspec/variant 拆分,文档讲清 |
| RNM API 持续演进 | 迁移文档标注对标的 RNM 版本 |
| 维护人力 | 早做贡献指南 + 架构文档,降门槛 |

---

## 七、成功指标(KPI)

- 技术:CI 全绿、核心场景 0 已知崩溃、迁移文档覆盖率 100%
- 社区:npm 周下载、GitHub star、issue 闭环率
- 北极星:**「真实 RN 项目改 import + 配 key 后,常用功能跑通」的成功案例数**

---

## 迁移者的现实路径(非零改动,但很轻)

改 import → 配高德 key → 多数情况加 `coordinateSystem="wgs84"` → 常用功能(MapView/Marker/Callout/Polyline/Polygon/Circle/相机命令)即可用;高级覆盖物(P1)和其他 provider(P2)按需等后续。
