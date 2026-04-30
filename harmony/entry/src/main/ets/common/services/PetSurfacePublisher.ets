import { formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { PetFormRegistry } from './PetFormRegistry';
import { PetSurfaceSnapshot } from '../models/PetSurfaceSnapshot';
import { DEFAULT_SNAPSHOT } from '../models/PetState';
import { defaultSkinProfile } from '../models/SkinProfile';
import { currentQuickActionFeedback } from './PetQuickActionService';
import { buildSurfaceSnapshot } from './PetSurfaceService';
import { KEY_DEFAULT_PET_ID, KEY_SURFACE_DEFAULT } from '../utils/AppStorageKeys';
import { PetEngine } from '../../features/pet3d/PetEngine';
import { toPetCardFormData } from '../../features/form/PetCardFormData';
import { DailySchedule } from '../../features/scheduler/ScheduleRule';
import { ScheduleRepo } from '../../features/scheduler/ScheduleRepo';
import { SkinRepo } from '../../features/storage/SkinRepo';

const TAG: string = 'PetDesk.PetSurfacePublisher';
const DOMAIN: number = 0xC001;
const REFRESH_MS: number = 30_000;
const EMPTY_SCHEDULE: DailySchedule = {
  rules: [],
  createdAt: 0,
  updatedAt: 0,
};

export const DEFAULT_SURFACE_SNAPSHOT: PetSurfaceSnapshot = buildSurfaceSnapshot({
  pet: DEFAULT_SNAPSHOT,
  skin: defaultSkinProfile(KEY_DEFAULT_PET_ID, '我家宝贝'),
  schedule: EMPTY_SCHEDULE,
});

export function readCurrentSurfaceSnapshot(): PetSurfaceSnapshot {
  const stored: PetSurfaceSnapshot | undefined = AppStorage.get<PetSurfaceSnapshot>(KEY_SURFACE_DEFAULT);
  return stored ?? buildCurrentSurfaceSnapshot();
}

export function syncCurrentSurfaceSnapshot(): PetSurfaceSnapshot {
  const snapshot: PetSurfaceSnapshot = buildCurrentSurfaceSnapshot();
  AppStorage.setOrCreate<PetSurfaceSnapshot>(KEY_SURFACE_DEFAULT, snapshot);
  return snapshot;
}

export class PetSurfacePublisher {
  private static _instance: PetSurfacePublisher | undefined;
  private unsubscribePet: (() => void) | undefined;
  private unsubscribeSkin: (() => void) | undefined;
  private unsubscribeSchedule: (() => void) | undefined;
  private refreshTimer: number = -1;

  static instance(): PetSurfacePublisher {
    if (!PetSurfacePublisher._instance) {
      PetSurfacePublisher._instance = new PetSurfacePublisher();
    }
    return PetSurfacePublisher._instance;
  }

  start(intervalMs: number = REFRESH_MS): void {
    if (this.unsubscribePet) {
      return;
    }

    this.unsubscribePet = PetEngine.instance().subscribe(() => this.publish());
    this.unsubscribeSkin = SkinRepo.instance().subscribe((profile) => {
      if (profile.petId === KEY_DEFAULT_PET_ID) {
        this.publish();
      }
    });
    this.unsubscribeSchedule = ScheduleRepo.instance().subscribe(() => this.publish());
    this.publish();
    this.refreshTimer = setInterval(() => this.publish(), intervalMs);
    hilog.info(DOMAIN, TAG, 'started');
  }

  stop(): void {
    if (this.unsubscribePet) {
      this.unsubscribePet();
      this.unsubscribePet = undefined;
    }
    if (this.unsubscribeSkin) {
      this.unsubscribeSkin();
      this.unsubscribeSkin = undefined;
    }
    if (this.unsubscribeSchedule) {
      this.unsubscribeSchedule();
      this.unsubscribeSchedule = undefined;
    }
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
    hilog.info(DOMAIN, TAG, 'stopped');
  }

  private publish(): void {
    const snapshot: PetSurfaceSnapshot = syncCurrentSurfaceSnapshot();
    this.publishForms(snapshot);
  }

  private publishForms(snapshot: PetSurfaceSnapshot): void {
    const formIds: string[] = PetFormRegistry.instance().currentIds();
    if (formIds.length === 0) {
      return;
    }

    const bindingData: formBindingData.FormBindingData = formBindingData.createFormBindingData(
      toPetCardFormData(snapshot, currentQuickActionFeedback()),
    );
    formIds.forEach((formId) => {
      formProvider.updateForm(formId, bindingData)
        .catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'updateForm failed for %{public}s: %{public}s', formId, err.message);
        });
    });
  }
}

function buildCurrentSurfaceSnapshot(): PetSurfaceSnapshot {
  return buildSurfaceSnapshot({
    pet: PetEngine.instance().current(),
    skin: SkinRepo.instance().get(KEY_DEFAULT_PET_ID),
    schedule: ScheduleRepo.instance().current(),
  });
}
