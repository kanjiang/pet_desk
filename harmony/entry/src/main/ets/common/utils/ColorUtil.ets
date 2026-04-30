/**
 * 颜色工具 - 把十六进制色串转换为 ArkGraphics 3D 用的归一化 Vec4.
 *
 * 输入: '#RRGGBB' 或 '#RRGGBBAA'.
 * 输出: { x, y, z, w } 各分量 0..1, 与 @kit.ArkGraphics3D 的 Vec4 兼容.
 */

export interface RgbaNormalized {
  x: number;
  y: number;
  z: number;
  w: number;
}

const FALLBACK: RgbaNormalized = { x: 1, y: 1, z: 1, w: 1 };

export function hexToRgbaNormalized(hex: string): RgbaNormalized {
  const stripped: string = hex.startsWith('#') ? hex.slice(1) : hex;
  if (stripped.length !== 6 && stripped.length !== 8) {
    return FALLBACK;
  }
  const r: number = parseInt(stripped.substring(0, 2), 16);
  const g: number = parseInt(stripped.substring(2, 4), 16);
  const b: number = parseInt(stripped.substring(4, 6), 16);
  const a: number = stripped.length === 8 ? parseInt(stripped.substring(6, 8), 16) : 255;
  if (Number.isNaN(r) || Number.isNaN(g) || Number.isNaN(b) || Number.isNaN(a)) {
    return FALLBACK;
  }
  return { x: r / 255, y: g / 255, z: b / 255, w: a / 255 };
}
