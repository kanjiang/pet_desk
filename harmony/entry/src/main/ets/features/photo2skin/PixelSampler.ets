/**
 * PixelSampler - 把照片 URI 解码成下采样后的 RgbColor 数组.
 *
 * 流程:
 *   uri -> fileIo 读全文件到 ArrayBuffer
 *      -> image.createImageSource(buf).createPixelMap({desiredSize: 96x96, RGBA_8888})
 *      -> readPixelsToBufferSync(rgba)
 *      -> 中心 60% 区域采样, 跳过明显的"白墙/灰底"背景色
 *      -> 返回 RgbColor[]
 *
 * 设计要点:
 *   - 显式 RGBA_8888, 避开默认 BGRA_8888 的颜色翻转坑
 *   - 96x96 已足够 K-means 提主色, 单张总像素 < 1 万, 几十毫秒
 *   - 中心权重: 大概率宠物在画面中心
 *   - 释放: PixelMap.release() 必须调, 否则 native buffer 会累积
 */

import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { RgbColor } from './ColorExtractor';

const TAG: string = 'PetDesk.PixelSampler';
const DOMAIN: number = 0xC001;

const SAMPLE_W: number = 96;
const SAMPLE_H: number = 96;
const CENTER_RATIO: number = 0.6;

export interface SamplerStats {
  totalPixels: number;
  keptPixels: number;
}

export interface SampleResult {
  pixels: RgbColor[];
  stats: SamplerStats;
}

/**
 * 是否应跳过该像素 (粗糙背景过滤).
 */
function shouldSkip(r: number, g: number, b: number): boolean {
  if (r > 235 && g > 235 && b > 235) {
    return true;
  }
  if (r < 18 && g < 18 && b < 18) {
    return true;
  }
  const max: number = Math.max(r, g, b);
  const min: number = Math.min(r, g, b);
  const sat: number = max === 0 ? 0 : (max - min) / max;
  if (sat < 0.08 && max > 200) {
    return true;
  }
  return false;
}

async function readUriToArrayBuffer(uri: string): Promise<ArrayBuffer> {
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const stat = fileIo.statSync(file.fd);
    const size: number = stat.size;
    const buf: ArrayBuffer = new ArrayBuffer(size);
    fileIo.readSync(file.fd, buf);
    return buf;
  } finally {
    fileIo.closeSync(file);
  }
}

export async function samplePixelsFromUri(uri: string): Promise<SampleResult> {
  hilog.info(DOMAIN, TAG, 'sampling uri: %{public}s', uri);

  const fileBuf: ArrayBuffer = await readUriToArrayBuffer(uri);
  const source = image.createImageSource(fileBuf);
  if (!source) {
    throw new Error('createImageSource returned null');
  }

  let pixelMap: image.PixelMap | null = null;
  try {
    pixelMap = await source.createPixelMap({
      desiredSize: { width: SAMPLE_W, height: SAMPLE_H },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: false,
    });
    if (!pixelMap) {
      throw new Error('createPixelMap returned null');
    }

    const byteSize: number = SAMPLE_W * SAMPLE_H * 4;
    const rgba: ArrayBuffer = new ArrayBuffer(byteSize);
    pixelMap.readPixelsToBufferSync(rgba);
    const view: Uint8Array = new Uint8Array(rgba);

    const cropMargin: number = Math.floor(SAMPLE_W * (1 - CENTER_RATIO) / 2);
    const x0: number = cropMargin;
    const x1: number = SAMPLE_W - cropMargin;
    const y0: number = cropMargin;
    const y1: number = SAMPLE_H - cropMargin;

    const out: RgbColor[] = [];
    let skipped: number = 0;
    for (let y: number = y0; y < y1; y++) {
      for (let x: number = x0; x < x1; x++) {
        const idx: number = (y * SAMPLE_W + x) * 4;
        const r: number = view[idx];
        const g: number = view[idx + 1];
        const b: number = view[idx + 2];
        if (shouldSkip(r, g, b)) {
          skipped += 1;
          continue;
        }
        out.push({ r, g, b });
      }
    }

    const total: number = (x1 - x0) * (y1 - y0);
    hilog.info(DOMAIN, TAG, 'sampled %{public}d / %{public}d pixels (skipped %{public}d)',
      out.length, total, skipped);

    return { pixels: out, stats: { totalPixels: total, keptPixels: out.length } };
  } finally {
    if (pixelMap) {
      pixelMap.release();
    }
    source.release();
  }
}
