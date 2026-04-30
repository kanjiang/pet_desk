/**
 * 颜色提取 - 从 RgbColor 数组用 K-means 得到主色板.
 *
 * M1 阶段是最小可用版: k=4, 8 次迭代, 距离用 RGB 欧氏 (后续可换 LAB).
 * 与 PixelSampler 解耦: 这里不依赖 ImageKit, 方便单测.
 */

export interface RgbColor {
  r: number;
  g: number;
  b: number;
}

export interface ExtractResult {
  primary: string;
  secondary: string;
  accent: string;
  shades: string[];
}

const MAX_ITER: number = 8;

function rgbToHex(c: RgbColor): string {
  const toHex = (v: number): string => {
    const clamped: number = Math.max(0, Math.min(255, Math.round(v)));
    const s: string = clamped.toString(16);
    return s.length === 1 ? '0' + s : s;
  };
  return '#' + toHex(c.r) + toHex(c.g) + toHex(c.b);
}

function distSq(a: RgbColor, b: RgbColor): number {
  const dr: number = a.r - b.r;
  const dg: number = a.g - b.g;
  const db: number = a.b - b.b;
  return dr * dr + dg * dg + db * db;
}

function pickInitialCentroids(pixels: RgbColor[], k: number): RgbColor[] {
  const step: number = Math.max(1, Math.floor(pixels.length / k));
  const out: RgbColor[] = [];
  for (let i: number = 0; i < k; i++) {
    out.push(pixels[i * step]);
  }
  return out;
}

export function kmeans(pixels: RgbColor[], k: number = 4): RgbColor[] {
  if (pixels.length === 0) {
    return [];
  }
  let centroids: RgbColor[] = pickInitialCentroids(pixels, k);
  const assign: number[] = new Array<number>(pixels.length).fill(0);

  for (let iter: number = 0; iter < MAX_ITER; iter++) {
    for (let i: number = 0; i < pixels.length; i++) {
      let best: number = 0;
      let bestD: number = Number.MAX_VALUE;
      for (let c: number = 0; c < centroids.length; c++) {
        const d: number = distSq(pixels[i], centroids[c]);
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      assign[i] = best;
    }

    const sums: RgbColor[] = [];
    const counts: number[] = [];
    for (let c: number = 0; c < k; c++) {
      sums.push({ r: 0, g: 0, b: 0 });
      counts.push(0);
    }
    for (let i: number = 0; i < pixels.length; i++) {
      const idx: number = assign[i];
      sums[idx].r += pixels[i].r;
      sums[idx].g += pixels[i].g;
      sums[idx].b += pixels[i].b;
      counts[idx] += 1;
    }
    centroids = centroids.map((old, idx) => {
      const n: number = counts[idx];
      if (n === 0) {
        return old;
      }
      return { r: sums[idx].r / n, g: sums[idx].g / n, b: sums[idx].b / n };
    });
  }

  return centroids;
}

export function extractPalette(pixels: RgbColor[]): ExtractResult {
  const centroids: RgbColor[] = kmeans(pixels, 4);
  const shades: string[] = centroids.map(rgbToHex);
  return {
    primary: shades[0] ?? '#E8A24C',
    secondary: shades[1] ?? '#FFFFFF',
    accent: shades[2] ?? '#C97A6A',
    shades,
  };
}
