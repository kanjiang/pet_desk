/**
 * 主页 - 全屏宠物 + 8 个互动按钮 + 顶部导航 + 作息提示条.
 *
 * 数据流:
 *   - PetEngine 通过 subscribe 推 PetSnapshot
 *   - SkinProfile 通过 AppStorage('skin:default') 推送, 用 @StorageLink 订阅
 *   - DailySchedule 通过 AppStorage('schedule:default') 推送
 *   - Scheduler.start() 启动作息扫描循环
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { PetEngine } from '../features/pet3d/PetEngine';
import { PetRenderer } from '../features/pet3d/PetRenderer';
import { DEFAULT_SNAPSHOT, PetSnapshot } from '../common/models/PetState';
import { PetSurfaceSnapshot } from '../common/models/PetSurfaceSnapshot';
import { defaultSkinProfile, SkinProfile } from '../common/models/SkinProfile';
import { DEFAULT_SURFACE_SNAPSHOT } from '../common/services/PetSurfacePublisher';
import { MoodBaseline, MoodSnapshot } from '../features/mood/MoodReading';
import {
  KEY_DEFAULT_PET_ID,
  KEY_MOOD_BASELINE,
  KEY_MOOD_CURRENT,
  KEY_SURFACE_DEFAULT,
  skinKey,
} from '../common/utils/AppStorageKeys';

const TAG: string = 'PetDesk.PetHome';
const DOMAIN: number = 0xC001;

interface ActionButtonSpec {
  label: Resource;
  emoji: string;
  event: () => void;
}

@Entry
@Component
struct PetHome {
  @State snap: PetSnapshot = DEFAULT_SNAPSHOT;
  @StorageLink(skinKey(KEY_DEFAULT_PET_ID)) skin: SkinProfile =
    defaultSkinProfile(KEY_DEFAULT_PET_ID, '我家宝贝');
  @StorageLink(KEY_MOOD_CURRENT) mood: MoodSnapshot | undefined = undefined;
  @StorageLink(KEY_MOOD_BASELINE) moodBaseline: MoodBaseline = { sampleCount: 0, updatedAt: 0 };
  @StorageLink(KEY_SURFACE_DEFAULT) surfacePreview: PetSurfaceSnapshot = DEFAULT_SURFACE_SNAPSHOT;

  private unsubscribe: (() => void) | undefined;

  aboutToAppear(): void {
    this.unsubscribe = PetEngine.instance().subscribe((s: PetSnapshot) => {
      this.snap = s;
    });
  }

  aboutToDisappear(): void {
    if (this.unsubscribe) {
      this.unsubscribe();
      this.unsubscribe = undefined;
    }
  }

  private goPick(): void {
    try {
      router.pushUrl({ url: 'pages/PhotoPick' });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'router.pushUrl err: %{public}s', String(err));
    }
  }

  private goSettings(): void {
    try {
      router.pushUrl({ url: 'pages/Settings' });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'router.pushUrl err: %{public}s', String(err));
    }
  }

  private actionSpecs(): ActionButtonSpec[] {
    return [
      { label: $r('app.string.btn_pet'), emoji: '✋', event: () => PetEngine.instance().dispatch({ type: 'user_pet' }) },
      { label: $r('app.string.btn_play_ball'), emoji: '🎾', event: () => PetEngine.instance().dispatch({ type: 'user_play_ball' }) },
      { label: $r('app.string.btn_play_toy'), emoji: '🪶', event: () => PetEngine.instance().dispatch({ type: 'user_play_toy' }) },
      { label: $r('app.string.btn_feed_bone'), emoji: '🍖', event: () => PetEngine.instance().dispatch({ type: 'user_feed_bone' }) },
      { label: $r('app.string.btn_scratch'), emoji: '🪵', event: () => PetEngine.instance().dispatch({ type: 'user_scratch' }) },
      { label: $r('app.string.btn_sunbathe'), emoji: '🌞', event: () => PetEngine.instance().dispatch({ type: 'user_sunbathe' }) },
      { label: $r('app.string.btn_stretch'), emoji: '🧘', event: () => PetEngine.instance().dispatch({ type: 'user_stretch' }) },
      { label: $r('app.string.btn_sleep'), emoji: '💤', event: () => PetEngine.instance().dispatch({ type: 'user_send_to_sleep' }) },
    ];
  }

  build() {
    Column() {
      this.topBar();
      this.scheduleHint();
      this.surfaceDebugStrip();
      this.moodDebugStrip();
      Stack() {
        PetRenderer({ snap: this.snap, skin: this.skin });
      }
      .layoutWeight(1)
      .width('100%');

      this.statsBar();
      this.actionGrid();
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF8F0');
  }

  @Builder
  surfaceDebugStrip() {
    Row() {
      Text('Surface预览')
        .fontSize(11)
        .fontColor('#8A5B4A');
      Text(`${this.surfacePreview.displayText} · ${this.surfacePreview.spriteState}`)
        .fontSize(11)
        .fontColor('#2A1F1A')
        .margin({ left: 8 });
      if (this.surfacePreview.nextScheduleText.length > 0) {
        Text(`· ${this.surfacePreview.nextScheduleText}`)
          .fontSize(11)
          .fontColor('#8A5B4A')
          .margin({ left: 8 });
      }
      Blank();
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 8, top: 2 });
  }

  @Builder
  moodDebugStrip() {
    Row() {
      Text('Mood')
        .fontSize(11)
        .fontColor('#8A5B4A');
      Text(this.mood ? `${this.mood.level} · ${this.mood.reason}` : '未获取到手表数据')
        .fontSize(11)
        .fontColor('#2A1F1A')
        .margin({ left: 8 });
      Blank();
      Text(`baseline:${this.moodBaseline.sampleCount}`)
        .fontSize(10)
        .fontColor('#8A5B4A');
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 8 });
  }

  @Builder
  topBar() {
    Row() {
      Text($r('app.string.home_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#2A1F1A')
        .layoutWeight(1);
      Text('换照片')
        .fontSize(13)
        .fontColor('#FF8A5C')
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(12)
        .borderWidth(1)
        .borderColor('#FF8A5C')
        .margin({ right: 8 })
        .onClick(() => this.goPick());
      Text('作息')
        .fontSize(13)
        .fontColor('#2A1F1A')
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(12)
        .borderWidth(1)
        .borderColor('#2A1F1A')
        .onClick(() => this.goSettings());
    }
    .width('100%')
    .padding({ top: 24, bottom: 12, left: 20, right: 20 });
  }

  @Builder
  scheduleHint() {
    if (this.surfacePreview.nextScheduleText.length > 0) {
      Row() {
        Text('下一项: ')
          .fontSize(12)
          .fontColor('#999');
        Text(this.surfacePreview.nextScheduleText)
          .fontSize(12)
          .fontColor('#2A1F1A');
        Blank();
        if (this.snap.lastActionSource === 'schedule') {
          Text('· 自动触发中')
            .fontSize(11)
            .fontColor('#FF8A5C');
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 8 });
    }
  }

  @Builder
  statsBar() {
    Row() {
      Text(`心情: ${this.snap.mood}`).fontSize(12).fontColor('#888');
      Blank();
      Text(`精力: ${this.snap.energy} | 饥饿: ${this.snap.hunger} | 亲密: ${this.snap.affection}`)
        .fontSize(12)
        .fontColor('#888');
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 8 });
  }

  @Builder
  actionGrid() {
    Grid() {
      ForEach(this.actionSpecs(), (spec: ActionButtonSpec) => {
        GridItem() {
          this.actionButton(spec);
        }
      }, (spec: ActionButtonSpec, idx: number) => `${idx}`);
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .columnsGap(10)
    .rowsGap(10)
    .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    .width('100%')
    .height(200);
  }

  @Builder
  actionButton(spec: ActionButtonSpec) {
    Column() {
      Text(spec.emoji).fontSize(24);
      Text(spec.label).fontSize(11).fontColor('#FFFFFF');
    }
    .backgroundColor('#FF8A5C')
    .width('100%')
    .height('100%')
    .borderRadius(14)
    .justifyContent(FlexAlign.Center)
    .onClick(spec.event);
  }
}
