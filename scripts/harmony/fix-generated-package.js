/**
 * 修补 codegen-harmony 生成的 RNOHGeneratedPackage.h，使其在 RNOH 0.72.38 上可编译。
 *
 * CLI（0.72.140）生成的 GeneratedEventEmitRequestHandler 用了
 * `ShadowViewRegistry::getComponentName(tag)`，但运行时的 RNOH 0.72.38 没有该方法
 * → 报 "no member named 'getComponentName'"。该调用只是把事件按组件名过滤；改为仅按
 * 事件名过滤即可（emitter 已按 tag 取，cn-maps 地图事件实际经 ArkTS emitComponentEvent
 * 分发）。
 *
 * 幂等：codegen 每次会重写此文件，故需在 `codegen` 之后运行本脚本。
 */
const fs = require('fs');
const path = require('path');

const target = path.resolve(
  __dirname,
  '../../example/harmony/entry/src/main/cpp/generated/RNOHGeneratedPackage.h'
);

if (!fs.existsSync(target)) {
  console.log(`[fix-generated-package] 未找到 ${target}，跳过。`);
  process.exit(0);
}

let s = fs.readFileSync(target, 'utf8');

if (s.includes('// [patch] no getComponentName')) {
  console.log('[fix-generated-package] 已打过补丁。');
  process.exit(0);
}

// 1) 删掉 getComponentName 取值行
s = s.replace(
  /\n\s*auto componentName = ctx\.shadowViewRegistry->getComponentName\(ctx\.tag\);/,
  '\n        // [patch] no getComponentName: RNOH 0.72.38 的 ShadowViewRegistry 无此方法'
);

// 2) 条件里去掉 componentName 过滤，仅保留事件名过滤
s = s.replace(
  /if \(std::find\(supportedComponentNames\.begin\(\), supportedComponentNames\.end\(\), componentName\) != supportedComponentNames\.end\(\) &&\s*\n\s*(std::find\(supportedEventNames[^\n]*\{)/,
  '(void)supportedComponentNames;\n        if ($1'
);

fs.writeFileSync(target, s, 'utf8');
console.log('[fix-generated-package] 已修补 RNOHGeneratedPackage.h（去除 getComponentName）。');
