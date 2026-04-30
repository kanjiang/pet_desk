/**
 * 预设模型注册表 - 把 BaseModelId 映射到 rawfile 路径与动画 clip 名.
 *
 * 单一事实源, 修改/新增预设宠物只改这里.
 *
 * 约定 (详见 resources/rawfile/models/README.md):
 * - 模型放在 entry/src/main/resources/rawfile/models/<id>.glb
 * - clip 名在 DEFAULT_ANIMS 里映射, 美术换名只改这一处
 * - 主色网格在节点路径 'rootNode_/Body' (M1 美术约定, 后续可在此 override)
 */

import { BaseModelId } from '../../common/models/SkinProfile';
import { PetAction } from '../../common/models/PetState';

export interface ModelDescriptor {
  id: BaseModelId;
  rawfilePath: string;
  bodyMeshNodePath: string;
  animationByAction: Record<string, string>;
}

const DEFAULT_ANIMS: Record<string, string> = {
  idle: 'idle',
  walk: 'walk',
  sit: 'sit',
  sleep: 'sleep',
  eat: 'eat',
  play_ball: 'play',
  play_toy: 'play',
  scratch: 'scratch',
  happy_jump: 'jump',
  stretch: 'stretch',
  sunbathe: 'sit',
  comfort: 'sit',
};

const REGISTRY: Record<BaseModelId, ModelDescriptor> = {
  shorthair_cat: {
    id: 'shorthair_cat',
    rawfilePath: 'models/shorthair_cat.glb',
    bodyMeshNodePath: 'rootNode_/Body',
    animationByAction: DEFAULT_ANIMS,
  },
  longhair_cat: {
    id: 'longhair_cat',
    rawfilePath: 'models/longhair_cat.glb',
    bodyMeshNodePath: 'rootNode_/Body',
    animationByAction: DEFAULT_ANIMS,
  },
  shiba: {
    id: 'shiba',
    rawfilePath: 'models/shiba.glb',
    bodyMeshNodePath: 'rootNode_/Body',
    animationByAction: DEFAULT_ANIMS,
  },
  golden_retriever: {
    id: 'golden_retriever',
    rawfilePath: 'models/golden_retriever.glb',
    bodyMeshNodePath: 'rootNode_/Body',
    animationByAction: DEFAULT_ANIMS,
  },
  border_collie: {
    id: 'border_collie',
    rawfilePath: 'models/border_collie.glb',
    bodyMeshNodePath: 'rootNode_/Body',
    animationByAction: DEFAULT_ANIMS,
  },
  rabbit_lop: {
    id: 'rabbit_lop',
    rawfilePath: 'models/rabbit_lop.glb',
    bodyMeshNodePath: 'rootNode_/Body',
    animationByAction: DEFAULT_ANIMS,
  },
  hamster: {
    id: 'hamster',
    rawfilePath: 'models/hamster.glb',
    bodyMeshNodePath: 'rootNode_/Body',
    animationByAction: DEFAULT_ANIMS,
  },
};

export function describe(id: BaseModelId): ModelDescriptor {
  return REGISTRY[id];
}

export function clipForAction(desc: ModelDescriptor, action: PetAction): string {
  return desc.animationByAction[action] ?? desc.animationByAction['idle'] ?? 'idle';
}
