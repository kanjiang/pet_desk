# Health And Mood Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect real Huawei Watch health data to a foreground-refresh Mood Engine that can infer lightweight user state, persist the result, and trigger pet comfort behavior inside the app.

**Architecture:** Add a small `features/mood/` slice with five focused units: `MoodReading` for shared types, `MoodInferrer` for pure rules, `MoodStateRepo` for persistence + AppStorage publish, `HealthProvider` for Harmony health data access, and `MoodEngineService` for orchestration. Wire the service into `EntryAbility` startup / foreground flow and surface the latest result in `PetHome` as a thin debug/status panel.

**Tech Stack:** ArkTS, ArkUI Stage model, HarmonyOS `@kit.HealthServiceKit`, optional single-shot fallback from `@kit.SensorServiceKit`, Preferences-backed repo pattern, AppStorage, existing `PetEngine`, existing `EntryAbility`, Hypium tests for pure logic and orchestration with fakes, manual device verification for Health Kit authorization and real watch data.

---

## Scope Check

This plan is intentionally limited to the first vertical slice already approved in `docs/DESIGN-MOOD.md`:

1. Huawei Watch only
2. Real health data first
3. Foreground refresh only
4. `stressed` / `low` trigger comfort behavior
5. `PetHome` shows latest mood status

This plan does **not** include:

- always-on background monitoring
- high-frequency heart-rate streaming
- LiveView or service-card mood surfaces
- cross-device sync
- medical interpretation

## Preconditions

Before Task 4 manual verification, make sure these non-code prerequisites are satisfied on the target device/project:

- The app has been registered in AppGallery Connect.
- Health Service Kit entitlement has been applied for and enabled.
- The module has valid AGC / Health capability configuration required by the installed Harmony SDK.
- The test device is logged in with a HUAWEI ID and paired to a supported Huawei Watch.
- The Huawei Health app privacy policy has been accepted on device if the platform requires it.

If any prerequisite is missing, complete Tasks 1-3 and 5-7 first, then stop Task 4 at the “real-device blocked by capability setup” checkpoint instead of faking success.

## File Structure

### New files

- Create: `harmony/entry/src/main/ets/features/mood/MoodReading.ets`
  - Shared types for health input, baseline, and persisted mood snapshot
- Create: `harmony/entry/src/main/ets/features/mood/MoodInferrer.ets`
  - Pure inference rules from `HealthReading` + `MoodBaseline`
- Create: `harmony/entry/src/main/ets/features/mood/MoodStateRepo.ets`
  - Preferences-backed current mood state + AppStorage publish
- Create: `harmony/entry/src/main/ets/features/mood/HealthProvider.ets`
  - Harmony health adapter boundary and normalization helpers
- Create: `harmony/entry/src/main/ets/features/mood/MoodEngineService.ets`
  - Orchestrates refresh, throttling, repo update, and `PetEngine` dispatch
- Create: `harmony/entry/src/ohosTest/ets/test/MoodInferrer.test.ets`
  - Pure rule tests
- Create: `harmony/entry/src/ohosTest/ets/test/MoodEngineService.test.ets`
  - Orchestration tests using fake provider / fake repo

### Files to modify

- Modify: `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`
  - Add mood-state keys beyond the existing `KEY_MOOD_CURRENT`
- Modify: `harmony/entry/src/main/ets/common/services/PersistenceBootstrap.ets`
  - Initialize `MoodStateRepo`
- Modify: `harmony/entry/src/main/ets/entryability/EntryAbility.ets`
  - Trigger mood refresh on startup and foreground
- Modify: `harmony/entry/src/main/ets/pages/PetHome.ets`
  - Display latest mood result and refresh time
- Modify: `harmony/entry/src/main/resources/base/element/string.json`
  - Add minimal user-facing mood / health strings if needed
- Modify: `docs/ARCHITECTURE.md`
  - Record the shipped mood path after implementation
