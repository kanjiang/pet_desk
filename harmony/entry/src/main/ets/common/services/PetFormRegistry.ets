import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'PetDesk.PetFormRegistry';
const DOMAIN: number = 0xC001;
const STORE_NAME: string = 'petdesk_forms';
const DISK_KEY: string = 'active_form_ids';

export class PetFormRegistry {
  private static _instance: PetFormRegistry | undefined;
  private cache: Set<string> = new Set();
  private store: preferences.Preferences | null = null;
  private readyPromise: Promise<void> | null = null;

  static instance(): PetFormRegistry {
    if (!PetFormRegistry._instance) {
      PetFormRegistry._instance = new PetFormRegistry();
    }
    return PetFormRegistry._instance;
  }

  init(context: common.Context): Promise<void> {
    if (this.readyPromise) {
      return this.readyPromise;
    }
    this.readyPromise = this.doInit(context);
    return this.readyPromise;
  }

  currentIds(): string[] {
    return Array.from(this.cache.values());
  }

  register(formId: string): void {
    if (formId.length === 0) {
      return;
    }
    this.cache.add(formId);
    this.persist();
  }

  unregister(formId: string): void {
    if (formId.length === 0) {
      return;
    }
    this.cache.delete(formId);
    this.persist();
  }

  private async doInit(context: common.Context): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      await this.hydrate();
      this.persist();
      hilog.info(DOMAIN, TAG, 'init done with %{public}d form(s)', this.cache.size);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'init failed, using memory cache: %{public}s', String(err));
    }
  }

  private async hydrate(): Promise<void> {
    if (!this.store) {
      return;
    }

    const raw: string = await this.store.get(DISK_KEY, '') as string;
    if (raw.length === 0) {
      return;
    }

    try {
      const parsed: unknown = JSON.parse(raw);
      if (!Array.isArray(parsed)) {
        return;
      }

      for (const formId of parsed) {
        if (typeof formId === 'string' && formId.length > 0) {
          this.cache.add(formId);
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'hydrate failed: %{public}s', String(err));
    }
  }

  private persist(): void {
    if (!this.store) {
      return;
    }

    try {
      this.store.putSync(DISK_KEY, JSON.stringify(this.currentIds()));
      this.store.flush()
        .catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', err.message);
        });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'persist failed: %{public}s', String(err));
    }
  }
}
