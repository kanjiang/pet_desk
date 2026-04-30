import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'PetDesk.PetQuickActionFeedbackStore';
const DOMAIN: number = 0xC001;
const STORE_NAME: string = 'petdesk_quick_action_feedback';
const DISK_KEY: string = 'current_feedback';

export interface QuickActionFeedbackState {
  text: string;
  expiresAt: number;
}

export class PetQuickActionFeedbackStore {
  private static _instance: PetQuickActionFeedbackStore | undefined;
  private cache: QuickActionFeedbackState | undefined = undefined;
  private store: preferences.Preferences | null = null;
  private readyPromise: Promise<void> | null = null;

  static instance(): PetQuickActionFeedbackStore {
    if (!PetQuickActionFeedbackStore._instance) {
      PetQuickActionFeedbackStore._instance = new PetQuickActionFeedbackStore();
    }
    return PetQuickActionFeedbackStore._instance;
  }

  init(context: common.Context): Promise<void> {
    if (this.readyPromise) {
      return this.readyPromise;
    }
    this.readyPromise = this.doInit(context);
    return this.readyPromise;
  }

  current(nowMs: number = Date.now()): string | undefined {
    const feedback: QuickActionFeedbackState | undefined = this.currentState(nowMs);
    return feedback?.text;
  }

  set(state: QuickActionFeedbackState): void {
    this.cache = state;
    this.persist(state);
  }

  clear(): void {
    this.cache = undefined;
    this.persist(undefined);
  }

  private async doInit(context: common.Context): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      const persisted: QuickActionFeedbackState | undefined = this.readPersistedState();
      if (this.shouldReplaceCache(persisted)) {
        this.cache = persisted;
      }
      hilog.info(DOMAIN, TAG, 'init done');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'init failed, using memory cache: %{public}s', String(err));
    }
  }

  private currentState(nowMs: number): QuickActionFeedbackState | undefined {
    const persisted: QuickActionFeedbackState | undefined = this.readPersistedState();
    if (this.shouldReplaceCache(persisted)) {
      this.cache = persisted;
    }

    if (this.cache === undefined) {
      return undefined;
    }

    if (this.cache.expiresAt <= nowMs) {
      this.clear();
      return undefined;
    }

    return this.cache;
  }

  private readPersistedState(): QuickActionFeedbackState | undefined {
    if (this.store === null) {
      return undefined;
    }

    try {
      const raw: string = this.store.getSync(DISK_KEY, '') as string;
      return parseFeedbackState(raw);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'read failed: %{public}s', String(err));
      return undefined;
    }
  }

  private shouldReplaceCache(candidate: QuickActionFeedbackState | undefined): boolean {
    if (candidate === undefined) {
      return false;
    }

    if (this.cache === undefined) {
      return true;
    }

    return candidate.expiresAt >= this.cache.expiresAt;
  }

  private persist(state: QuickActionFeedbackState | undefined): void {
    if (this.store === null) {
      return;
    }

    try {
      this.store.putSync(DISK_KEY, serializeFeedbackState(state));
      this.store.flush()
        .catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', err.message);
        });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'persist failed: %{public}s', String(err));
    }
  }
}

function parseFeedbackState(raw: string): QuickActionFeedbackState | undefined {
  if (raw.length === 0) {
    return undefined;
  }

  try {
    const parsed: unknown = JSON.parse(raw);
    if (!isQuickActionFeedbackState(parsed)) {
      return undefined;
    }
    return parsed;
  } catch (_err) {
    return undefined;
  }
}

function isQuickActionFeedbackState(value: unknown): value is QuickActionFeedbackState {
  if (typeof value !== 'object' || value === null) {
    return false;
  }

  const candidate: Record<string, unknown> = value as Record<string, unknown>;
  return typeof candidate.text === 'string' && typeof candidate.expiresAt === 'number';
}

function serializeFeedbackState(state: QuickActionFeedbackState | undefined): string {
  if (state === undefined) {
    return '';
  }

  return JSON.stringify(state);
}