- Modify: `docs/ROADMAP.md`
  - Mark M3 Health + Mood progress after implementation

### Responsibility boundaries

- `MoodReading.ets` contains types only
- `MoodInferrer.ets` contains pure business rules only
- `MoodStateRepo.ets` persists and publishes, but does not call `PetEngine`
- `HealthProvider.ets` talks to Harmony kits, but does not infer mood
- `MoodEngineService.ets` coordinates everything and is the only file that dispatches `mood_signal`

## Task 1: Add Mood Models And AppStorage Keys

**Files:**
- Create: `harmony/entry/src/main/ets/features/mood/MoodReading.ets`
- Modify: `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`
- Test: `harmony/entry/src/ohosTest/ets/test/MoodInferrer.test.ets`

- [ ] **Step 1: Write the failing test scaffold**

Create `harmony/entry/src/ohosTest/ets/test/MoodInferrer.test.ets`:

```ts
import { describe, it, expect } from '@ohos/hypium';
import { inferMood } from '../../../main/ets/features/mood/MoodInferrer';
import { HealthReading, MoodBaseline } from '../../../main/ets/features/mood/MoodReading';

describe('MoodInferrer', () => {
  it('falls back to normal when baseline is still cold-start and reading is mild', 0, () => {
    const reading: HealthReading = {
      collectedAt: 1,
      heartRate: 78,
      stress: 32,
      source: 'health_kit',
    };
    const baseline: MoodBaseline = {
      sampleCount: 0,
      updatedAt: 0,
    };

    const snapshot = inferMood(reading, baseline);
    expect(snapshot.level).assertEqual('normal');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `MoodInferrer` and `MoodReading` do not exist yet

- [ ] **Step 3: Write minimal models and keys**

Create `harmony/entry/src/main/ets/features/mood/MoodReading.ets`:

```ts
export type MoodLevel = 'relaxed' | 'normal' | 'stressed' | 'low';

export interface HealthReading {
  collectedAt: number;
  heartRate?: number;
  hrv?: number;
  stress?: number;
  sleepScore?: number;
  source: 'health_kit';
}

export interface MoodBaseline {
  restingHeartRate?: number;
  hrvMedian?: number;
  stressMedian?: number;
  sampleCount: number;
  updatedAt: number;
}

export interface MoodSnapshot {
  level: MoodLevel;
  reason: string;
  updatedAt: number;
  lastTriggeredAt?: number;
  mutedUntil?: number;
  latestReading?: HealthReading;
}
```

Modify `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`:

```ts
export const KEY_MOOD_CURRENT: string = 'mood:current';
export const KEY_MOOD_BASELINE: string = 'mood:baseline';
```

- [ ] **Step 4: Re-run test to verify the failure moved forward**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `inferMood(...)` is still missing, proving the type contract is now in place

- [ ] **Step 5: Checkpoint**

Verify:

- `MoodReading.ets` exists with the exact three exported model types
- `AppStorageKeys.ets` contains both mood keys and no duplicate definitions
- No commit unless the user explicitly asks for one

## Task 2: Implement `MoodInferrer`

**Files:**
- Create: `harmony/entry/src/main/ets/features/mood/MoodInferrer.ets`
- Test: `harmony/entry/src/ohosTest/ets/test/MoodInferrer.test.ets`

- [ ] **Step 1: Extend the failing tests with concrete rule cases**

Update `harmony/entry/src/ohosTest/ets/test/MoodInferrer.test.ets`:

```ts
it('infers stressed when heart rate is clearly above baseline and stress is high', 0, () => {
  const reading: HealthReading = {
    collectedAt: 1,
    heartRate: 108,
    stress: 82,
    source: 'health_kit',
  };
  const baseline: MoodBaseline = {
    restingHeartRate: 70,
    stressMedian: 30,
    sampleCount: 10,
    updatedAt: 1,
  };

  const snapshot = inferMood(reading, baseline);
  expect(snapshot.level).assertEqual('stressed');
});

