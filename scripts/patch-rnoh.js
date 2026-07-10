const fs = require('fs');
const path = require('path');

const RNOH_ROOT = path.resolve(
  __dirname,
  '../example/harmony/oh_modules/.ohpm/@rnoh+react-native-openharmony@0.72.38/oh_modules/@rnoh/react-native-openharmony/src/main/ets'
);

// ---------------------------------------------------------------------------
// Patch 1: RNSurface.ets —— 防止 measuredSize 为 undefined 时崩溃。
// ---------------------------------------------------------------------------
function patchRNSurface() {
  const targetFile = path.join(RNOH_ROOT, 'RNSurface.ets');
  if (!fs.existsSync(targetFile)) {
    console.log(`[patch-rnoh] RNSurface.ets not found. Skipping.`);
    return;
  }
  let content = fs.readFileSync(targetFile, 'utf8');
  const targetStr =
    'const newSize: Size =\n      { width: measuredSize.width || selfLayoutInfo.width, height: measuredSize.height || selfLayoutInfo.height }';
  const replacementStr =
    'const newSize: Size =\n      { width: (measuredSize && measuredSize.width) || selfLayoutInfo.width, height: (measuredSize && measuredSize.height) || selfLayoutInfo.height }';
  if (content.includes(replacementStr)) {
    console.log('[patch-rnoh] RNSurface.ets already patched.');
    return;
  }
  if (content.includes(targetStr)) {
    fs.writeFileSync(
      targetFile,
      content.replace(targetStr, replacementStr),
      'utf8'
    );
    console.log('[patch-rnoh] Patched RNSurface.ets (crash guard).');
  } else {
    console.warn(
      '[patch-rnoh] RNSurface.ets target pattern not found (structure changed?).'
    );
  }
}

// ---------------------------------------------------------------------------
// Patch 2: LazyForEach 的 key 去掉 renderKey —— 防止“滚动地图就重载”。
//
// RNOH 各容器用 LazyForEach 渲染子节点，key = `tag@renderKey`。而 DescriptorRegistry
// 每次 updateDescriptor 都会把该 tag 的 renderKey +1。滚动时 ScrollView 提交 shadow
// 树会重发子节点 descriptor（内容不变也算一次更新）→ renderKey 变 → LazyForEach 认为
// 是“新 item”→ 销毁重建整棵子树。对普通 View/Text 无所谓（廉价），但对地图这种自带
// 原生 XComponent 表面的组件，就是每次滚动都销毁+重建地图表面（可见的“重载”）。
//
// 去掉 key 里的 renderKey（只用 tag，本就唯一）后：descriptor 更新走 onDataChange 的
// 原地更新，而非销毁重建。RNOH 组件本来就通过 subscribeToDescriptorChanges 处理原地
// 更新，renderKey 那套“变了就整体重建”只是保守默认，去掉后更省、且不再重载地图。
// ---------------------------------------------------------------------------
function patchLazyForEachKey() {
  const target =
    'descriptorWrapper.tag.toString() + "@" + descriptorWrapper.renderKey';
  const repl = 'descriptorWrapper.tag.toString()';
  let patched = 0;

  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir)) {
      const p = path.join(dir, entry);
      const stat = fs.statSync(p);
      if (stat.isDirectory()) {
        walk(p);
      } else if (p.endsWith('.ets')) {
        const content = fs.readFileSync(p, 'utf8');
        if (content.includes(target)) {
          fs.writeFileSync(p, content.split(target).join(repl), 'utf8');
          patched++;
          console.log(
            `[patch-rnoh] Patched LazyForEach key: ${path.relative(RNOH_ROOT, p)}`
          );
        }
      }
    }
  };

  if (!fs.existsSync(RNOH_ROOT)) {
    console.log(
      '[patch-rnoh] RNOH root not found. Skipping LazyForEach patch.'
    );
    return;
  }
  walk(RNOH_ROOT);
  if (patched === 0) {
    console.log(
      '[patch-rnoh] LazyForEach key already patched (or pattern not found).'
    );
  } else {
    console.log(`[patch-rnoh] Patched ${patched} LazyForEach key site(s).`);
  }
}

try {
  patchRNSurface();
  patchLazyForEachKey();
} catch (err) {
  console.error('[patch-rnoh] Error while patching RNOH:', err);
  process.exit(1);
}
