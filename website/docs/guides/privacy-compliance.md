---
id: privacy-compliance
title: 隐私合规（PIPL · 必读）
sidebar_label: 隐私合规
description: 中国地图 SDK 在声明隐私合规前不会初始化。按 PIPL 展示隐私政策、取得同意，再用 setPrivacyConsent 转达给 SDK。
---

# 隐私合规（必读）

:::danger 不做这一步，地图就是空白
中国地图 SDK（高德等）在宿主应用**声明隐私合规之前不会初始化，地图渲染为空白**（高德会输出日志 `555570`）。这不是 bug，是各家 SDK 遵循《个人信息保护法》(PIPL) 与应用商店审核要求的强制行为。
:::

## 你的责任 vs 库的责任

依照 PIPL 与应用商店审核要求，应在初始化地图**之前**向用户展示隐私政策并取得同意。职责划分：

- **你的应用负责**：撰写隐私政策（须包含所用地图 SDK 的条款）、在合适时机弹窗展示、取得用户明确同意。
- **本库负责**：在你告知"用户已同意"后，把这一状态转达给底层地图 SDK，使其初始化。

> **本库绝不代为同意。** `setPrivacyConsent` 只是转达你的应用已经取得的同意，不替用户做决定。

## 用法

用户点击你自己的隐私弹窗"同意"后，在挂载任何 `<MapView>` **之前**调用一次：

```tsx title="App.tsx"
import { setPrivacyConsent } from 'react-native-cn-maps';

// 在用户接受你的隐私政策之后：
setPrivacyConsent({ agreed: true, contains: true, shown: true });
```

三个参数（均默认 `true`）：

| 参数 | 含义 |
|---|---|
| `agreed` | 用户已同意隐私政策 |
| `contains` | 你的隐私政策已包含地图 SDK 条款 |
| `shown` | 已向用户展示隐私政策 |

`setPrivacyConsent()` 不传参等价于三者全 `true`。

## 放在哪里调用

在**第一个 `<MapView>` 挂载前**、且**用户已同意后**。典型做法是在应用启动流程里，同意弹窗的回调中调用：

```tsx
function App() {
  const [consented, setConsented] = useState(false);

  const handleAgree = () => {
    setPrivacyConsent({ agreed: true, contains: true, shown: true });
    setConsented(true);
  };

  if (!consented) {
    return <PrivacyDialog onAgree={handleAgree} />;
  }
  return <MapScreen />;
}
```

## 各平台/厂商行为

| 平台 / 厂商 | `setPrivacyConsent` 映射到 |
|---|---|
| 高德 iOS | `+[MAMapView updatePrivacyShow:privacyInfo:]` / `+[MAMapView updatePrivacyAgree:]` |
| 高德 Android | 高德隐私合规接口 |
| 百度 Android | `SDKInitializer.setAgreePrivacy(...)` + `SDKInitializer.initialize(...)` |
| 百度 iOS | `+[BMKMapManager setAgreePrivacy:]`（另需在 `AppDelegate` 用 AK 启动 SDK） |
| 腾讯 | `TencentMapInitializer.setAgreePrivacy(true)` 等（按 SDK 文档） |
| 华为 Map Kit | 空操作——系统地图无需隐私合规初始化 |

高德的 iOS 与 Android 均已实现；百度/腾讯按各自 SDK 的隐私入口接入（见各厂商[原生配置](../native-setup/baidu.md)）。

## 常见问题

- **调了还是空白？** 确认调用发生在 `<MapView>` 挂载**之前**，且原生 SDK key 已配好（[原生配置](../native-setup/amap.md)）。
- **控制台警告 native module 不可用？** 升级后没重新构建原生 App。重装 pod / 重新 build。
- **要不要每次启动都调？** 是，`setPrivacyConsent` 是内存态，应用每次启动都调用一次（在用户已同意的前提下）。
