# Surface Card And LiveView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shared surface-state layer, ship a working HarmonyOS desktop service card with two quick actions, and leave LiveView integrated on the same model so lock-screen work can follow without re-architecting.

**Architecture:** Add a lightweight `PetSurfaceSnapshot` model and two small services (`PetSurfaceService`, `PetQuickActionService`) above `PetEngine`, `SkinRepo`, and `ScheduleRepo`. The card and LiveView both read this same surface model. Implement the desktop card first, then wire the lock-screen extension on top of the same snapshot and action flow.

**Tech Stack:** ArkTS, ArkUI Stage model, HarmonyOS `FormExtensionAbility`, HarmonyOS `LiveViewExtensionAbility`, AppStorage, Preferences-backed repos, existing `PetEngine` / `Scheduler` / `SkinRepo` / `ScheduleRepo`, Hypium tests for pure logic, manual device verification for system-surface behavior.

---

## Scope Check

This plan intentionally keeps two subsystems in one plan because they share one new state layer and one quick-action routing model. The implementation order still isolates them:

1. Shared surface state
2. Desktop service card
3. Card hardening
4. LiveView integration

If the team decides to defer lock-screen work entirely, Tasks 5 and 6 can be skipped without rewriting earlier tasks.

## File Structure

### New files

- Create: `harmony/entry/src/main/ets/common/models/PetSurfaceSnapshot.ets`
  - Lightweight card/lock-screen model
- Create: `harmony/entry/src/main/ets/common/services/PetSurfaceService.ets`
  - Builds `PetSurfaceSnapshot` from `PetEngine`, `SkinRepo`, and `ScheduleRepo`
- Create: `harmony/entry/src/main/ets/common/services/PetQuickActionService.ets`
  - Validates quick actions and dispatches them back into `PetEngine`
- Create: `harmony/entry/src/main/ets/entryability/FormExtensionAbility.ets`
  - HarmonyOS service card extension ability
- Create: `harmony/entry/src/main/ets/entryability/LiveViewExtensionAbility.ets`
  - HarmonyOS lock-screen extension ability
- Create: `harmony/entry/src/main/ets/features/form/PetCardForm.ets`
  - Card UI and action handlers
- Create: `harmony/entry/src/main/ets/features/liveview/PetLiveView.ets`
  - Lightweight lock-screen display builder
- Create: `harmony/entry/src/ohosTest/ets/test/PetSurfaceService.test.ets`
  - Unit tests for snapshot derivation
- Create: `harmony/entry/src/ohosTest/ets/test/PetQuickActionService.test.ets`
  - Unit tests for quick-action routing

### Files to modify

- Modify: `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`
  - Add surface-state keys
- Modify: `harmony/entry/src/main/ets/features/pet3d/PetEngine.ets`
  - Add a minimal event hook if quick-action feedback needs a distinct source tag
- Modify: `harmony/entry/src/main/ets/pages/PetHome.ets`
  - Add a temporary debug preview for `PetSurfaceSnapshot`
- Modify: `harmony/entry/src/main/module.json5`
  - Register `FormExtensionAbility` and `LiveViewExtensionAbility`
- Modify: `harmony/entry/src/main/resources/base/element/string.json`
  - Add card/lock-screen strings
- Modify: `harmony/entry/src/main/resources/base/profile/main_pages.json`
  - Only if preview/debug route needs a dedicated page
- Modify: `docs/ARCHITECTURE.md`
  - Record the new surface-state layer once implementation lands
- Modify: `docs/ROADMAP.md`
  - Mark M3 progress after card and LiveView milestones complete

### Responsibility boundaries

- `PetSurfaceSnapshot` is a data contract only
- `PetSurfaceService` is read-only derivation logic
- `PetQuickActionService` is write-path logic for surface-originated actions
- `PetCardForm` must not read `PetHome` state
- `PetLiveView` must not duplicate card logic; it reads the same snapshot but chooses a lighter presentation

## Task 1: Add The Shared Surface-State Model