it('infers low when hrv is below baseline and sleep score is poor', 0, () => {
  const reading: HealthReading = {
    collectedAt: 1,
    hrv: 24,
    sleepScore: 42,
    source: 'health_kit',
  };
  const baseline: MoodBaseline = {
    hrvMedian: 48,
    sampleCount: 12,
    updatedAt: 1,
  };

  const snapshot = inferMood(reading, baseline);
  expect(snapshot.level).assertEqual('low');
});

it('infers relaxed when hrv is above baseline and stress is low', 0, () => {
  const reading: HealthReading = {
    collectedAt: 1,
    hrv: 62,
    stress: 18,
    source: 'health_kit',
  };
  const baseline: MoodBaseline = {
    hrvMedian: 48,
    stressMedian: 35,
    sampleCount: 12,
    updatedAt: 1,
  };

  const snapshot = inferMood(reading, baseline);
  expect(snapshot.level).assertEqual('relaxed');
});
```

- [ ] **Step 2: Run tests to confirm rule coverage is red**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `inferMood(...)` is still undefined

- [ ] **Step 3: Implement the minimal pure rule engine**

Create `harmony/entry/src/main/ets/features/mood/MoodInferrer.ets`:

```ts
import { HealthReading, MoodBaseline, MoodSnapshot } from './MoodReading';

const BASELINE_READY_SAMPLES: number = 7;

export function inferMood(reading: HealthReading, baseline: MoodBaseline): MoodSnapshot {
  if (isStressed(reading, baseline)) {
    return {
      level: 'stressed',
      reason: '心率明显偏高且压力较高',
      updatedAt: reading.collectedAt,
      latestReading: reading,
    };
  }

  if (isLow(reading, baseline)) {
    return {
      level: 'low',
      reason: '恢复指标偏低且近期睡眠较弱',
      updatedAt: reading.collectedAt,
      latestReading: reading,
    };
  }

  if (isRelaxed(reading, baseline)) {
    return {
      level: 'relaxed',
      reason: '恢复指标较好且压力较低',
      updatedAt: reading.collectedAt,
      latestReading: reading,
    };
  }

  return {
    level: 'normal',
    reason: baseline.sampleCount < BASELINE_READY_SAMPLES ? '基线样本不足，保持保守判断' : '当前状态平稳',
    updatedAt: reading.collectedAt,
    latestReading: reading,
  };
}

function isStressed(reading: HealthReading, baseline: MoodBaseline): boolean {
  if (reading.heartRate === undefined || reading.stress === undefined) {
    return false;
  }
  const heartRateThreshold: number = baseline.restingHeartRate !== undefined
    ? baseline.restingHeartRate * 1.25
    : 100;
  return reading.heartRate >= heartRateThreshold && reading.stress >= 70;
}

function isLow(reading: HealthReading, baseline: MoodBaseline): boolean {
  if (reading.hrv === undefined || reading.sleepScore === undefined) {
    return false;
  }
  const hrvThreshold: number = baseline.hrvMedian !== undefined ? baseline.hrvMedian * 0.7 : 28;
  return reading.hrv <= hrvThreshold && reading.sleepScore < 60;
}

