# 代码评审 findings(待统一修复)

> 全工程逐文件走读产出的问题清单。先记录、后统一修复。修复后把状态改为 ✅,并在对应 PR/commit 注明。

## 图例

- 🔴 **correctness** — 真 bug / 行为错误
- 🔵 **architecture** — 架构 / 设计决策
- 🟡 **cleanup** — 死代码 / 冗余 / 一致性
- ⚪ **minor** — 可选优化(精度、性能、可读性)

状态:⬜ 待修 · 🚧 修复中 · ✅ 已修

---

## A 组:JS 基础层

| ID | 级别 | 文件 | 问题 | 建议修法 | 状态 |
|----|------|------|------|----------|------|
| A1 | 🟡 cleanup | `src/_warnings.ts` | `useWarnNotImplemented` / `__resetWarningsForTests` 已无任何调用方(M11–M18 把 6 个 stub 全转真实现),整文件死代码 | 删除 `src/_warnings.ts` | ⬜ |
| A2 | 🔴 correctness | `src/coordinate.ts` | `toProviderCoordinate/fromProviderCoordinate` 用 `=== 'wgs84'` 二元判断,`bd09` 源坐标落入 `else` 被**静默当作 gcj02**,错位数百米。`CoordinateSystem` 类型声明了 3 种但只处理 2 种 | 补 `bd09ToGcj02 / gcj02ToBd09`(BD-09↔GCJ-02 标准公式),把两个函数改成对**源坐标系**的显式三分派;或至少对 `bd09` 显式 `__DEV__` 警告,避免静默错位 | ⬜ |
| A3 | ⚪ minor | `src/coordinate.ts` | `gcj02ToWgs84` 用一次"减法粗反解"(`原值*2 - 正解`),误差约 1–2 米 | 如需更高精度可改 2–3 次迭代逼近;一般地图够用,可不改 | ⬜ |

### A-arch:多 provider 坐标系规约(挂 M8 百度)

| ID | 级别 | 范围 | 决策 | 状态 |
|----|------|------|------|------|
| A4 | 🔵 architecture | `coordinate.ts` + M8 百度 | 当前"JS 转 gcj02 下发、native 恒收 gcj02"是**正确且可延续**的方向(高德/腾讯原生即 gcj02;百度原生是 **bd09**,但可用 `SDKInitializer.setCoordType(CoordType.GCJ02)`(Android)/ iOS 等价全局设置让其按 gcj02 解释)。**定为统一规约**:native 层恒收发 GCJ-02,各 provider 负责让 SDK 以 gcj02 解释。需在 M8 文档写明 + 百度 provider 初始化时设置 | ⬜ |

> 注:A2(用户源侧 bd09 转换)与 A4(provider 输出侧)是**两件独立的事**——A4 解决"发给哪家 SDK",A2 解决"用户给的数据是 bd09 时先转成 gcj02"。两者都要做。

---

## B 组:JS 核心(MapView / Marker / AnimatedRegion)

_(待走读)_

## C 组:JS 覆盖物/瓦片门面

_(待走读)_

## D 组:JS web stubs

_(待走读)_

## E–G 组:Android

_(待走读)_

## H–J 组:iOS

_(待走读)_

## K 组:example + 配置(podspec / gradle)

_(待走读)_
