import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility as BaseFormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { PetSurfaceSnapshot } from '../common/models/PetSurfaceSnapshot';
import { PetFormRegistry } from '../common/services/PetFormRegistry';
import { currentQuickActionFeedback, handleQuickActionWithFeedback } from '../common/services/PetQuickActionService';
import {
  readCurrentSurfaceSnapshot,
  syncCurrentSurfaceSnapshot,
} from '../common/services/PetSurfacePublisher';
import { bootstrapPersistence } from '../common/services/PersistenceBootstrap';
import { KEY_DEFAULT_PET_ID } from '../common/utils/AppStorageKeys';
import { PetEngine } from '../features/pet3d/PetEngine';
import { toPetCardFormData } from '../features/form/PetCardFormData';
import { ScheduleRepo } from '../features/scheduler/ScheduleRepo';
import { SkinRepo } from '../features/storage/SkinRepo';

const TAG: string = 'PetDesk.FormExtensionAbility';
const DOMAIN: number = 0xC001;

export default class FormExtensionAbility extends BaseFormExtensionAbility {
  private activeFormIds: Set<string> = new Set();
  private feedbackResetTimer: number = -1;
  private unsubscribePet: (() => void) | undefined = undefined;
  private unsubscribeSchedule: (() => void) | undefined = undefined;
  private unsubscribeSkin: (() => void) | undefined = undefined;
  private sharedStateWatchersStarted: boolean = false;

  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'onCreate %{public}s', want.abilityName ?? 'FormExtensionAbility');
    bootstrapPersistence(this.context)
      .then(() => {
        this.refreshAllForms();
      })
      .catch((err: Error) => {
        hilog.warn(DOMAIN, TAG, 'bootstrapPersistence failed: %{public}s', err.message);
        this.refreshAllForms();
      });
  }

  onAddForm(want: Want): formBindingData.FormBindingData {
    this.registerFormId(formIdFromWant(want));
    this.startSharedStateWatchers();
    return this.createBindingData(readCurrentSurfaceSnapshot());
  }

  onUpdateForm(formId: string): void {
    this.registerFormId(formId);
    this.startSharedStateWatchers();
    this.refreshAllForms();
  }

  onFormEvent(formId: string, message: string): void {
    this.registerFormId(formId);
    this.startSharedStateWatchers();
    const action: string | null = parseFormAction(message);
    if (action !== null) {
      const result = handleQuickActionWithFeedback(action);
      if (result.handled && typeof result.expiresAt === 'number') {
        this.scheduleFeedbackReset(result.expiresAt);
      }
    }
    this.refreshAllForms();
  }

  onRemoveForm(formId: string): void {
    this.activeFormIds.delete(formId);
    PetFormRegistry.instance().unregister(formId);
    if (this.allKnownFormIds().length === 0) {
      this.stopSharedStateWatchers();
      this.clearFeedbackResetTimer();
    }
  }

  private startSharedStateWatchers(): void {
    if (this.sharedStateWatchersStarted) {
      return;
    }
    this.sharedStateWatchersStarted = true;

    this.unsubscribePet = PetEngine.instance().subscribe(() => {
      this.refreshAllForms();
    });
    this.unsubscribeSkin = SkinRepo.instance().subscribe((profile) => {
      if (profile.petId === KEY_DEFAULT_PET_ID) {
        this.refreshAllForms();
      }
    });
    this.unsubscribeSchedule = ScheduleRepo.instance().subscribe(() => {
      this.refreshAllForms();
    });
  }

  private stopSharedStateWatchers(): void {
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
    this.sharedStateWatchersStarted = false;
  }

  private registerFormId(formId: string | null): void {
    if (formId === null || formId.length === 0) {
      return;
    }
    this.activeFormIds.add(formId);
    PetFormRegistry.instance().register(formId);
  }

  private refreshAllForms(): void {
    const formIds: string[] = this.allKnownFormIds();
    if (formIds.length === 0) {
      this.stopSharedStateWatchers();
      this.clearFeedbackResetTimer();
      syncCurrentSurfaceSnapshot();
      return;
    }

    const snapshot = syncCurrentSurfaceSnapshot();
    formIds.forEach((formId) => {
      formProvider.updateForm(formId, this.createBindingData(snapshot))
        .catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'updateForm failed for %{public}s: %{public}s', formId, err.message);
        });
    });
  }

  private createBindingData(snapshot: PetSurfaceSnapshot): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(
      toPetCardFormData(snapshot, currentQuickActionFeedback()),
    );
  }

  private scheduleFeedbackReset(expiresAt: number): void {
    this.clearFeedbackResetTimer();

    const delayMs: number = Math.max(expiresAt - Date.now(), 0);
    this.feedbackResetTimer = setTimeout(() => {
      this.feedbackResetTimer = -1;
      this.refreshAllForms();
    }, delayMs);
  }

  private clearFeedbackResetTimer(): void {
    if (this.feedbackResetTimer === -1) {
      return;
    }
    clearTimeout(this.feedbackResetTimer);
    this.feedbackResetTimer = -1;
  }

  private allKnownFormIds(): string[] {
    const merged: Set<string> = new Set(this.activeFormIds);
    PetFormRegistry.instance().currentIds().forEach((formId) => {
      merged.add(formId);
    });
    return Array.from(merged.values());
  }
}

function parseFormAction(message: string): string | null {
  if (message.length === 0) {
    return null;
  }

  try {
    const parsed: Record<string, unknown> = JSON.parse(message) as Record<string, unknown>;
    if (typeof parsed.action === 'string' && parsed.action.length > 0) {
      return parsed.action;
    }
  } catch (_err) {
    // Some hosts pass raw strings instead of serialized JSON params.
  }

  return message;
}

function formIdFromWant(want: Want): string | null {
  const formId: unknown = want.parameters?.[formInfo.FormParam.IDENTITY_KEY];
  if (typeof formId === 'string' || typeof formId === 'number') {
    return String(formId);
  }
  return null;
}