**Files:**
- Create: `harmony/entry/src/main/ets/common/models/PetSurfaceSnapshot.ets`
- Modify: `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`
- Test: `harmony/entry/src/ohosTest/ets/test/PetSurfaceService.test.ets`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, it, expect } from '@ohos/hypium';
import { PetAction, PetMood } from '../../../main/ets/common/models/PetState';
import { defaultSkinProfile } from '../../../main/ets/common/models/SkinProfile';
import { defaultSchedule } from '../../../main/ets/features/scheduler/ScheduleRule';
import { buildSurfaceSnapshot } from '../../../main/ets/common/services/PetSurfaceService';

describe('PetSurfaceSnapshot', () => {
  it('builds a lightweight snapshot from core state', 0, () => {
    const snapshot = buildSurfaceSnapshot({
      pet: {
        petId: 'default',
        action: PetAction.PLAY_BALL,
        mood: PetMood.PLAYFUL,
        energy: 72,
        hunger: 28,
        affection: 55,
        lastInteractionAt: 1,
        lastActionSource: 'user',
        updatedAt: 2,
      },
      skin: defaultSkinProfile('default', '小橘'),
      schedule: defaultSchedule(),
      now: new Date('2026-05-06T08:30:00'),
    });

    expect(snapshot.petName).assertEqual('小橘');
    expect(snapshot.currentAction).assertEqual(PetAction.PLAY_BALL);
    expect(snapshot.quickActions.length).assertEqual(2);
    expect(snapshot.nextScheduleText.length > 0).assertTrue();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `PetSurfaceService` and `PetSurfaceSnapshot` do not exist yet

- [ ] **Step 3: Write minimal implementation**

Create `harmony/entry/src/main/ets/common/models/PetSurfaceSnapshot.ets`:

```ts
import { PetAction, PetMood } from './PetState';

export interface QuickActionDescriptor {
  id: 'feed' | 'play';
  label: string;
  icon: string;
  enabled: boolean;
}

export interface PetSurfaceSnapshot {
  petName: string;
  petMood: PetMood;
  currentAction: PetAction;
  displayText: string;
  nextScheduleText: string;
  spriteState: string;
  quickActions: QuickActionDescriptor[];
  updatedAt: number;
}
```

Modify `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`:

```ts
export const KEY_SURFACE_DEFAULT: string = 'surface:default';
export const KEY_LIVEVIEW_DEFAULT: string = 'liveview:default';
```
 
- [ ] **Step 4: Run test to verify it still fails for the right reason**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `buildSurfaceSnapshot(...)` is not implemented yet, proving the model alone is not enough

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add harmony/entry/src/main/ets/common/models/PetSurfaceSnapshot.ets harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets harmony/entry/src/ohosTest/ets/test/PetSurfaceService.test.ets && git commit -m "feat(surface): add pet surface snapshot model"
```

## Task 2: Implement `PetSurfaceService`

**Files:**
- Create: `harmony/entry/src/main/ets/common/services/PetSurfaceService.ets`
- Test: `harmony/entry/src/ohosTest/ets/test/PetSurfaceService.test.ets`

- [ ] **Step 1: Extend the failing test with exact expectations**

Update `harmony/entry/src/ohosTest/ets/test/PetSurfaceService.test.ets`:

```ts
it('maps play state to playful sprite and text', 0, () => {
  const snapshot = buildSurfaceSnapshot({
    pet: {
      petId: 'default',
      action: PetAction.PLAY_BALL,
      mood: PetMood.PLAYFUL,
      energy: 72,
      hunger: 28,
      affection: 55,
      lastInteractionAt: 1,
      lastActionSource: 'user',
      updatedAt: 2,
    },
    skin: defaultSkinProfile('default', '小橘'),
    schedule: defaultSchedule(),
    now: new Date('2026-05-06T08:30:00'),
  });

  expect(snapshot.spriteState).assertEqual('playful');
  expect(snapshot.displayText).assertEqual('正在玩球');
  expect(snapshot.quickActions[0].id).assertEqual('feed');
  expect(snapshot.quickActions[1].id).assertEqual('play');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `buildSurfaceSnapshot` is missing

- [ ] **Step 3: Write minimal implementation**

Create `harmony/entry/src/main/ets/common/services/PetSurfaceService.ets`:

```ts
import { PetAction, PetMood, PetSnapshot } from '../models/PetState';
import { SkinProfile } from '../models/SkinProfile';
import { PetSurfaceSnapshot } from '../models/PetSurfaceSnapshot';
import { DailySchedule, ScheduleRule } from '../../features/scheduler/ScheduleRule';

export interface BuildSurfaceInput {
  pet: PetSnapshot;
  skin: SkinProfile;
  schedule: DailySchedule;
  now?: Date;
}

export function buildSurfaceSnapshot(input: BuildSurfaceInput): PetSurfaceSnapshot {
  const now = input.now ?? new Date();
  const next = nextScheduleRule(input.schedule, now);

  return {
    petName: input.skin.petName,
    petMood: input.pet.mood,
    currentAction: input.pet.action,
    displayText: displayTextForAction(input.pet.action, input.pet.mood),
    nextScheduleText: next ? `${pad2(next.hour)}:${pad2(next.minute)} · ${next.reason}` : '',
    spriteState: spriteForState(input.pet.action, input.pet.mood),
    quickActions: [
      { id: 'feed', label: '喂一下', icon: '🍖', enabled: true },
      { id: 'play', label: '玩一下', icon: '🎾', enabled: true },
    ],
    updatedAt: now.getTime(),
  };
}

function displayTextForAction(action: PetAction, mood: PetMood): string {
  switch (action) {
    case PetAction.SLEEP: return '正在睡觉';
    case PetAction.EAT: return '正在吃饭';
    case PetAction.PLAY_BALL: return '正在玩球';
    case PetAction.PLAY_TOY: return '正在玩耍';
    case PetAction.SCRATCH: return '正在抓抓板';
    case PetAction.SUNBATHE: return '正在晒太阳';
    default:
      if (mood === PetMood.HUNGRY) return '有点饿了';
      if (mood === PetMood.SLEEPY) return '有点困了';
      return '我在这儿';
  }
}

function spriteForState(action: PetAction, mood: PetMood): string {
  switch (action) {
    case PetAction.SLEEP: return 'sleep';
    case PetAction.EAT: return 'eat';
    case PetAction.PLAY_BALL:
    case PetAction.PLAY_TOY:
      return 'playful';
    case PetAction.SUNBATHE: return 'sunbathe';
    default:
      return mood === PetMood.PLAYFUL ? 'playful' : 'idle';
  }
}

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

function nextScheduleRule(schedule: DailySchedule, from: Date): ScheduleRule | null {
  let best: { rule: ScheduleRule; whenMs: number } | null = null;
  for (const rule of schedule.rules) {
    if (!rule.enabled) continue;
    const when = nextRuleDate(rule, from).getTime();
    if (best === null || when < best.whenMs) {
      best = { rule, whenMs: when };
    }
  }
  return best?.rule ?? null;
}

function nextRuleDate(rule: ScheduleRule, from: Date): Date {
  const candidate = new Date(from.getFullYear(), from.getMonth(), from.getDate(), rule.hour, rule.minute, 0, 0);
  for (let dayOffset = 0; dayOffset < 8; dayOffset++) {
    const probe = new Date(candidate.getTime());
    probe.setDate(candidate.getDate() + dayOffset);
    if (probe.getTime() <= from.getTime()) continue;
    const weekday = probe.getDay();
    if (rule.weekdays.length > 0 && !rule.weekdays.includes(weekday)) continue;
    return probe;
  }
  return candidate;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS for `PetSurfaceService.test.ets`

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add harmony/entry/src/main/ets/common/services/PetSurfaceService.ets harmony/entry/src/ohosTest/ets/test/PetSurfaceService.test.ets && git commit -m "feat(surface): add pet surface service"
```

## Task 3: Implement `PetQuickActionService`

**Files:**
- Create: `harmony/entry/src/main/ets/common/services/PetQuickActionService.ets`
- Test: `harmony/entry/src/ohosTest/ets/test/PetQuickActionService.test.ets`

- [ ] **Step 1: Write the failing test**

Create `harmony/entry/src/ohosTest/ets/test/PetQuickActionService.test.ets`:

```ts
import { describe, it, expect } from '@ohos/hypium';
import { quickActionToEvent } from '../../../main/ets/common/services/PetQuickActionService';

describe('PetQuickActionService', () => {
  it('maps feed quick action to the feed event', 0, () => {
    const event = quickActionToEvent('feed');
    expect(event.type).assertEqual('user_feed_bone');
  });

  it('maps play quick action to the play event', 0, () => {
    const event = quickActionToEvent('play');
    expect(event.type).assertEqual('user_play_ball');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- FAIL because `PetQuickActionService` does not exist

- [ ] **Step 3: Write minimal implementation**

Create `harmony/entry/src/main/ets/common/services/PetQuickActionService.ets`:

```ts
import { PetEvent } from '../models/PetState';
import { PetEngine } from '../../features/pet3d/PetEngine';

export type QuickActionId = 'feed' | 'play';

export function quickActionToEvent(action: QuickActionId): PetEvent {
  switch (action) {
    case 'feed':
      return { type: 'user_feed_bone' };
    case 'play':
      return { type: 'user_play_ball' };
  }
}

export function handleQuickAction(action: QuickActionId): void {
  PetEngine.instance().dispatch(quickActionToEvent(action));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS for `PetQuickActionService.test.ets`

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add harmony/entry/src/main/ets/common/services/PetQuickActionService.ets harmony/entry/src/ohosTest/ets/test/PetQuickActionService.test.ets && git commit -m "feat(surface): add quick action service"
```

## Task 4: Publish Surface State Inside The App

**Files:**
- Modify: `harmony/entry/src/main/ets/pages/PetHome.ets`
- Modify: `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`

- [ ] **Step 1: Add a failing preview expectation**

Add a temporary preview assertion in `PetSurfaceService.test.ets`:

```ts
it('produces data suitable for card preview rendering', 0, () => {
  const snapshot = buildSurfaceSnapshot({
    pet: {
      petId: 'default',
      action: PetAction.SLEEP,
      mood: PetMood.SLEEPY,
      energy: 12,
      hunger: 65,
      affection: 50,
      lastInteractionAt: 1,
      lastActionSource: 'schedule',
      updatedAt: 2,
    },
    skin: defaultSkinProfile('default', '小橘'),
    schedule: defaultSchedule(),
    now: new Date('2026-05-06T21:55:00'),
  });

  expect(snapshot.displayText).assertEqual('正在睡觉');
  expect(snapshot.spriteState).assertEqual('sleep');
});
```

- [ ] **Step 2: Run tests to verify current behavior**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS, proving preview data is stable before wiring UI

- [ ] **Step 3: Publish the snapshot and add an in-app debug preview**

Modify `harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets`:

```ts
export const KEY_SURFACE_DEFAULT: string = 'surface:default';
```

Modify `harmony/entry/src/main/ets/pages/PetHome.ets` by deriving and publishing a snapshot whenever state changes:

```ts
import { KEY_SURFACE_DEFAULT } from '../common/utils/AppStorageKeys';
import { buildSurfaceSnapshot } from '../common/services/PetSurfaceService';

private publishSurfaceSnapshot(): void {
  const snapshot = buildSurfaceSnapshot({
    pet: this.snap,
    skin: this.skin,
    schedule: this.schedule,
  });
  AppStorage.setOrCreate(KEY_SURFACE_DEFAULT, snapshot);
}
```

Call `publishSurfaceSnapshot()`:

- after pet subscription updates `this.snap`
- after skin/schedule repos are ready

Add a temporary debug strip:

```ts
Text(`Surface: ${this.nextScheduleText}`)
  .fontSize(10)
  .fontColor('#999')
```

- [ ] **Step 4: Run app manually to verify preview behavior**

Manual verification:

1. Open `/host/workdir/pet_desk/harmony` in DevEco Studio
2. Run on device or simulator
3. Trigger `喂一下` / `玩一下` from the main app

Expected:

- The small preview strip updates without opening any system surface
- No regressions in `PetHome`

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add harmony/entry/src/main/ets/pages/PetHome.ets harmony/entry/src/main/ets/common/utils/AppStorageKeys.ets && git commit -m "feat(surface): publish surface snapshot from app state"
```

## Task 5: Implement The Minimum Desktop Service Card

**Files:**
- Create: `harmony/entry/src/main/ets/entryability/FormExtensionAbility.ets`
- Create: `harmony/entry/src/main/ets/features/form/PetCardForm.ets`
- Modify: `harmony/entry/src/main/module.json5`
- Modify: `harmony/entry/src/main/resources/base/element/string.json`

- [ ] **Step 1: Write a minimal failing behavior test for card data**

Add to `PetSurfaceService.test.ets`:

```ts
it('exposes exactly two quick actions for the service card', 0, () => {
  const snapshot = buildSurfaceSnapshot({
    pet: {
      petId: 'default',
      action: PetAction.IDLE,
      mood: PetMood.CALM,
      energy: 80,
      hunger: 30,
      affection: 50,
      lastInteractionAt: 1,
      lastActionSource: 'system',
      updatedAt: 2,
    },
    skin: defaultSkinProfile('default', '小橘'),
    schedule: defaultSchedule(),
    now: new Date('2026-05-06T11:00:00'),
  });

  expect(snapshot.quickActions.length).assertEqual(2);
  expect(snapshot.quickActions[0].label).assertEqual('喂一下');
  expect(snapshot.quickActions[1].label).assertEqual('玩一下');
});
```

- [ ] **Step 2: Run tests to confirm card contract is stable**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS, confirming surface data is ready for UI consumption

- [ ] **Step 3: Implement the card ability and UI**

Create `harmony/entry/src/main/ets/entryability/FormExtensionAbility.ets`:

```ts
import { FormExtensionAbility } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

export default class PetFormExtensionAbility extends FormExtensionAbility {
  onAddForm(want: Want) {
    return want;
  }
}
```

Create `harmony/entry/src/main/ets/features/form/PetCardForm.ets`:

```ts
import { handleQuickAction } from '../../common/services/PetQuickActionService';

@Component
export struct PetCardForm {
  @StorageLink('surface:default') surface = {
    petName: '我家宝贝',
    petMood: 'calm',
    currentAction: 'idle',
    displayText: '我在这儿',
    nextScheduleText: '',
    spriteState: 'idle',
    quickActions: [],
    updatedAt: 0,
  };

  build() {
    Column() {
      Text(this.surface.petName);
      Text(this.surface.displayText);
      Text(this.surface.nextScheduleText);
      Row() {
        Button('喂一下').onClick(() => handleQuickAction('feed'));
        Button('玩一下').onClick(() => handleQuickAction('play'));
      }
    }
  }
}
```

Modify `harmony/entry/src/main/module.json5` to register the form extension and any required form metadata block.

- [ ] **Step 4: Manual verify the card**

Manual verification:

1. Run the app on a HarmonyOS device
2. Add the PetDesk card to the desktop
3. Confirm card shows pet name, state, next schedule
4. Tap `喂一下`
5. Tap `玩一下`
6. Tap the card body

Expected:

- Card renders
- Quick actions update visible state
- Card tap opens the app

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add harmony/entry/src/main/ets/entryability/FormExtensionAbility.ets harmony/entry/src/main/ets/features/form/PetCardForm.ets harmony/entry/src/main/module.json5 harmony/entry/src/main/resources/base/element/string.json && git commit -m "feat(surface): add desktop service card"
```

## Task 6: Harden The Service Card

**Files:**
- Modify: `harmony/entry/src/main/ets/features/form/PetCardForm.ets`
- Modify: `harmony/entry/src/main/ets/common/services/PetSurfaceService.ets`
- Modify: `harmony/entry/src/main/ets/common/services/PetQuickActionService.ets`

- [ ] **Step 1: Add failing test for feedback-state mapping**

Add to `PetSurfaceService.test.ets`:

```ts
it('returns stable fallback text when no strong state is available', 0, () => {
  const snapshot = buildSurfaceSnapshot({
    pet: {
      petId: 'default',
      action: PetAction.IDLE,
      mood: PetMood.CALM,
      energy: 80,
      hunger: 30,
      affection: 50,
      lastInteractionAt: 1,
      lastActionSource: 'system',
      updatedAt: 2,
    },
    skin: defaultSkinProfile('default', '小橘'),
    schedule: defaultSchedule(),
    now: new Date('2026-05-06T11:00:00'),
  });

  expect(snapshot.displayText).assertEqual('我在这儿');
});
```

- [ ] **Step 2: Run tests to verify coverage**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS, giving a safe baseline before UI changes

- [ ] **Step 3: Add short-lived feedback and safer fallback rendering**

Modify `PetQuickActionService.ets`:

```ts
export interface QuickActionResult {
  ok: boolean;
  feedbackText: string;
}

export function handleQuickActionWithFeedback(action: QuickActionId): QuickActionResult {
  handleQuickAction(action);
  return {
    ok: true,
    feedbackText: action === 'feed' ? '吃饱啦' : '好开心',
  };
}
```

Modify `PetCardForm.ets`:

```ts
@State feedbackText: string = '';

private onQuickAction(action: 'feed' | 'play'): void {
  const result = handleQuickActionWithFeedback(action);
  this.feedbackText = result.feedbackText;
  setTimeout(() => {
    this.feedbackText = '';
  }, 2000);
}
```

Render fallback if the snapshot is incomplete:

```ts
Text(this.surface.displayText || '我在这儿');
```

- [ ] **Step 4: Manual verify hardening behavior**

Manual verification:

1. Add card to desktop
2. Tap quick actions repeatedly
3. Background and restore the launcher
4. Reboot app process if needed

Expected:

- No blank card state
- Feedback text appears briefly after action
- Card remains usable after restore

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add harmony/entry/src/main/ets/features/form/PetCardForm.ets harmony/entry/src/main/ets/common/services/PetSurfaceService.ets harmony/entry/src/main/ets/common/services/PetQuickActionService.ets && git commit -m "feat(surface): harden service card interactions"
```

## Task 7: Add Lock-Screen LiveView On The Same Model

**Files:**
- Create: `harmony/entry/src/main/ets/entryability/LiveViewExtensionAbility.ets`
- Create: `harmony/entry/src/main/ets/features/liveview/PetLiveView.ets`
- Modify: `harmony/entry/src/main/module.json5`
- Modify: `harmony/entry/src/main/resources/base/element/string.json`

- [ ] **Step 1: Write a failing test for lightweight lock-screen data**

Add to `PetSurfaceService.test.ets`:

```ts
it('provides lightweight text suitable for lock-screen display', 0, () => {
  const snapshot = buildSurfaceSnapshot({
    pet: {
      petId: 'default',
      action: PetAction.SUNBATHE,
      mood: PetMood.CALM,
      energy: 70,
      hunger: 20,
      affection: 55,
      lastInteractionAt: 1,
      lastActionSource: 'schedule',
      updatedAt: 2,
    },
    skin: defaultSkinProfile('default', '小橘'),
    schedule: defaultSchedule(),
    now: new Date('2026-05-06T15:00:00'),
  });

  expect(snapshot.displayText.length > 0).assertTrue();
  expect(snapshot.displayText.length <= 12).assertTrue();
});
```

- [ ] **Step 2: Run tests to verify lock-screen text contract**

Run:

```bash
cd "/host/workdir/pet_desk/harmony" && hvigorw test --mode module -p module=entry@default -p product=default
```

Expected:

- PASS when display text remains short enough for lock-screen usage

- [ ] **Step 3: Implement LiveView extension and UI**

Create `harmony/entry/src/main/ets/entryability/LiveViewExtensionAbility.ets`:

```ts
import { UIExtensionAbility } from '@kit.AbilityKit';

export default class PetLiveViewExtensionAbility extends UIExtensionAbility {}
```

Create `harmony/entry/src/main/ets/features/liveview/PetLiveView.ets`:

```ts
@Component
export struct PetLiveView {
  @StorageLink('surface:default') surface = {
    petName: '我家宝贝',
    petMood: 'calm',
    currentAction: 'idle',
    displayText: '我在这儿',
    nextScheduleText: '',
    spriteState: 'idle',
    quickActions: [],
    updatedAt: 0,
  };

  build() {
    Row() {
      Text('🐾');
      Column() {
        Text(this.surface.petName);
        Text(this.surface.displayText || '我在这儿');
      }
    }
  }
}
```

Modify `module.json5` to register the LiveView extension declaration.

- [ ] **Step 4: Manual verify lock-screen behavior**

Manual verification:

1. Run on device
2. Trigger a schedule event and one quick action
3. Lock the device
4. Observe the LiveView state
5. Tap into the app

Expected:

- Lightweight state appears
- Event state can intensify presentation
- Tapping opens the app

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add harmony/entry/src/main/ets/entryability/LiveViewExtensionAbility.ets harmony/entry/src/main/ets/features/liveview/PetLiveView.ets harmony/entry/src/main/module.json5 harmony/entry/src/main/resources/base/element/string.json && git commit -m "feat(surface): add liveview surface"
```

## Task 8: Documentation And Cleanup

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/2026-05-06-surface-and-liveview-design.md`

- [ ] **Step 1: Add a failing documentation checklist**

Create this checklist in your working notes and verify each item is still false before editing docs:

```text
[ ] Architecture mentions PetSurfaceService
[ ] Architecture mentions FormExtensionAbility
[ ] Architecture mentions LiveViewExtensionAbility
[ ] Roadmap marks service card progress
[ ] Roadmap marks LiveView progress
```

- [ ] **Step 2: Re-read docs and verify the checklist is still incomplete**

Run:

```bash
rg -n "PetSurfaceService|FormExtensionAbility|LiveViewExtensionAbility|服务卡片|实况窗" "/host/workdir/pet_desk/docs"
```

Expected:

- Missing or outdated references before documentation update

- [ ] **Step 3: Update documentation**

Add these concrete updates:

```md
## In docs/ARCHITECTURE.md
- Add `PetSurfaceService` between core state and system surfaces
- Mark `FormExtensionAbility` as implemented
- Mark `LiveViewExtensionAbility` as implemented or partial

## In docs/ROADMAP.md
- Mark M3 service card item complete once card manual verification passes
- Mark LiveView item partial or complete depending on actual scope finished

## In docs/2026-05-06-surface-and-liveview-design.md
- Add a short implementation status note at the top
```

- [ ] **Step 4: Verify docs are updated**

Run:

```bash
rg -n "PetSurfaceService|FormExtensionAbility|LiveViewExtensionAbility|服务卡片|实况窗" "/host/workdir/pet_desk/docs"
```

Expected:

- Updated references appear in the intended docs

- [ ] **Step 5: Commit**

```bash
cd "/host/workdir/pet_desk" && git add docs/ARCHITECTURE.md docs/ROADMAP.md docs/2026-05-06-surface-and-liveview-design.md && git commit -m "docs(surface): record M3 surface implementation"
```

## Self-Review

### 1. Spec coverage

This plan covers:

- Shared surface state model
- Surface-only responsibilities
- Service card first
- Two quick actions
- Lightweight-first visuals
- LiveView on the same snapshot model
- Error handling and fallback expectations
- Refresh strategy through app-published surface state

The only intentionally deferred area is deeper LiveView polish, which the approved design marked as later-stage behavior, not first delivery scope.

### 2. Placeholder scan

Checked for:

- `TODO`
- `TBD`
- "implement later"
- "add appropriate error handling"
- "write tests for the above"

None are used as task placeholders. Each task has explicit files, code snippets, and verification steps.

### 3. Type consistency

- `PetSurfaceSnapshot`
- `QuickActionDescriptor`
- `QuickActionId`
- `buildSurfaceSnapshot`
- `handleQuickAction`
- `handleQuickActionWithFeedback`
- `FormExtensionAbility`
- `LiveViewExtensionAbility`

These names are used consistently throughout this plan.

## Notes Before Execution

- If the checked-in Harmony project still lacks a usable local `hvigorw` wrapper, complete DevEco Studio project sync before executing the first test command.
- The Hypium test paths in this plan assume `ohosTest` is enabled for the `entry` module. If the generated test root differs after DevEco sync, keep the filenames and move the exact paths once before Task 1, then keep them stable for the rest of the plan.
- Implement the card before the LiveView even if both files are scaffolded in one branch. The card is the first ship target.

## Execution Handoff

Plan complete and saved to `docs/2026-05-06-surface-and-liveview-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
