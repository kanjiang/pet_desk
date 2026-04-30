import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { bootstrapPersistence } from '../common/services/PersistenceBootstrap';
import { PetSurfacePublisher } from '../common/services/PetSurfacePublisher';
import { HarmonyHealthProvider } from '../features/mood/HealthProvider';
import { MoodEngineService } from '../features/mood/MoodEngineService';
import { MoodStateRepo } from '../features/mood/MoodStateRepo';
import { Scheduler } from '../features/scheduler/Scheduler';

const TAG: string = 'PetDesk.EntryAbility';
const DOMAIN: number = 0xC001;
const moodEngine: MoodEngineService = new MoodEngineService(
  new HarmonyHealthProvider(),
  MoodStateRepo.instance(),
);

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
    bootstrapPersistence(this.context)
      .then(() => {
        PetSurfacePublisher.instance().start();
        Scheduler.instance().start();
        return moodEngine.refresh(this.context);
      })
      .catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'bootstrapPersistence failed: %{public}s', err.message);
        PetSurfacePublisher.instance().start();
        Scheduler.instance().start();
      });
  }

  onForeground(): void {
    moodEngine.refresh(this.context)
      .catch((err: Error) => {
        hilog.warn(DOMAIN, TAG, 'mood refresh failed: %{public}s', err.message);
      });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/PetHome', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });
  }

  onDestroy(): void {
    PetSurfacePublisher.instance().stop();
    Scheduler.instance().stop();
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }
}
