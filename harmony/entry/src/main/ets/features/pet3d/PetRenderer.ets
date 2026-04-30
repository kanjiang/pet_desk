/**
 * PetRenderer - 把 PetSnapshot + SkinProfile 渲染为 3D 宠物.
 *
 * 内部分三层渲染:
 *   1. Component3D 渲染真实 glTF (来自 PetSceneController)
 *   2. 失败/加载中时回退到 emoji 占位 (没 .glb 资源也能跑)
 *   3. 顶部叠一个心情底色光晕 + 底部宠物名字
 *
 * 数据流单向:
 *   父组件 -> @Prop(snap, skin) -> @Watch 触发 -> 控制器 applySkin/playAction
 *   控制器 -> sceneOpt -> Component3D 渲染
 */

import { Component3D } from '@kit.ArkGraphics3D';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { PetAction, PetMood, PetSnapshot } from '../../common/models/PetState';
import { SkinProfile } from '../../common/models/SkinProfile';
import { LoadState, PetSceneController } from './PetSceneController';

const TAG: string = 'PetDesk.PetRenderer';
const DOMAIN: number = 0xC001;

function actionEmoji(action: PetAction): string {
  switch (action) {
    case PetAction.IDLE: return '🐾';
    case PetAction.WALK: return '🚶';
    case PetAction.SIT: return '🪑';
    case PetAction.SLEEP: return '💤';
    case PetAction.EAT: return '🍖';
    case PetAction.PLAY_BALL: return '🎾';
    case PetAction.PLAY_TOY: return '🪶';
    case PetAction.SCRATCH: return '🪵';
    case PetAction.HAPPY_JUMP: return '✨';
    case PetAction.STRETCH: return '🧘';
    case PetAction.SUNBATHE: return '🌞';
    case PetAction.COMFORT: return '🤗';
    default: return '🐾';
  }
}

function moodTint(mood: PetMood): string {
  switch (mood) {
    case PetMood.HAPPY: return '#FFE3A1';
    case PetMood.CALM: return '#E8F0FF';
    case PetMood.SLEEPY: return '#D6D2EA';
    case PetMood.HUNGRY: return '#FFD1B3';
    case PetMood.PLAYFUL: return '#C8F2D2';
    case PetMood.CONCERNED: return '#F4C7C3';
    default: return '#FFFFFF';
  }
}

@Component
export struct PetRenderer {
  @Prop @Watch('onSnapChanged') snap: PetSnapshot;
  @Prop @Watch('onSkinChanged') skin: SkinProfile;

  @State private loadState: LoadState = 'idle';
  @State private errorMessage: string = '';
  @State private sceneReady: boolean = false;

  private controller: PetSceneController = new PetSceneController();
  private lastModelId: string = '';
  private lastAction: PetAction = PetAction.IDLE;
  private lastPrimary: string = '';
  private mounted: boolean = false;
  private modelRequestSeq: number = 0;

  aboutToAppear(): void {
    this.mounted = true;
    this.syncFromProps();
  }

  aboutToDisappear(): void {
    this.mounted = false;
    this.modelRequestSeq += 1;
    this.controller.dispose();
  }

  onSnapChanged(_: string): void {
    this.syncFromProps();
  }

  onSkinChanged(_: string): void {
    this.syncFromProps();
  }

  /**
   * 把 props 当前值下推到控制器. 用 lastXxx 做幂等:
   * 相同值不重复触发昂贵的 model 加载 / 材质替换.
   */
  private syncFromProps(): void {
    if (this.skin.baseModelId !== this.lastModelId) {
      const requestSeq: number = ++this.modelRequestSeq;
      this.lastModelId = this.skin.baseModelId;
      this.lastPrimary = this.skin.palette.primary;
      this.sceneReady = false;
      this.loadState = 'loading';
      this.errorMessage = '';
      this.controller.ensureModel(this.skin)
        .then(() => {
          if (!this.mounted || requestSeq !== this.modelRequestSeq) {
            return;
          }
          this.loadState = this.controller.state();
          this.errorMessage = this.controller.errorMessage();
          this.sceneReady = this.loadState === 'ready';
          if (this.sceneReady) {
            this.controller.playAction(this.snap.action);
            this.lastAction = this.snap.action;
          }
        })
        .catch((err: Error) => {
          hilog.error(DOMAIN, TAG, 'ensureModel rejected: %{public}s', err.message);
        });
      return;
    }
    if (this.skin.palette.primary !== this.lastPrimary) {
      this.lastPrimary = this.skin.palette.primary;
      this.controller.applySkin(this.skin);
    }
    if (this.snap.action !== this.lastAction) {
      this.lastAction = this.snap.action;
      this.controller.playAction(this.snap.action);
    }
  }

  build() {
    Stack() {
      Circle({ width: 280, height: 280 })
        .fill(moodTint(this.snap.mood))
        .opacity(0.5);

      if (this.sceneReady && this.controller.sceneOpt !== null) {
        Component3D({ scene: this.controller.sceneOpt })
          .width(260)
          .height(260);
      } else {
        this.fallbackVisual();
      }

      Text(this.skin.petName)
        .fontSize(14)
        .fontColor('#666')
        .position({ x: 0, y: 250 });
    }
    .width(300)
    .height(300)
    .alignContent(Alignment.Center);
  }

  @Builder
  fallbackVisual() {
    Stack() {
      Circle({ width: 180, height: 180 })
        .fill(this.skin.palette.primary);
      Column() {
        Text(actionEmoji(this.snap.action))
          .fontSize(96);
        if (this.loadState === 'loading') {
          Text('加载 3D 模型...')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .opacity(0.85);
        } else if (this.loadState === 'error') {
          Text('未找到模型, 显示占位')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .opacity(0.75);
        }
      }
      .alignItems(HorizontalAlign.Center);
    }
    .width(200)
    .height(200);
  }
}
