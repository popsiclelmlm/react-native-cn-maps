#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# hm.sh —— 鸿蒙(RNOH)示例的 hdc + 模拟器一键测试工具链
#
# 用法:  scripts/harmony/hm.sh <子命令> [参数]
# 例:    scripts/harmony/hm.sh doctor        # 体检：hdc/SDK/设备/依赖/HAP
#        scripts/harmony/hm.sh dev           # 全自动开发模式：装HAP+起Metro+转发+启动+看日志
#        scripts/harmony/hm.sh shot out.jpeg # 截图
#
# 目标设备(target)选择优先级：
#   1) 环境变量 HM_TARGET（如 HM_TARGET=29Q0223920001682 走真机）
#   2) 自动选第一个模拟器（const.product.name == emulator）
#   3) hdc list targets 的第一个
# ---------------------------------------------------------------------------
set -uo pipefail

# ---- 工程常量（如改了 bundleName/ability 在此同步） ------------------------
BUNDLE="com.cnmaps.example"
ABILITY="EntryAbility"
METRO_PORT=8081

# ---- 路径 ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HM_DIR="$REPO_ROOT/example/harmony"
HAP="$HM_DIR/entry/build/default/outputs/default/entry-default-signed.hap"

# ---- 找 hdc：优先 PATH，其次 OpenHarmony SDK toolchains，取最高版本 --------
find_hdc() {
  if command -v hdc >/dev/null 2>&1; then command -v hdc; return; fi
  local base
  for base in "$HOME/Library/OpenHarmony/Sdk" "$HOME/OpenHarmony/Sdk" \
              "/Applications/DevEco-Studio.app/Contents/sdk"; do
    [ -d "$base" ] || continue
    local cand
    cand="$(ls -d "$base"/*/toolchains/hdc 2>/dev/null | sort -V | tail -1)"
    [ -n "$cand" ] && { echo "$cand"; return; }
  done
  echo ""  # 没找到
}
HDC="$(find_hdc)"
if [ -z "$HDC" ]; then
  echo "❌ 找不到 hdc。请确认已装 OpenHarmony SDK，或把 hdc 加入 PATH。" >&2
  exit 1
fi

# ---- 选 target -------------------------------------------------------------
pick_target() {
  if [ -n "${HM_TARGET:-}" ]; then echo "$HM_TARGET"; return; fi
  local list t name
  list="$("$HDC" list targets 2>/dev/null | grep -v '^\[Empty\]' | awk '{print $1}' | grep -v '^$')"
  [ -z "$list" ] && { echo ""; return; }
  # 找模拟器
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    name="$("$HDC" -t "$t" shell param get const.product.name 2>/dev/null | tr -d '[:space:]')"
    [ "$name" = "emulator" ] && { echo "$t"; return; }
  done <<< "$list"
  # 退而求其次：第一个
  echo "$list" | head -1
}

require_target() {
  TARGET="$(pick_target)"
  if [ -z "$TARGET" ]; then
    echo "❌ 没有可用 target。请先在 DevEco 启动模拟器或连真机，再 \`$HDC list targets\` 确认。" >&2
    exit 1
  fi
}

hd() { "$HDC" -t "$TARGET" "$@"; }   # 针对选定 target 的 hdc 快捷封装

# ---- 子命令 ----------------------------------------------------------------
cmd_doctor() {
  echo "🔎 鸿蒙测试环境体检"
  echo "  hdc      : $HDC ($("$HDC" -v 2>/dev/null))"
  echo "  工程目录 : $HM_DIR"
  echo -n "  JS 依赖  : "; [ -d "$HM_DIR/node_modules" ] && echo "✅ 已安装" || echo "❌ 未安装 (跑 \`$0 deps\`)"
  echo -n "  oh_modules: "; [ -d "$HM_DIR/oh_modules/@rnoh" ] && echo "✅ 已安装" || echo "❌ 未安装 (DevEco/ohpm install)"
  echo -n "  签名 HAP : "; [ -f "$HAP" ] && echo "✅ $HAP" || echo "❌ 未构建 (用 DevEco Run/Build 生成)"
  echo "  Targets  :"
  "$HDC" list targets -v 2>/dev/null | sed 's/^/    /'
  TARGET="$(pick_target)"
  [ -n "$TARGET" ] && echo "  → 将使用 : $TARGET"
}

cmd_deps() {
  echo "📦 安装 JS 依赖 (RN 0.72.5 + RNOH + 三家 provider)…"
  ( cd "$HM_DIR" && npm install )
  echo "🩹 打 RNOH 补丁…"
  node "$REPO_ROOT/scripts/patch-rnoh.js" || true
}

cmd_metro() {
  echo "🚀 启动 Metro (harmony 预设, 端口 $METRO_PORT)。保持本窗口打开。"
  ( cd "$HM_DIR" && npx react-native start --reset-cache )
}

cmd_forward() {
  require_target
  hd rport "tcp:$METRO_PORT" "tcp:$METRO_PORT" && \
    echo "🔌 已把模拟器 $TARGET 的 tcp:$METRO_PORT 转发到本机 Metro。"
  hd fport ls 2>/dev/null | grep "$METRO_PORT" || true
}

