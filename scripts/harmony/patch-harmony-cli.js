/**
 * 修补 @react-native-oh/react-native-harmony-cli 的库扫描：让它跟随符号链接。
 *
 * monorepo 里 `react-native-cn-maps` 等是用 `file:` 装的 → node_modules 下是 symlink。
 * CLI 的 ProjectDependenciesManager 用 `dirent.isDirectory()` 判断目录，而 symlink 的
 * isDirectory() 返回 false → 本地库被整体漏扫，`codegen-harmony` 生成 `{modules:{}}`，
 * 组件拿不到 ComponentJSIBinder，JS 端 requireNativeComponent 全部 "not found"。
 *
 * 幂等：已打过补丁则跳过。`npm install` 会还原 node_modules，故 codegen 前需先跑本脚本。
 */
const fs = require('fs');
const path = require('path');

const target = path.resolve(
  __dirname,
  '../../example/harmony/node_modules/@react-native-oh/react-native-harmony-cli/dist/core/ProjectDependenciesManager.js'
);

if (!fs.existsSync(target)) {
  console.log(`[patch-harmony-cli] 未找到 ${target}，跳过。`);
  process.exit(0);
}

let s = fs.readFileSync(target, 'utf8');

if (s.includes('// [patch] follow symlinked deps')) {
  console.log('[patch-harmony-cli] 已打过补丁。');
  process.exit(0);
}

const before =
  '            for (let dirent of this.fs.readDirentsSync(directoryPath)) {\n' +
  '                if (dirent.isDirectory()) {\n';
const after =
  '            for (let dirent of this.fs.readDirentsSync(directoryPath)) {\n' +
  '                // [patch] follow symlinked deps（monorepo 的 file: 依赖是 symlink，\n' +
  '                // 上游 dirent.isDirectory() 对其返回 false → 漏扫本地库）\n' +
  '                const direntPath = directoryPath.copyWithNewSegment(dirent.name);\n' +
  '                let isDir = dirent.isDirectory();\n' +
  '                if (!isDir) {\n' +
  '                    try { isDir = require("node:fs").statSync(direntPath.toString()).isDirectory(); } catch (e) {}\n' +
  '                }\n' +
  '                if (isDir) {\n';

if (!s.includes(before)) {
  console.warn('[patch-harmony-cli] 未匹配到目标代码（CLI 版本可能已变），跳过。');
  process.exit(0);
}

s = s.replace(before, after);
fs.writeFileSync(target, s, 'utf8');
console.log('[patch-harmony-cli] 已修补 ProjectDependenciesManager.js（跟随 symlink）。');
