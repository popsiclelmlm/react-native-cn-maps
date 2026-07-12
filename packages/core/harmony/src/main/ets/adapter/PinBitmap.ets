/*
 * 共享的「着色大头针」位图工具。
 *
 * 背景：RNM 的 Marker 支持 pinColor（随机/语义色默认图钉），但鸿蒙端只有高德 SDK
 * 自带按色相生成默认 marker 的工厂（defaultMarkerASync(hue)）；百度/腾讯/MapKit
 * 均无等价能力。这里用 OffscreenCanvas 自绘一枚经典大头针（圆头 + 尖脚 + 白色内点），
 * fillStyle 直接消化 CSS 颜色字符串（#rgb/#rrggbb/rgba()/命名色），无需自行解析。
 *
 * 同色 PixelMap 进程级缓存（海量标注示例会成百次请求同色 pin）。
 */
import image from '@ohos.multimedia.image';

// 注意：各家 SDK 都把 PixelMap 按逻辑像素 ×DPI 显示（真机 66×92 位图显示成 ~230px 巨钉），
// 画布用小逻辑尺寸，显示时 ×3.25DPI ≈ 72×98 物理 px，与各家默认图钉相当。
const PIN_W = 22;
const PIN_H = 30;

const cache = new Map<string, image.PixelMap>();

export const TINTED_PIN_WIDTH = PIN_W;
export const TINTED_PIN_HEIGHT = PIN_H;

export function tintedPinPixelMap(color: string): image.PixelMap | null {
  const cached = cache.get(color);
  if (cached !== undefined) {
    return cached;
  }
  try {
    const settings = new RenderingContextSettings(true);
    const canvas = new OffscreenCanvas(PIN_W, PIN_H);
    const ctx = canvas.getContext('2d', settings);
    const cx = PIN_W / 2;
    const r = PIN_W / 2 - 5;
    const cy = r + 3;
    // 上部约 234° 的圆弧，下部开口用两条二次贝塞尔收到底部尖端
    const a = Math.PI * 0.15;
    ctx.beginPath();
    ctx.arc(cx, cy, r, Math.PI - a, Math.PI * 2 + a);
    ctx.quadraticCurveTo(cx + r * 0.5, cy + r * 1.1, cx, PIN_H - 2);
    ctx.quadraticCurveTo(cx - r * 0.5, cy + r * 1.1, cx - r * Math.cos(a), cy + r * Math.sin(a));
    ctx.closePath();
    ctx.fillStyle = color;
    ctx.fill();
    ctx.lineWidth = 1;
    ctx.strokeStyle = 'rgba(0,0,0,0.35)';
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.38, 0, Math.PI * 2);
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    const pm = ctx.getPixelMap(0, 0, PIN_W, PIN_H);
    cache.set(color, pm);
    return pm;
  } catch (_e) {
    return null;
  }
}