function isRelaxed(reading: HealthReading, baseline: MoodBaseline): boolean {
  if (reading.hrv === undefined || reading.stress === undefined) {
    return false;
  }
  const hrvThreshold: number = baseline.hrvMedian !== undefined ? baseline.hrvMedian * 1.1 : 55;
  return reading.hrv >= hrvThreshold && reading.stress < 30;
}
```

- [ ] **Step 4: Run tests to verify the inference rules pass**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS for `MoodInferrer.test.ets`

- [ ] **Step 5: Checkpoint**

Verify:

- `MoodInferrer.ets` imports no Harmony kit APIs
- The cold-start fallback still returns `normal`
- `stressed`, `low`, and `relaxed` are covered by tests

## Task 3: Implement `MoodStateRepo`

**Files:**
- Create: `harmony/entry/src/main/ets/features/mood/MoodStateRepo.ets`
- Modify: `harmony/entry/src/main/ets/common/services/PersistenceBootstrap.ets`

- [ ] **Step 1: Write a failing orchestration test that depends on repo state**

Create `harmony/entry/src/ohosTest/ets/test/MoodEngineService.test.ets`:

```ts
import { describe, it, expect } from '@ohos/hypium';
import { MoodEngineService } from '../../../main/ets/features/mood/MoodEngineService';
import { HealthReading, MoodBaseline, MoodSnapshot } from '../../../main/ets/features/mood/MoodReading';

class FakeProvider {
  constructor(private reading: HealthReading | null) {}
  async readLatest(): Promise<HealthReading | null> {
    return this.reading;
  }
}

class FakeRepo {
  public snapshot: MoodSnapshot | undefined;
  public baseline: MoodBaseline = { sampleCount: 0, updatedAt: 0 };

  current(): MoodSnapshot | undefined { return this.snapshot; }
  currentBaseline(): MoodBaseline { return this.baseline; }
  save(snapshot: MoodSnapshot): void { this.snapshot = snapshot; }
}

describe('MoodEngineService', () => {
  it('stores the inferred snapshot after a refresh', 0, async () => {
    const provider = new FakeProvider({
      collectedAt: 1,
      heartRate: 104,
      stress: 80,
      source: 'health_kit',
    });
    const repo = new FakeRepo();
    const service = new MoodEngineService(provider, repo as never);

    await service.refresh();
    expect(repo.snapshot?.level).assertEqual('stressed');
  });
});
```

- [ ] **Step 2: Run tests to confirm downstream pieces are still missing**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `MoodEngineService` does not exist yet

- [ ] **Step 3: Add the repo with publish + persistence behavior**

Create `harmony/entry/src/main/ets/features/mood/MoodStateRepo.ets`:

```ts
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { MoodBaseline, MoodSnapshot } from './MoodReading';
import { KEY_MOOD_BASELINE, KEY_MOOD_CURRENT } from '../../common/utils/AppStorageKeys';

const TAG: string = 'PetDesk.MoodStateRepo';
const DOMAIN: number = 0xC001;
const STORE_NAME: string = 'petdesk_mood';
const SNAPSHOT_KEY: string = 'current';
const BASELINE_KEY: string = 'baseline';

