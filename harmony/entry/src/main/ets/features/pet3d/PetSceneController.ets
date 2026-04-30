/**
 * PetSceneController - 封装 ArkGraphics 3D Scene 的加载与控制逻辑.
 *
 * 职责:
 *   1. 异步加载 .glb (Scene.load) 并构造 SceneOptions 给 Component3D 使用
 *   2. 创建相机, 设置背景
 *   3. applySkin: 把 SkinProfile 翻译到 Body 网格的 baseColorFactor
 *   4. playAction: 根据 PetAction 启用对应 animation, 关闭其他
 *   5. dispose: 释放 GPU 资源
 *
 * 设计要点:
 *   - 这个类不是 ArkUI 组件, 不持有 @State, 是纯 TS 控制器
 *   - 所有外部操作都是幂等的: 重复 applySkin/playAction 不会报错
 *   - 加载失败时 sceneOpt 仍为 null, 上层 UI 据此回退到占位
 *
 * 注意 (来自实战经验):
 *   - sceneOpt 必须在相机/动画都准备好后再赋值, 否则 Component3D 黑屏
 *   - aboutToDisappear 必须 destroy, 否则 GPU 显存泄漏
 */

import {
  Animation,
  Camera,
  EnvironmentBackgroundType,
  Geometry,
  MaterialType,
  MetallicRoughnessMaterial,
  ModelType,
  Scene,
  SceneResourceFactory,
} from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { PetAction } from '../../common/models/PetState';
import { SkinProfile } from '../../common/models/SkinProfile';
import { hexToRgbaNormalized } from '../../common/utils/ColorUtil';
import { clipForAction, describe, ModelDescriptor } from './ModelRegistry';

const TAG: string = 'PetDesk.PetScene';
const DOMAIN: number = 0xC001;

export interface SceneOptions {
  scene: Scene;
  modelType: ModelType;
}

export type LoadState = 'idle' | 'loading' | 'ready' | 'error';

export class PetSceneController {
  private scene: Scene | null = null;
  private camera: Camera | null = null;
  private currentClip: Animation | null = null;
  private descriptor: ModelDescriptor | null = null;
  private loadState: LoadState = 'idle';
  private lastError: string = '';
  private loadToken: number = 0;

  sceneOpt: SceneOptions | null = null;

  state(): LoadState {
    return this.loadState;
  }

  errorMessage(): string {
    return this.lastError;
  }

  /**
   * 加载或切换模型. 若当前已加载相同 model, 直接返回.
   * 不同 model 时先 destroy 旧 scene 再加载新 scene.
   */
  async ensureModel(skin: SkinProfile): Promise<void> {
    const token: number = ++this.loadToken;
    const desired: ModelDescriptor = describe(skin.baseModelId);
    if (this.descriptor && this.descriptor.id === desired.id && this.scene) {
      return;
    }
    await this.disposeInternal();
    if (token !== this.loadToken) {
      return;
    }
    this.descriptor = desired;
    this.loadState = 'loading';
    this.lastError = '';

    let loaded: Scene | null = null;
    try {
      loaded = await Scene.load($rawfile(desired.rawfilePath));
      if (!loaded) {
        throw new Error('Scene.load returned null');
      }
      if (token !== this.loadToken) {
        loaded.destroy();
        return;
      }
      loaded.environment.backgroundType = EnvironmentBackgroundType.BACKGROUND_NONE;

      const rf: SceneResourceFactory = loaded.getResourceFactory();
      const cam: Camera = await rf.createCamera({ name: 'PetCam' });
      if (token !== this.loadToken) {
        loaded.destroy();
        return;
      }
      cam.enabled = true;
      cam.position.z = 3.5;
      cam.clearColor = { r: 1.0, g: 0.97, b: 0.94, a: 1.0 };
      this.scene = loaded;
      this.camera = cam;

      this.applySkinInternal(skin);
      this.playActionInternal(PetAction.IDLE);

      this.sceneOpt = { scene: loaded, modelType: ModelType.SURFACE };
      this.loadState = 'ready';
      hilog.info(DOMAIN, TAG, 'model ready: %{public}s', desired.id);
    } catch (err) {
      if (token !== this.loadToken) {
        return;
      }
      if (loaded && this.scene !== loaded) {
        try {
          loaded.destroy();
        } catch (destroyErr) {
          hilog.warn(DOMAIN, TAG, 'destroy failed after load error: %{public}s', String(destroyErr));
        }
      }
      this.scene = null;
      this.camera = null;
      this.currentClip = null;
      this.sceneOpt = null;
      this.lastError = err instanceof Error ? err.message : String(err);
      this.loadState = 'error';
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', this.lastError);
    }
  }

  applySkin(skin: SkinProfile): void {
    if (this.loadState !== 'ready') {
      return;
    }
    this.applySkinInternal(skin);
  }

  playAction(action: PetAction): void {
    if (this.loadState !== 'ready') {
      return;
    }
    this.playActionInternal(action);
  }

  async dispose(): Promise<void> {
    this.loadToken += 1;
    await this.disposeInternal();
  }

  private applySkinInternal(skin: SkinProfile): void {
    if (!this.scene || !this.descriptor) {
      return;
    }
    const node = this.scene.getNodeByPath(this.descriptor.bodyMeshNodePath);
    if (!node) {
      hilog.warn(DOMAIN, TAG, 'body mesh node not found: %{public}s', this.descriptor.bodyMeshNodePath);
      return;
    }
    const geom = node as Geometry;
    if (!geom.mesh || geom.mesh.subMeshes.length === 0) {
      hilog.warn(DOMAIN, TAG, 'body mesh has no submeshes');
      return;
    }
    const mat = geom.mesh.subMeshes[0].material;
    if (!mat || mat.materialType !== MaterialType.METALLIC_ROUGHNESS) {
      hilog.warn(DOMAIN, TAG, 'body material not METALLIC_ROUGHNESS, skin skipped');
      return;
    }
    const pbr = mat as MetallicRoughnessMaterial;
    const color = hexToRgbaNormalized(skin.palette.primary);
    pbr.baseColor.factor = { x: color.x, y: color.y, z: color.z, w: color.w };
  }

  private playActionInternal(action: PetAction): void {
    if (!this.scene || !this.descriptor) {
      return;
    }
    const target: string = clipForAction(this.descriptor, action);
    const anims: Animation[] = this.scene.animations ?? [];
    if (anims.length === 0) {
      return;
    }
    let next: Animation | null = null;
    for (const a of anims) {
      const isTarget: boolean = a.name === target;
      a.enabled = isTarget;
      if (isTarget) {
        next = a;
      }
    }
    if (!next) {
      anims[0].enabled = true;
      next = anims[0];
      hilog.warn(DOMAIN, TAG, 'clip %{public}s not found, fallback to %{public}s', target, next.name);
    }
    this.currentClip = next;
  }

  private async disposeInternal(): Promise<void> {
    if (this.scene) {
      try {
        this.scene.destroy();
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'destroy failed: %{public}s', String(err));
      }
    }
    this.scene = null;
    this.camera = null;
    this.currentClip = null;
    this.descriptor = null;
    this.sceneOpt = null;
    this.loadState = 'idle';
  }
}
