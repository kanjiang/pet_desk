import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { KEY_MOOD_BASELINE, KEY_MOOD_CURRENT } from '../../common/utils/AppStorageKeys';
import { MoodBaseline, MoodSnapshot } from './MoodReading';

const TAG: string = 'PetDesk.MoodStateRepo';
const DOMAIN: number = 0xC001;
const STORE_NAME: string = 'petdesk_mood';
const SNAPSHOT_KEY: string = 'current';
const BASELINE_KEY: string = 'baseline';

export class MoodStateRepo {
  private static _instance: MoodStateRepo | undefined;
  private store: preferences.Preferences | null = null;
  private snapshot: MoodSnapshot | undefined = undefined;
  private baseline: MoodBaseline = { sampleCount: 0, updatedAt: 0 };
  private readyPromise: Promise<void> | null = null;

  static instance(): MoodStateRepo {
    if (!MoodStateRepo._instance) {
      MoodStateRepo._instance = new MoodStateRepo();
    }
    return MoodStateRepo._instance;
  }

  init(context: common.Context): Promise<void> {
    if (this.readyPromise) {
      return this.readyPromise;
    }
    this.readyPromise = this.doInit(context);
    return this.readyPromise;
  }

  current(): MoodSnapshot | undefined {
    return this.snapshot;
  }

  currentBaseline(): MoodBaseline {
    return this.baseline;
  }

  save(snapshot: MoodSnapshot): void {
    this.snapshot = snapshot;
    AppStorage.setOrCreate<MoodSnapshot | undefined>(KEY_MOOD_CURRENT, snapshot);
    this.persist(SNAPSHOT_KEY, snapshot);
  }

  saveBaseline(baseline: MoodBaseline): void {
    this.baseline = baseline;
    AppStorage.setOrCreate<MoodBaseline>(KEY_MOOD_BASELINE, baseline);
    this.persist(BASELINE_KEY, baseline);
  }

  private async doInit(context: common.Context): Promise<void> {
    this.store = await preferences.getPreferences(context, { name: STORE_NAME });
    this.snapshot = this.readJson<MoodSnapshot>(SNAPSHOT_KEY);
    this.baseline = this.readJson<MoodBaseline>(BASELINE_KEY) ?? { sampleCount: 0, updatedAt: 0 };
    AppStorage.setOrCreate<MoodSnapshot | undefined>(KEY_MOOD_CURRENT, this.snapshot);
    AppStorage.setOrCreate<MoodBaseline>(KEY_MOOD_BASELINE, this.baseline);
    hilog.info(DOMAIN, TAG, 'init done');
  }

  private readJson<T>(key: string): T | undefined {
    if (!this.store) {
      return undefined;
    }

    const raw: string = this.store.getSync(key, '') as string;
    if (raw.length === 0) {
      return undefined;
    }

    try {
      return JSON.parse(raw) as T;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'parse failed: %{public}s', String(err));
      return undefined;
    }
  }

  private persist(key: string, value: object): void {
    if (!this.store) {
      return;
    }

    this.store.putSync(key, JSON.stringify(value));
    this.store.flush().catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', err.message);
    });
  }
}
