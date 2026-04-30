/**
 * SkinProfile 仓储 - 内存 cache + Preferences 持久化 + AppStorage 状态广播.
 *
 * 三层结构:
 *   1. 内存 cache (Map): O(1) 同步读路径
 *   2. Preferences ('petdesk_skins.xml'): JSON-serialize 后落盘
 *   3. AppStorage ('skin:<petId>'): 给 @StorageLink 用的响应式发布渠道
 *
 * 生命周期:
 *   App 启动 -> EntryAbility.onCreate -> SkinRepo.init(ctx)
 *      -> 异步 getPreferences -> hydrate (把所有已存 pet 读回 cache + AppStorage)
 *      -> 业务可用
 *   业务调 save() -> 写 cache -> publish AppStorage -> putSync + flush()
 *
 * 失败兜底:
 *   - init 失败 -> 仍能在内存中跑, save 时不写盘 (有日志告警)
 *   - hydrate 时单条解析失败 -> 跳过该 pet, 不影响其它
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { BaseModelId, defaultSkinProfile, SkinProfile } from '../../common/models/SkinProfile';
import { skinKey } from '../../common/utils/AppStorageKeys';

const TAG: string = 'PetDesk.SkinRepo';
const DOMAIN: number = 0xC001;
const STORE_NAME: string = 'petdesk_skins';
const INDEX_KEY: string = '__index__';
export type SkinListener = (profile: SkinProfile) => void;
const VALID_MODEL_IDS: BaseModelId[] = [
  'shorthair_cat',
  'longhair_cat',
  'shiba',
  'golden_retriever',
  'border_collie',
  'rabbit_lop',
  'hamster',
];

function isHexColor(v: unknown): boolean {
  return typeof v === 'string' && /^#[0-9A-Fa-f]{6}$/.test(v);
}

function isSkinProfile(value: unknown): value is SkinProfile {
  if (typeof value !== 'object' || value === null) {
    return false;
  }
  const v = value as Record<string, unknown>;
  if (typeof v.petId !== 'string' || typeof v.petName !== 'string' || typeof v.baseModelId !== 'string') {
    return false;
  }
  if (!VALID_MODEL_IDS.includes(v.baseModelId as BaseModelId)) {
    return false;
  }
  if (typeof v.createdAt !== 'number' || typeof v.updatedAt !== 'number') {
    return false;
  }
  const palette = v.palette;
  if (typeof palette !== 'object' || palette === null) {
    return false;
  }
  const p = palette as Record<string, unknown>;
  return isHexColor(p.primary) && isHexColor(p.secondary) && isHexColor(p.nose) && isHexColor(p.eyes);
}

export class SkinRepo {
  private static _instance: SkinRepo | undefined;
  private cache: Map<string, SkinProfile> = new Map();
  private listeners: Set<SkinListener> = new Set();
  private store: preferences.Preferences | null = null;
  private ready: boolean = false;
  private readyPromise: Promise<void> | null = null;

  static instance(): SkinRepo {
    if (!SkinRepo._instance) {
      SkinRepo._instance = new SkinRepo();
    }
    return SkinRepo._instance;
  }

  init(context: common.Context): Promise<void> {
    if (this.readyPromise) {
      return this.readyPromise;
    }
    this.readyPromise = this.doInit(context);
    return this.readyPromise;
  }

  isReady(): boolean {
    return this.ready;
  }

  whenReady(): Promise<void> {
    return this.readyPromise ?? Promise.resolve();
  }

  subscribe(listener: SkinListener): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  get(petId: string): SkinProfile {
    const existing: SkinProfile | undefined = this.cache.get(petId);
    if (existing) {
      return existing;
    }
    const fresh: SkinProfile = defaultSkinProfile(petId, '我家宝贝');
    this.cache.set(petId, fresh);
    this.publish(fresh);
    return fresh;
  }

  save(profile: SkinProfile): void {
    const next: SkinProfile = { ...profile, updatedAt: Date.now() };
    this.cache.set(next.petId, next);
    this.publish(next);
    this.persist(next);
  }

  private async doInit(context: common.Context): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, { name: STORE_NAME });
      await this.hydrate();
      this.ready = true;
      hilog.info(DOMAIN, TAG, 'init done, %{public}d pet(s) hydrated', this.cache.size);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed, will run in-memory only: %{public}s', String(err));
      this.ready = false;
    }
  }

  private async hydrate(): Promise<void> {
    if (!this.store) {
      return;
    }
    const indexRaw: string = await this.store.get(INDEX_KEY, '') as string;
    if (indexRaw.length === 0) {
      return;
    }
    let petIds: string[] = [];
    try {
      petIds = JSON.parse(indexRaw) as string[];
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'index parse failed, reset: %{public}s', String(err));
      return;
    }
    for (const id of petIds) {
      try {
        const raw: string = await this.store.get(this.diskKey(id), '') as string;
        if (raw.length === 0) {
          continue;
        }
        const parsed: unknown = JSON.parse(raw);
        if (!isSkinProfile(parsed)) {
          hilog.warn(DOMAIN, TAG, 'invalid skin profile schema for %{public}s', id);
          continue;
        }
        const profile: SkinProfile = parsed;
        this.cache.set(id, profile);
        this.publish(profile);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'load pet %{public}s failed: %{public}s', id, String(err));
      }
    }
  }

  private persist(profile: SkinProfile): void {
    if (!this.store) {
      hilog.warn(DOMAIN, TAG, 'no store, skip persist for pet %{public}s', profile.petId);
      return;
    }
    try {
      this.store.putSync(this.diskKey(profile.petId), JSON.stringify(profile));
      const ids: string[] = Array.from(this.cache.keys());
      this.store.putSync(INDEX_KEY, JSON.stringify(ids));
      this.store.flush()
        .catch((err: Error) => {
          hilog.warn(DOMAIN, TAG, 'flush failed: %{public}s', err.message);
        });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persist failed: %{public}s', String(err));
    }
  }

  private publish(profile: SkinProfile): void {
    AppStorage.setOrCreate<SkinProfile>(skinKey(profile.petId), profile);
    this.listeners.forEach((listener) => listener(profile));
  }

  private diskKey(petId: string): string {
    return `pet_${petId}`;
  }
}
