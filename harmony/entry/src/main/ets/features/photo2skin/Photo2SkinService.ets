/**
 * Photo2SkinService - 照片到 SkinProfile 的端到端编排.
 *
 * 输入: 已选 photo URI 数组 (来自 PhotoViewPicker) + 目标 petId/petName.
 * 步骤:
 *   1. 对每张照片调 PixelSampler 拿 RgbColor[]
 *   2. 合并所有像素 (上限 30000, 防止 K-means 太慢)
 *   3. extractPalette 得 ExtractResult
 *   4. 合成 SkinProfile, 通过 SkinRepo.save 写入 (会自动持久化 + 广播)
 *   5. 返回结果, 让 UI 显示色板供用户确认/重做
 */

import { hilog } from '@kit.PerformanceAnalysisKit';

import { SkinProfile, BaseModelId } from '../../common/models/SkinProfile';
import { SkinRepo } from '../storage/SkinRepo';
import { extractPalette, ExtractResult, RgbColor } from './ColorExtractor';
import { samplePixelsFromUri } from './PixelSampler';

const TAG: string = 'PetDesk.Photo2Skin';
const DOMAIN: number = 0xC001;

const MAX_PHOTOS: number = 5;
const MAX_TOTAL_PIXELS: number = 30000;

export interface BuildSkinInput {
  petId: string;
  petName: string;
  baseModelId: BaseModelId;
  photoUris: string[];
}

export interface BuildSkinResult {
  profile: SkinProfile;
  palette: ExtractResult;
  sampledPhotos: number;
  totalPixels: number;
}

function downsample<T>(arr: T[], maxLen: number): T[] {
  if (arr.length <= maxLen) {
    return arr;
  }
  const step: number = Math.floor(arr.length / maxLen);
  const out: T[] = [];
  for (let i: number = 0; i < arr.length; i += step) {
    out.push(arr[i]);
    if (out.length >= maxLen) {
      break;
    }
  }
  return out;
}

export async function buildSkinFromPhotos(input: BuildSkinInput): Promise<BuildSkinResult> {
  if (input.photoUris.length === 0) {
    throw new Error('photoUris is empty');
  }
  const uris: string[] = input.photoUris.slice(0, MAX_PHOTOS);
  hilog.info(DOMAIN, TAG, 'building skin from %{public}d photo(s)', uris.length);

  const allPixels: RgbColor[] = [];
  let succeeded: number = 0;
  for (const uri of uris) {
    try {
      const result = await samplePixelsFromUri(uri);
      for (const p of result.pixels) {
        allPixels.push(p);
      }
      succeeded += 1;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'sample failed: %{public}s', String(err));
    }
  }

  if (allPixels.length === 0) {
    throw new Error('no usable pixels after sampling all photos');
  }

  const reduced: RgbColor[] = downsample(allPixels, MAX_TOTAL_PIXELS);
  hilog.info(DOMAIN, TAG, 'kmeans on %{public}d pixels', reduced.length);
  const palette: ExtractResult = extractPalette(reduced);

  const now: number = Date.now();
  const existing: SkinProfile = SkinRepo.instance().get(input.petId);
  const profile: SkinProfile = {
    petId: input.petId,
    petName: input.petName,
    baseModelId: input.baseModelId,
    palette: {
      primary: palette.primary,
      secondary: palette.secondary,
      nose: palette.accent,
      eyes: existing.palette.eyes,
    },
    sourcePhotos: uris,
    createdAt: existing.createdAt || now,
    updatedAt: now,
  };
  SkinRepo.instance().save(profile);

  return {
    profile,
    palette,
    sampledPhotos: succeeded,
    totalPixels: allPixels.length,
  };
}
