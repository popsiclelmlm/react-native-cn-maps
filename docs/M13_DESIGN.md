# M13 设计:takeSnapshot(地图截图)

> 对应 [RNM_PARITY_PLAN.md](RNM_PARITY_PLAN.md) M13(P1)。复用 M6 的「命令 + `onCommandResult` 按 requestId 回传 Promise」机制,新增一个**异步返回图片**的命令。

## 架构

`mapRef.current.takeSnapshot(options?)` → `Promise<string>`。底层是一条 codegen command,native 异步截图后通过 `onCommandResult{ id, data }` 把结果按 `requestId` 回传,JS 端 `query<string>` 把 Promise resolve 成 uri/base64 字符串。

- 类型已在 M1 备好:`takeSnapshot?(options?: SnapshotOptions): Promise<string>`,`SnapshotOptions = { width?, height?, region?, format?: 'png'|'jpg', quality?, result?: 'file'|'base64' }`。

## 命令签名

```
takeSnapshot(viewRef, requestId: Int32, width: Int32, height: Int32,
             format: string, quality: Double, result: string)
```
- `width`/`height`:0 表示用地图视图当前尺寸;>0 则把结果缩放到该尺寸。
- `format`:`"png"` | `"jpg"`。
- `quality`:0..1(仅 jpg 有意义)。
- `result`:`"file"`(默认)| `"base64"`。

回传 `onCommandResult.data = JSON.stringify({ uri })`:
- file 模式:`uri = "file://<临时文件路径>"`。
- base64 模式:`uri = <raw base64 字符串>`。

JS `query<string>` 的 parse 取 `data.uri`。

## native 实现要点

- **Android**:`aMap.getMapScreenShot(OnMapScreenShotListener)` → 回调拿 `Bitmap`;按需缩放;`compress(PNG/JPEG, quality*100)` 得字节:
  - file:写入 `context.cacheDir/map-snapshot-<requestId>.png|jpg`,uri = `file://...`。
  - base64:`Base64.encodeToString(bytes, NO_WRAP)`。
  - 在回调里 `dispatchCommandResult(requestId, { uri })`。
- **iOS**:`[mapView takeSnapshotInRect:mapView.bounds withCallback:^(UIImage *image, NSInteger state){...}]`;按需缩放;`UIImagePNGRepresentation` / `UIImageJPEGRepresentation(img, quality)`:
  - file:写 `NSTemporaryDirectory()`,uri = `file://...`。
  - base64:`[data base64EncodedStringWithOptions:0]`。
  - `emitCommandResult:requestId data:@{ @"uri": uri }`。回调可能触发多次,JS 端首个 resolve 后即删除 resolver,重复回传无害。

## 本期范围与 best-effort

- **核心保证**:截当前视口为 png/jpg,file/base64 两种返回,可缩放;Android 双端(iOS 待真机验证)。
- **best-effort / 文档化**:`SnapshotOptions.region`(指定区域截图)本期**忽略**,只截当前视口(RNM 的 region 截图在国内 SDK 上语义不直接对应)。

## 三层落点

- **JS**:`MapViewNativeComponent.ts` 增加 `takeSnapshot` 命令 + `supportedCommands`;`MapView.tsx` 命令式 handle 增加 `takeSnapshot`(`query<string>`,parse 取 `data.uri`)。
- **iOS**:`RNMapsMapView.mm` 增加 `- (void)takeSnapshot:...`(由 `RCTRNMapsMapViewHandleCommand` 分发)。
- **Android**:`MapViewManager.kt` 增加 `override fun takeSnapshot(...)` 委托给 `MapView.takeSnapshotResult(...)`;`MapView.kt` 实现截图 + 写文件/编码 + `dispatchCommandResult`。
- **example**:新增 "takeSnapshot" 按钮,截图后用 `<Image>` 预览。
- **测试**:命令式 API 主要靠真机;JS 侧补一个 `supportedCommands` 含 `takeSnapshot` 的断言。

## 验收(同步回 RNM_PARITY_PLAN.md M13)

- [ ] 三层落地 + codegen/typecheck/lint/jest 通过
- [ ] 返回可用 uri,能 `<Image>` 显示(file 模式)
- [ ] base64 模式可用
- [ ] Android 真机验证 / iOS 真机验证
