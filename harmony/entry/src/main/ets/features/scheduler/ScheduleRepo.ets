/**
 * DailySchedule 持久化 + AppStorage 广播.
 *
 * 与 SkinRepo 同样的三层结构, 但只有一份全局作息 (M2 单宠物默认).
 * key: 'schedule:default' -> JSON of DailySchedule
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { DailySchedule, defaultSchedule } from './ScheduleRule';
import { KEY_SCHEDULE_DEFAULT } from '../../common/utils/AppStorageKeys';
import { PetAction } from '../../common/models/PetState';

const TAG: string = 'PetDesk.ScheduleRepo';
const DOMAIN: number = 0xC001;
const STORE_NAME: string = 'petdesk_schedule';
const DISK_KEY: string = 'default';
export type ScheduleListener = (schedule: DailySchedule) => void;
const VALID_ACTIONS: PetAction[] = [
  PetAction.IDLE,
  PetAction.WALK,
  PetAction.SIT,
  PetAction.SLEEP,
  PetAction.EAT,
  PetAction.PLAY_BALL,
  PetAction.PLAY_TOY,
  PetAction.SCRATCH,
  PetAction.HAPPY_JUMP,
  PetAction.STRETCH,
  PetAction.SUNBATHE,
  PetAction.COMFORT,
];

function isValidWeekdays(value: unknown): boolean {
  return Array.isArray(value) && value.every((d) => typeof d === 'number' && d >= 0 && d <= 6);
}

function isDailySchedule(value: unknown): value is DailySchedule {
  if (typeof value !== 'object' || value === null) {
    return false;
  }
  const v = value as Record<string, unknown>;
  if (!Array.isArray(v.rules) || typeof v.createdAt !== 'number' || typeof v.updatedAt !== 'number') {
    return false;
  }
  for (const rule of v.rules) {
    if (typeof rule !== 'object' || rule === null) {
      return false;
    }
    const r = rule as Record<string, unknown>;
    if (typeof r.id !== 'string' ||
      typeof r.hour !== 'number' ||
      typeof r.minute !== 'number' ||
      typeof r.action !== 'string' ||
      typeof r.reason !== 'string' ||
      typeof r.enabled !== 'boolean' ||
      !isValidWeekdays(r.weekdays)) {
      return false;
    }
    if (r.hour < 0 || r.hour > 23 || r.minute < 0 || r.minute > 59) {
      return false;
    }
    if (!VALID_ACTIONS.includes(r.action as PetAction)) {
      return false;
    }
  }
  return true;
}

export class ScheduleRepo {
  private static _instance: ScheduleRepo | undefined;
  private cache: DailySchedule = defaultSchedule();
  private listeners: Set<ScheduleListener> = new Set();
  private store: preferences.Preferences | null = null;
  private ready: boolean = false;
  private readyPromise: Promise<void> | null = null;

  static instance(): ScheduleRepo {
    if (!ScheduleRepo._instance) {
      ScheduleRepo._instance = new ScheduleRepo();
    }
    return ScheduleRepo._instance;
  }

  init(context: common.Context): Promise<void> {
    if (this.readyPromise) {
      return this.readyPromise;
    }
    this.readyPromise = this.doInit(context);
    return this.readyPromise;
  }

  whenReady(): Promise<void> {
    return this.readyPromise ?? Promise.resolve();
  }

  isReady(): boolean {
    return this.ready;
  }

  subscribe(listener: ScheduleListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  current(): DailySchedule {
    return this.cache;
  }

  save(schedule: DailySchedule): void {
    const next: DailySchedule = { ...schedule, updatedAt: Date.now() };
    this.cache = next;
    this.publish(next);
    this.persist(next);
  }

  private async doInit(context: common.Context): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      await this.hydrate();
      this.ready = true;
      hilog.info(DOMAIN, TAG, 'init done with %{public}d rules', this.cache.rules.length);
      this.publish(this.cache);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed, using default: %{public}s', String(err));
      this.publish(this.cache);
      this.ready = false;
    }
  }

  private async hydrate(): Promise<void> {
    if (!this.store) return;
    const raw: string = await this.store.get(DISK_KEY, '') as string;
    if (raw.length === 0) {
      return;
    }
    try {
      const parsed: unknown = JSON.parse(raw);
      if (!isDailySchedule(parsed)) {
        hilog.warn(DOMAIN, TAG, 'invalid schedule schema, fallback default');
        return;
      }
      this.cache = parsed;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'parse fail, fallback default: %{public}s', String(err));
    }
  }

  private persist(schedule: DailySchedule): void {
    if (!this.store) return;
    try {
      this.store.putSync(DISK_KEY, JSON.stringify(schedule));
      this.store.flush()
        .catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', err.message);
        });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persist failed: %{public}s', String(err));
    }
  }

  private publish(schedule: DailySchedule): void {
    AppStorage.setOrCreate<DailySchedule>(KEY_SCHEDULE_DEFAULT, schedule);
    this.listeners.forEach((listener) => listener(schedule));
  }
}