export class MoodStateRepo {
  private static _instance: MoodStateRepo | undefined;
  private store: preferences.Preferences | null = null;
  private snapshot: MoodSnapshot | undefined;
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
    const raw = this.store.getSync(key, '') as string;
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
```

Modify `harmony/entry/src/main/ets/common/services/PersistenceBootstrap.ets`:

```ts
import { MoodStateRepo } from '../../features/mood/MoodStateRepo';

await Promise.all([
  PetFormRegistry.instance().init(context),
  PetQuickActionFeedbackStore.instance().init(context),
  SkinRepo.instance().init(context),
  ScheduleRepo.instance().init(context),
  MoodStateRepo.instance().init(context),
]);
```

- [ ] **Step 4: Run a lightweight sanity pass**

Run:

```bash
cd "/host/workdir/pet_desk" && rg "MoodStateRepo|KEY_MOOD_BASELINE" harmony/entry/src/main
```

Expected:

- `MoodStateRepo` exists
- `PersistenceBootstrap` initializes it
- both mood keys are referenced from code

- [ ] **Step 5: Checkpoint**

Verify:

- `MoodStateRepo` publishes snapshot and baseline to `AppStorage`
- `PersistenceBootstrap` owns repo initialization
- No other file directly touches the mood Preferences store

## Task 4: Implement `HealthProvider` For Real Device Data

**Files:**
- Create: `harmony/entry/src/main/ets/features/mood/HealthProvider.ets`
- Modify: `harmony/entry/src/main/module.json5` only if the installed SDK requires additional Health capability config for AGC / client metadata

- [ ] **Step 1: Add a pure normalization helper test**

Append this test to `harmony/entry/src/ohosTest/ets/test/MoodInferrer.test.ets` or create a small provider test file:

```ts
import { normalizeHealthReading } from '../../../main/ets/features/mood/HealthProvider';

it('normalizes sparse health values into a HealthReading contract', 0, () => {
  const reading = normalizeHealthReading({
    collectedAt: 100,
    heartRate: 88,
    stress: undefined,
    hrv: 41,
    sleepScore: 72,
  });

  expect(reading.collectedAt).assertEqual(100);
  expect(reading.heartRate).assertEqual(88);
  expect(reading.hrv).assertEqual(41);
  expect(reading.source).assertEqual('health_kit');
});
```

- [ ] **Step 2: Run tests to confirm the provider helper is missing**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `normalizeHealthReading` and `HealthProvider` do not exist yet

- [ ] **Step 3: Implement the provider boundary and Harmony adapter**

Create `harmony/entry/src/main/ets/features/mood/HealthProvider.ets`:

```ts
import { hilog } from '@kit.PerformanceAnalysisKit';
import type { common } from '@kit.AbilityKit';
import { HealthReading } from './MoodReading';

const TAG: string = 'PetDesk.HealthProvider';
const DOMAIN: number = 0xC001;

export interface HealthProvider {
  readLatest(context?: common.Context): Promise<HealthReading | null>;
}

export function normalizeHealthReading(input: {
  collectedAt: number;
  heartRate?: number;
  hrv?: number;
  stress?: number;
  sleepScore?: number;
}): HealthReading {
  return {
    collectedAt: input.collectedAt,
    heartRate: input.heartRate,
    hrv: input.hrv,
    stress: input.stress,
    sleepScore: input.sleepScore,
    source: 'health_kit',
  };
}

export class HarmonyHealthProvider implements HealthProvider {
  async readLatest(_context?: common.Context): Promise<HealthReading | null> {
    try {
      const collectedAt: number = Date.now();

      // In this file only, use the installed Harmony SDK docs/autocomplete to map the
      // exact HealthServiceKit calls that return the most recent stable values for:
      // heart rate, HRV, stress, and sleep score. Keep those SDK-specific calls local here.
      const heartRate: number | undefined = undefined;
      const hrv: number | undefined = undefined;
      const stress: number | undefined = undefined;
      const sleepScore: number | undefined = undefined;

      if (heartRate === undefined && hrv === undefined && stress === undefined && sleepScore === undefined) {
        return null;
      }

      return normalizeHealthReading({
        collectedAt,
        heartRate,
        hrv,
        stress,
        sleepScore,
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'readLatest failed: %{public}s', String(err));
      return null;
    }
  }
}
```

If the installed SDK / Health capability setup requires AGC metadata, add it in the same task to `module.json5` and keep the change isolated to that file only.

- [ ] **Step 4: Manual verify the real device prerequisites**

Manual verification:

1. Sync the project in DevEco Studio so the installed Harmony SDK types are available.
2. Open `HealthProvider.ets` and replace the four local `undefined` placeholders with the concrete SDK calls exposed by your installed HealthServiceKit version.
3. Build and run on a device paired with Huawei Watch.
4. Confirm permission and authorization UI can be completed.
5. Add a temporary log line after `readLatest()` and confirm at least one metric is returned.

Expected:

- The app can request Health permissions without crashing.
- `readLatest()` returns at least one real metric on an authorized device.
- If AGC / entitlement setup is missing, stop here and note the blocker instead of fabricating data.

- [ ] **Step 5: Checkpoint**

Verify:

- All Harmony SDK-specific code lives in `HealthProvider.ets`
- The rest of the mood stack still depends only on `HealthReading`
- The repo remains honest about any device/entitlement blocker

## Task 5: Implement `MoodEngineService`

**Files:**
- Create: `harmony/entry/src/main/ets/features/mood/MoodEngineService.ets`
- Test: `harmony/entry/src/ohosTest/ets/test/MoodEngineService.test.ets`
- Modify: `harmony/entry/src/main/ets/features/pet3d/PetEngine.ets` only if a tiny helper is needed for test injection; otherwise leave it unchanged

- [ ] **Step 1: Extend the service test with throttling and dispatch cases**

Update `harmony/entry/src/ohosTest/ets/test/MoodEngineService.test.ets`:

```ts
class FakePetDispatcher {
  public calls: string[] = [];
  dispatch(level: 'low' | 'stressed' | 'relaxed'): void {
    this.calls.push(level);
  }
}

it('dispatches comfort for stressed on the first refresh', 0, async () => {
  const provider = new FakeProvider({
    collectedAt: 1,
    heartRate: 105,
    stress: 80,
    source: 'health_kit',
  });
  const repo = new FakeRepo();
  const pet = new FakePetDispatcher();
  const service = new MoodEngineService(provider as never, repo as never, pet.dispatch.bind(pet));

  await service.refresh();
  expect(pet.calls.length).assertEqual(1);
  expect(pet.calls[0]).assertEqual('stressed');
});

it('throttles repeated stressed triggers inside 30 minutes', 0, async () => {
  const provider = new FakeProvider({
    collectedAt: 1,
    heartRate: 105,
    stress: 80,
    source: 'health_kit',
  });
  const repo = new FakeRepo();
  repo.snapshot = {
    level: 'stressed',
    reason: 'old',
    updatedAt: 1,
    lastTriggeredAt: 1,
  };
  const pet = new FakePetDispatcher();
  const service = new MoodEngineService(provider as never, repo as never, pet.dispatch.bind(pet), () => 10 * 60_000);

  await service.refresh();
  expect(pet.calls.length).assertEqual(0);
});
```

- [ ] **Step 2: Run tests to confirm the service is still missing**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `MoodEngineService` is still undefined

- [ ] **Step 3: Implement refresh orchestration**

Create `harmony/entry/src/main/ets/features/mood/MoodEngineService.ets`:

```ts
import type { common } from '@kit.AbilityKit';
import { PetEngine } from '../pet3d/PetEngine';
import { HealthProvider } from './HealthProvider';
import { inferMood } from './MoodInferrer';
import { MoodLevel, MoodSnapshot } from './MoodReading';
import { MoodStateRepo } from './MoodStateRepo';

const THROTTLE_MS: number = 30 * 60_000;

export class MoodEngineService {
  constructor(
    private readonly provider: HealthProvider,
    private readonly repo: Pick<MoodStateRepo, 'current' | 'currentBaseline' | 'save'>,
    private readonly dispatchMood: (level: 'low' | 'stressed' | 'relaxed') => void = defaultDispatchMood,
    private readonly now: () => number = () => Date.now(),
  ) {}

