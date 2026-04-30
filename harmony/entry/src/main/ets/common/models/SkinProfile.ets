/**
 * Photo2Skin 输出的"宠物外观档案".
 * M1 阶段是颜色板 + 预设模型, M2 增加 patternMaskUri, M4 升级到云端 3D.
 */

export type BaseModelId =
  | 'shorthair_cat'
  | 'longhair_cat'
  | 'shiba'
  | 'golden_retriever'
  | 'border_collie'
  | 'rabbit_lop'
  | 'hamster';

export interface PetPalette {
  primary: string;
  secondary: string;
  nose: string;
  eyes: string;
}

export interface SkinProfile {
  petId: string;
  petName: string;
  baseModelId: BaseModelId;
  palette: PetPalette;
  patternMaskUri?: string;
  sourcePhotos: string[];
  createdAt: number;
  updatedAt: number;
}

export function defaultSkinProfile(petId: string, petName: string): SkinProfile {
  const now: number = Date.now();
  return {
    petId,
    petName,
    baseModelId: 'shorthair_cat',
    palette: {
      primary: '#E8A24C',
      secondary: '#FFFFFF',
      nose: '#C97A6A',
      eyes: '#7BC474',
    },
    sourcePhotos: [],
    createdAt: now,
    updatedAt: now,
  };
}
