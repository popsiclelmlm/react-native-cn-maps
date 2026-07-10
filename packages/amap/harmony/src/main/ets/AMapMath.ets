/*
 * Pure, SDK-free math helpers for the AMap adapter. Extracted from AMapAdapter so
 * they can be unit-tested with @ohos/hypium without any map SDK or device (number
 * in → number out, string in → string out). Ported 1:1 from AMapAdapter.kt.
 */

// RNM rotation is clockwise degrees; AMap's rotateAngle is counterclockwise.
export function rnRotationToAMap(degrees: number): number {
  let normalized = (360 - (degrees % 360)) % 360;
  if (normalized < 0) {
    normalized += 360;
  }
  return normalized;
}

// Parse a CSS color (#RGB / #RRGGBB / #AARRGGBB) to [r,g,b] 0..255, or null.
export function parseColor(color: string): [number, number, number] | null {
  let hex = color.trim();
  if (!hex.startsWith('#')) {
    return null;
  }
  hex = hex.substring(1);
  if (hex.length === 3) {
    hex = `${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}`;
  }
  if (hex.length === 8) {
    hex = hex.substring(2); // drop alpha
  }
  if (hex.length !== 6) {
    return null;
  }
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  if (isNaN(r) || isNaN(g) || isNaN(b)) {
    return null;
  }
  return [r, g, b];
}

// CSS color → HSV hue 0..360 (for AMap's default-marker hue), or null.
export function markerHue(color: string | null): number | null {
  if (color === null) {
    return null;
  }
  const rgb = parseColor(color);
  if (rgb === null) {
    return null;
  }
  const r = rgb[0] / 255;
  const g = rgb[1] / 255;
  const b = rgb[2] / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const d = max - min;
  if (d === 0) {
    return 0;
  }
  let h = 0;
  if (max === r) {
    h = ((g - b) / d) % 6;
  } else if (max === g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h *= 60;
  return h < 0 ? h + 360 : h;
}

// EPSG:3857 bbox substitution for WMS tiles.
export function wmsUrl(template: string, x: number, y: number, zoom: number, tileSize: number): string {
  const m = 20037508.342789244;
  const tileMeters = (2 * m) / (1 << zoom);
  const minX = -m + x * tileMeters;
  const maxX = -m + (x + 1) * tileMeters;
  const maxY = m - y * tileMeters;
  const minY = m - (y + 1) * tileMeters;
  return template
    .replace('{minX}', `${minX}`)
    .replace('{minY}', `${minY}`)
    .replace('{maxX}', `${maxX}`)
    .replace('{maxY}', `${maxY}`)
    .replace('{width}', `${tileSize}`)
    .replace('{height}', `${tileSize}`);
}