  async refresh(context?: common.Context): Promise<MoodSnapshot | undefined> {
    const reading = await this.provider.readLatest(context);
    if (!reading) {
      return this.repo.current();
    }

    const next = inferMood(reading, this.repo.currentBaseline());
    const previous = this.repo.current();
    const shouldTrigger = isTriggerLevel(next.level) && canTrigger(previous, next.level, this.now());
    const persisted: MoodSnapshot = {
      ...next,
      lastTriggeredAt: shouldTrigger ? this.now() : previous?.lastTriggeredAt,
    };

    this.repo.save(persisted);

    if (shouldTrigger) {
      this.dispatchMood(next.level);
    }

    return persisted;
  }
}

function defaultDispatchMood(level: 'low' | 'stressed' | 'relaxed'): void {
  if (level === 'low' || level === 'stressed') {
    PetEngine.instance().dispatch({ type: 'mood_signal', level });
  }
}

function isTriggerLevel(level: MoodLevel): level is 'low' | 'stressed' | 'relaxed' {
  return level === 'low' || level === 'stressed' || level === 'relaxed';
}

function canTrigger(previous: MoodSnapshot | undefined, nextLevel: MoodLevel, now: number): boolean {
  if (!previous || previous.level !== nextLevel || previous.lastTriggeredAt === undefined) {
    return nextLevel === 'low' || nextLevel === 'stressed';
  }
  return now - previous.lastTriggeredAt >= THROTTLE_MS && (nextLevel === 'low' || nextLevel === 'stressed');
}
```

- [ ] **Step 4: Run tests to verify orchestration behavior**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS for `MoodEngineService.test.ets`
- `relaxed` and `normal` do not force comfort dispatch

- [ ] **Step 5: Checkpoint**

Verify:

- `MoodEngineService` is the only file that decides whether to dispatch `mood_signal`
- `PetEngine` still only knows about the existing event union
- `relaxed` is persisted but does not trigger comfort behavior

## Task 6: Wire Startup / Foreground Refresh And Add `PetHome` Preview

**Files:**
- Modify: `harmony/entry/src/main/ets/entryability/EntryAbility.ets`
- Modify: `harmony/entry/src/main/ets/pages/PetHome.ets`
- Modify: `harmony/entry/src/main/resources/base/element/string.json`

- [ ] **Step 1: Add a visible UI contract test note**

Record this verification checklist in working notes before editing UI:

```text
[ ] App start does not crash when health data is unavailable
[ ] Returning to foreground re-runs mood refresh
[ ] PetHome shows latest mood level or a safe fallback
[ ] stressed / low still drive comfort behavior
```

- [ ] **Step 2: Create a shared service instance in `EntryAbility`**

Modify `harmony/entry/src/main/ets/entryability/EntryAbility.ets`:

```ts
import { HarmonyHealthProvider } from '../features/mood/HealthProvider';
import { MoodEngineService } from '../features/mood/MoodEngineService';
import { MoodStateRepo } from '../features/mood/MoodStateRepo';

const moodEngine = new MoodEngineService(
  new HarmonyHealthProvider(),
  MoodStateRepo.instance(),
);

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
```

Add a foreground hook:

```ts
onForeground(): void {
  moodEngine.refresh(this.context)
    .catch((err: Error) => {
      hilog.warn(DOMAIN, TAG, 'mood refresh failed: %{public}s', err.message);
    });
}
```

- [ ] **Step 3: Show a thin mood preview on `PetHome`**

Modify `harmony/entry/src/main/ets/pages/PetHome.ets`:

```ts
import { MoodBaseline, MoodSnapshot } from '../features/mood/MoodReading';
import { KEY_MOOD_BASELINE, KEY_MOOD_CURRENT } from '../common/utils/AppStorageKeys';

@StorageLink(KEY_MOOD_CURRENT) mood: MoodSnapshot | undefined = undefined;
@StorageLink(KEY_MOOD_BASELINE) moodBaseline: MoodBaseline = { sampleCount: 0, updatedAt: 0 };
```

Add a small builder below `surfaceDebugStrip()`:

```ts
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
```

Call `this.moodDebugStrip();` after `this.surfaceDebugStrip();`.

If the UI needs a friendlier label, add these strings to `string.json`:

```json
{ "name": "mood_status_title", "value": "心情感知" },
{ "name": "mood_status_empty", "value": "未获取到手表数据" }
```

- [ ] **Step 4: Manual verify the app-level slice**

Manual verification:

1. Start the app on device with watch paired.
2. Grant Health permission if prompted.
3. Observe the `Mood` debug strip on `PetHome`.
4. Put the app to background, then foreground it again.
5. If possible, simulate or wait for a watch state that produces a clearly high-stress or low-energy reading.

Expected:

- App starts even if no data arrives.
- Foregrounding re-runs the refresh path.
- `PetHome` shows either the latest mood or a clear fallback.
- A `stressed` or `low` refresh changes the pet into `COMFORT`.

- [ ] **Step 5: Checkpoint**

Verify:

- The debug strip is readable but lightweight
- `EntryAbility` owns refresh timing, not `PetHome`
- Permission / no-data paths degrade safely

## Task 7: Update Docs After The Vertical Slice Lands

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/DESIGN-MOOD.md`

- [ ] **Step 1: Re-read current docs and list what changed**

Run:

```bash
cd "/host/workdir/pet_desk" && rg "Mood|Health|READ_HEALTH_DATA|手表|Mood Engine" docs
```

Expected:

- Existing mood design doc is present
- Architecture / roadmap still need implementation-state updates

- [ ] **Step 2: Update implementation-state wording**

Add these concrete updates:

```md
## In docs/ARCHITECTURE.md
- Add `MoodStateRepo`, `HealthProvider`, and `MoodEngineService` to the module responsibility section
- State that M3 v1 uses foreground refresh, not background streaming

## In docs/ROADMAP.md
- Mark Health Kit integration as partial or done depending on device validation
- Mark Mood Engine v1 as partial or done depending on orchestration landing

## In docs/DESIGN-MOOD.md
- Change current implementation status from "design approved" to the actual post-implementation state
```

- [ ] **Step 3: Verify the docs are aligned**

Run:

```bash
cd "/host/workdir/pet_desk" && rg "MoodStateRepo|HealthProvider|MoodEngineService|foreground refresh" docs
```

Expected:

- The updated terms appear in the intended docs
- Roadmap and architecture match the actual code state

- [ ] **Step 4: Checkpoint**

Verify:

- Docs do not overclaim background monitoring
- Docs distinguish “real watch data foreground slice” from future always-on work
- No commit unless the user explicitly asks

## Self-Review

### 1. Spec coverage

This plan covers:

- real Huawei Watch data as the first-class source
- a unified `HealthReading` contract
- a pure `MoodInferrer`
- persistence + AppStorage publish via `MoodStateRepo`
- orchestration + throttling via `MoodEngineService`
- `EntryAbility` startup / foreground refresh
- `PetHome` verification UI
- documentation updates after implementation

It intentionally defers:

- background streaming
- advanced baseline builders
- ignore-count-based 24h mute logic
- card / LiveView mood surfaces

### 2. Placeholder scan

Checked for:

- `TODO`
- `TBD`
- “implement later”
- “add appropriate error handling”
- “write tests for the above”

No task uses these as placeholders. The only intentionally open point is the exact installed `HealthServiceKit` method names inside `HealthProvider.ets`, and this is isolated to one file with explicit manual verification because that detail depends on the local Harmony SDK and entitlement state rather than the repo itself.

### 3. Type consistency

These names are used consistently throughout the plan:

- `MoodLevel`
- `HealthReading`
- `MoodBaseline`
- `MoodSnapshot`
- `inferMood`
- `MoodStateRepo`
- `HealthProvider`
- `HarmonyHealthProvider`
- `MoodEngineService`

## Notes Before Execution

- If `hvigorw` is still unavailable in this environment, keep running pure file reviews and `ReadLints`, then perform the device-dependent parts in DevEco Studio.
- Keep all SDK-specific health calls isolated inside `HealthProvider.ets`. Do not spread Harmony health API imports into `MoodInferrer`, `MoodStateRepo`, or `PetHome`.
- Preserve existing service-card work. Mood implementation should plug into `PetEngine` without changing the already shipped surface-state contract.

## Execution Handoff

Plan complete and saved to `docs/2026-05-08-health-and-mood-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session with checkpoints

**Which approach?**