cmd_install() {
  require_target
  [ -f "$HAP" ] || { echo "❌ 没有 HAP：$HAP（先用 DevEco 构建）" >&2; exit 1; }
  echo "📲 安装到 $TARGET …"
  hd install -r "$HAP"
}

cmd_launch() {
  require_target
  echo "▶️  启动 $BUNDLE/$ABILITY @ $TARGET"
  hd shell aa start -a "$ABILITY" -b "$BUNDLE"
}

cmd_stop() {
  require_target
  hd shell aa force-stop "$BUNDLE" && echo "⏹  已停止 $BUNDLE"
}

cmd_log() {
  require_target
  echo "📜 实时 RNOH 日志（Ctrl-C 退出）。过滤 #RNOH / JSBundle / 异常。"
  hd shell hilog | grep --line-buffered -iE "RNOH|JSBundle|Metro|cnmaps|exception|fatal|Error"
}

cmd_shot() {
  require_target
  local out="${1:-$REPO_ROOT/example/harmony/.screenshot.jpeg}"
  hd shell snapshot_display -f /data/local/tmp/_hm_shot.jpeg >/dev/null 2>&1
  hd file recv /data/local/tmp/_hm_shot.jpeg "$out" >/dev/null 2>&1
  echo "🖼  截图已保存：$out"
}

# 全自动开发模式：装HAP → 后台起Metro → 转发 → 启动 → 跟日志
cmd_dev() {
  require_target
  [ -d "$HM_DIR/node_modules" ] || { echo "⚠️  JS 依赖未装，先跑 \`$0 deps\`"; exit 1; }
  cmd_install
  echo "🚀 后台启动 Metro …"
  ( cd "$HM_DIR" && npx react-native start --reset-cache >/tmp/hm-metro.log 2>&1 & echo $! > /tmp/hm-metro.pid )
  echo "   等待 Metro 就绪…"
  for _ in $(seq 1 30); do
    curl -s "http://localhost:$METRO_PORT/status" 2>/dev/null | grep -q packager && break
    sleep 1
  done
  cmd_forward
  cmd_launch
  echo "✅ 已启动。若白屏：确认 Metro 日志 /tmp/hm-metro.log，并执行 \`$0 reload\`。"
  cmd_log
}

cmd_reload() {
  require_target
  # RN 0.72 触发 reload：重启 ability（最稳）
  hd shell aa force-stop "$BUNDLE" >/dev/null 2>&1
  hd shell aa start -a "$ABILITY" -b "$BUNDLE"
  echo "🔁 已重启以重新拉取 bundle。"
}

# 切换 JS 入口：smoke=纯RN冒烟页(不接地图), app=真实地图demo。改完自动重载。
cmd_smoke() {
  sed -i '' "s#import App from './App';#import App from './App.smoke';#" "$HM_DIR/index.js"
  echo "🧪 index.js → ./App.smoke（纯 RN 冒烟页）"
  cmd_reload 2>/dev/null || true
}
cmd_app() {
  sed -i '' "s#import App from './App.smoke';#import App from './App';#" "$HM_DIR/index.js"
  echo "🗺  index.js → ./App（真实地图 demo）"
  cmd_reload 2>/dev/null || true
}

cmd_bundle() {
  echo "📦 生成发布版 JS bundle 到 rawfile（自包含，无需 Metro）…"
  ( cd "$HM_DIR" && npm run bundle )
  echo "⚠️  发布模式还需：把 entry/.../pages/Index.ets 的 MetroJSBundleProvider"
  echo "    换成 ResourceJSBundleProvider，再用 DevEco 重新 Build HAP。"
}

usage() {
  cat <<EOF
hm.sh —— 鸿蒙(RNOH) hdc+模拟器测试工具链

  doctor            体检：hdc/SDK/target/依赖/HAP
  deps              在 example/harmony 装 JS 依赖 + 打 RNOH 补丁
  dev               全自动开发模式(装HAP→起Metro→转发→启动→看日志) ← 最常用
  reload            重启 app 重新拉 bundle
  install           只装签名 HAP
  launch / stop     启动 / 停止 app
  metro             前台起 Metro
  forward           hdc rport 8081 端口转发
  log               实时看 RNOH 日志
  shot [文件]       截图(默认 example/harmony/.screenshot.jpeg)
  smoke / app       切换 JS 入口：纯RN冒烟页 / 真实地图demo(自动重载)
  bundle            生成发布版自包含 bundle(发布模式)

环境变量: HM_TARGET=<序列号|ip:port> 指定设备(默认自动选模拟器)
EOF
}

case "${1:-}" in
  doctor)  cmd_doctor ;;
  deps)    cmd_deps ;;
  dev)     cmd_dev ;;
  reload)  cmd_reload ;;
  install) cmd_install ;;
  launch)  cmd_launch ;;
  stop)    cmd_stop ;;
  metro)   cmd_metro ;;
  forward) cmd_forward ;;
  log)     cmd_log ;;
  shot)    shift; cmd_shot "${1:-}" ;;
  smoke)   cmd_smoke ;;
  app)     cmd_app ;;
  bundle)  cmd_bundle ;;
  ""|-h|--help|help) usage ;;
  *) echo "未知子命令: $1"; echo; usage; exit 1 ;;
esac
