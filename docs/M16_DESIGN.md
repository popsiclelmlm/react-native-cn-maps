# M16 设计:Polyline 渐变 + 线型补全

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M16(P2)。在 M5 的 Polyline 上补 RNM 的高级线型:逐点渐变 `strokeColors`,以及 `lineCap` / `lineJoin` / `miterLimit`。

## Props(新增)

| RNM prop | 类型 | 传递方式 | Android | iOS |
|---|---|---|---|---|
| `strokeColors` | `ColorValue[]` | JSON 字符串(色值字符串数组,与 holes/dash 一致的 JSON 通道) | ✅ `colorValues + useGradient` | ✅ `MAMultiColoredPolyline` |
| `lineCap` | `'butt'\|'round'\|'square'` | string | ✅ `lineCapType` | ✅ renderer |
| `lineJoin` | `'miter'\|'round'\|'bevel'` | string | ✅ `lineJoinType` | ✅ renderer |
| `miterLimit` | number | double | ❌(AMap 无 setter) | ✅ renderer |

> 落地后确认:AMap Android `PolylineOptions.lineCapType / lineJoinType` 存在,`lineCap`/`lineJoin` 双端都支持;仅 `miterLimit` Android 无对应。

> `strokeColors` 走 JSON 字符串(色值用 CSS 字符串,如 `'#ff0000'`),native 端自行解析,避开 codegen 对 ColorValue 数组的限制。

## native 实现要点

- **Android(头牌:渐变)**:
  - 解析 `strokeColors` JSON → `Color.parseColor` 每个 → `PolylineOptions.colorValues(list).useGradient(true)`(有渐变色时优先于单色 `color`)。
  - `lineCap`/`lineJoin` → AMap `PolylineOptions.lineCapType / lineJoinType`(若 SDK 支持则映射,否则忽略);`miterLimit` 无对应,忽略。
  - 渐变/线型变化走 `rebuild()`(AMap overlay 几何不可变)。
- **iOS**:
  - 有 `strokeColors` 时用 `MAMultiColoredPolyline`(+ `MAMultiColoredPolylineRenderer.strokeColors` + `gradient = YES`);否则用现有 `MAPolyline`。
  - `lineCap`/`lineJoin`/`miterLimit` 落到 renderer(`lineCapType`/`lineJoinType`/`miterLimit`)。

## 本期范围与 best-effort

- **核心保证**:Android 渐变折线(`strokeColors`)显示;Android / iOS 双端编译通过(iOS 待真机)。
- **best-effort / 文档化**:Android 的 `lineCap`/`lineJoin` 视 AMap SDK 支持而定,`miterLimit` Android 不支持;这些在 iOS renderer 上完整。

## 三层落点

- **JS**:`PolylineNativeComponent.ts` 增 `strokeColors`/`lineCap`/`lineJoin`/`miterLimit`;`MapPolyline.tsx` 去掉「ignored」注释,接上这几个 prop(strokeColors → JSON)。
- **Android**:`PolylineView.kt`(渐变 + 线型 rebuild)+ `PolylineManager.kt`(新 `@ReactProp`)。
- **iOS**:`RNMapsPolyline.mm`(MAMultiColoredPolyline 分支 + renderer 线型)。
- **example**:把现有 Polyline 演示加一个渐变开关(`strokeColors`)。
- **测试**:`MapPolyline` 把 `strokeColors` 序列化为 JSON 的纯逻辑断言(或 sentinel 级)。

## 验收(同步回 RNM_PARITY_PLAN.md M16)

- [ ] 三层落地 + codegen/typecheck/lint/jest 通过
- [ ] 渐变折线显示(Android)
- [ ] Android 真机验证 / iOS 真机验证
