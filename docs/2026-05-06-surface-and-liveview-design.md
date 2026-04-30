# PetDesk M3 Design: Surface Card And LiveView

## Status

- Topic: HarmonyOS `服务卡片` + `锁屏实况窗`
- Decision date: 2026-05-06
- Design status: Approved in chat
- Implementation policy: Design both surfaces together, implement `服务卡片` first

## Implementation status note

- The shared surface-state path is now implemented in code: `PetSurfaceSnapshot`, `PetSurfaceService`, `PetQuickActionService`, and the app-level `PetSurfacePublisher`.
- The desktop service card path is shipped as a minimal hardened widget via `FormExtensionAbility` + `PetCardForm`, backed by the shared form registry / form fan-out update path and quick-action feedback hardening.
- The lock-screen LiveView remains design-approved but deferred in code. The lightweight text contract test is still useful, but the actual implementation was removed because the current public SDK 12 baseline (`compatibleSdkVersion: 5.0.0(12)`) does not yet provide a reliable public foundation for this repo.
- Unless otherwise noted, the rest of this document remains the approved design target rather than a statement that LiveView is already present in the shipped code.

## Goal

Bring the pet out of the main app and onto the user's device surfaces while keeping the first M3 delivery stable and lightweight.

This design optimizes for:

1. Persistent pet presence outside the app
2. Low implementation risk for the first delivery
3. A single shared state model across app, card, and lock screen
4. Fast user interactions from the desktop card
5. A future upgrade path from lightweight visuals to richer animated surfaces

## Product Decisions

### Chosen approach

The approved direction is:

- Design `服务卡片` and `锁屏实况窗` together
- Implement `服务卡片` first
- Use a lightweight-first strategy for the card
- Keep `锁屏实况窗` as an always-present companion surface
- Support `1~2` quick actions on the card in the first version

### Recommended experience strategy

#### Surface card

The desktop card is the **interactive companion surface**.

Its job is to let the user:

- See the pet's current state
- See the next scheduled activity
- Trigger one quick interaction without opening the app
- Open the app for deeper interaction

#### LiveView

The lock-screen LiveView is the **ambient presence surface**.

Its job is to:

- Show that the pet is still "alive" on the device
- Display a minimal status most of the time
- Expand or intensify only on important events
- Avoid becoming a second full application surface

## Responsibility Split

The two surfaces must not duplicate each other.

### Surface card responsibilities

- Lightweight companion widget on the desktop
- Quick interaction entry point
- Higher information density than lock screen
- Short action feedback after quick interactions

### LiveView responsibilities

- Low-disruption lock-screen presence
- Persistent lightweight state
- Event-based enhanced presentation
- Entry point into the app when a user wants more detail

## First-Version Scope

## Surface Card V1

### Required content

- Lightweight pet visual using sprite or lightweight animated asset
- Current pet state text
- Next schedule text
- Two quick actions:
  - `喂一下`
  - `玩一下`

### Interaction model

- Tap pet body: open the app
- Tap quick action: dispatch one action, update surface state, show lightweight feedback
- Tap status area: open the app

### Explicitly out of scope

- Full 3D rendering inside the card
- Large action panel
- Schedule editing
- High-frequency refresh animation
- Complex multi-step interactions

## LiveView V1

### Required content

- Small pet visual
- One short status sentence
- Optional next-schedule hint when useful

### Display modes

#### Always-on lightweight state

This is the default mode.

Example content:

- `在晒太阳`
- `准备午睡`
- `想你了`

#### Event-enhanced state

This appears on notable moments:

- Feeding time
- Bedtime
- Play reminder
- Post-interaction feedback
- Future mood-support event

### Explicitly out of scope

- Complex controls on the lock screen
- High-density information layout
- Card-level quick actions duplicated on the lock screen
- App-like navigation behavior

## Architecture

## Core design rule

`服务卡片` and `锁屏实况窗` must not read page state directly. They both consume a shared lightweight surface model.

### New shared model

```ts
interface PetSurfaceSnapshot {
  petName: string;
  petMood: string;
  currentAction: string;
  displayText: string;
  nextScheduleText: string;
  spriteState: string;
  quickActions: QuickActionDescriptor[];
  updatedAt: number;
}
```

This model exists to compress internal app state into the minimum required surface representation.

### New shared services

#### `PetSurfaceService`

Builds a `PetSurfaceSnapshot` from:

- `PetEngine.current()`
- `SkinRepo`
- `ScheduleRepo`

Responsibilities:

- Derive user-facing text
- Map action/mood into sprite state
- Build quick-action availability
- Produce stable, surface-safe fallback output

#### `PetQuickActionService`

Receives quick actions from system surfaces and translates them into `PetEngine.dispatch(...)`.

Responsibilities:

- Validate action support
- Dispatch action events
- Trigger lightweight feedback state
- Request surface refresh

### HarmonyOS extension split

#### `FormExtensionAbility`

Purpose:

- Desktop surface card rendering
- Card click handling
- Quick action entry point

#### `LiveViewExtensionAbility`

Purpose:

- Lock-screen lightweight presence
- Event-based enhanced presentation
- Jump-to-app entry

## High-Level Data Flow

```text
PetEngine / SkinRepo / ScheduleRepo
            ↓
     PetSurfaceService
        ↓        ↓
 FormExtension   LiveViewExtension
        ↓
 PetQuickActionService -> PetEngine.dispatch()
```

### Quick action flow

```text
User taps "喂一下" on card
  -> FormExtensionAbility receives click
  -> PetQuickActionService.handle("feed")
  -> PetEngine.dispatch({ type: "user_feed_bone" })
  -> PetSurfaceService rebuilds snapshot
  -> Card refreshes
  -> Short feedback text appears
```

## Refresh Strategy

The first version should not refresh everything on every state change. It should use layered refresh rules.

### 1. Event-driven refresh

Refresh immediately when:

- A quick action succeeds
- Schedule fires
- Skin changes
- Pet state meaningfully changes
- LiveView enhancement event occurs

### 2. Low-frequency fallback refresh

- Card: minute-level fallback refresh
- LiveView: no aggressive polling; refresh when state changes or on valid platform event windows

### 3. Cold-start recovery refresh

If the surface is recreated by the system:

- Load the latest available `PetSurfaceSnapshot` or reconstruct it quickly
- Show a safe default if state is temporarily unavailable
- Prefer `show something fast, then become accurate`

## Error Handling

## Guiding principle

Surface failures must not break the main app.

### Rule 1: Surface isolation

- Card update failure affects only the card
- LiveView failure affects only the LiveView
- `PetEngine`, `SkinRepo`, and `ScheduleRepo` remain authoritative

### Rule 2: Quick action fallback

When a quick action fails:

- Do not freeze the surface
- Show a lightweight fallback message such as `稍后再试`
- Still allow opening the app

### Rule 3: Missing-state fallback

If `PetSurfaceSnapshot` cannot be generated:

- Show default pet sprite
- Show safe text: `我在这儿`
- Keep tap-to-open app functional
- Avoid showing broken or contradictory state

## Consistency Rules

To prevent app/card/lock-screen mismatch:

1. All external surfaces read from the same surface snapshot model
2. All quick actions flow back into `PetEngine`
3. No extension ability directly mutates rendering-layer state
4. The main app remains the primary truth source

## Delivery Plan

## Milestone M3-1: Shared surface state

Status: Implemented in repo.

Implemented scope:

- `common/models/PetSurfaceSnapshot.ets`
- `common/services/PetSurfaceService.ets`
- `common/services/PetQuickActionService.ets`

Current result:

- App can render a debug preview of surface state
- Text, sprite state, and quick actions are derivable from current repos/services

## Milestone M3-2: Minimum service card

Status: Implemented in repo.

Implemented scope:

- `FormExtensionAbility`
- Card UI
- Quick action wiring

Current result:

- User can place the card on the desktop
- Card shows pet visual, current status, next schedule
- Card supports `喂一下` and `玩一下`
- Tapping the card opens the app

## Milestone M3-3: Card hardening

Status: Implemented in repo.

Implemented scope:

- Feedback messaging
- Sprite-state mapping
- Refresh policy stability
- Error fallback behavior

Current result:

- Card feels reliable and responsive
- No blank-state regressions on restore or update

## Milestone M3-4: LiveView integration

Status: Deferred for now, blocked by current SDK / capability baseline.

Future target when unblocked:

- `LiveViewExtensionAbility`
- Lightweight persistent lock-screen mode
- Event-enhanced mode

Future success criteria:

- LiveView uses the same surface snapshot model as the card
- Important events can elevate display intensity
- Tapping still opens the app

## Files To Add In Implementation

```text
# Already present in repo
harmony/entry/src/main/ets/common/models/PetSurfaceSnapshot.ets
harmony/entry/src/main/ets/common/services/PetSurfaceService.ets
harmony/entry/src/main/ets/common/services/PetQuickActionService.ets
harmony/entry/src/main/ets/entryability/FormExtensionAbility.ets
harmony/entry/src/main/ets/features/form/PetCardForm.ets

# Future / deferred LiveView-specific files
harmony/entry/src/main/ets/entryability/LiveViewExtensionAbility.ets
harmony/entry/src/main/ets/features/liveview/PetLiveView.ets
```

`module.json5` already needs to reflect the shipped card path; any LiveView-specific declaration remains future work together with the deferred implementation.

## Testing Strategy

### Design-level verification

- Confirm shared surface model is sufficient for both card and lock screen
- Confirm no surface directly depends on `PetHome`
- Confirm quick actions route through `PetEngine`

### Functional verification targets

#### Surface card

- Can be added to desktop
- Shows correct pet state
- Shows next schedule
- Quick actions update state
- Main app opens from card tap

#### LiveView

- Shows persistent lightweight state
- Can transition to enhanced event state
- Opens app correctly

#### Consistency

- App, card, and lock screen do not diverge on obvious state
- Surface failure does not break app usage

## Explicit Non-Goals For First Delivery

- Real-time 3D rendering on system surfaces
- Complex lock-screen controls
- Editing schedule from card or lock screen
- Cross-device multi-surface synchronization
- Deep watch mood integration in the same release

## Risks

### Technical risks

- HarmonyOS extension ability lifecycle differences
- Refresh policy restrictions on cards/live surfaces
- Surface update throttling by the system
- Asset limitations for lightweight animation

### Product risks

- Making card and lock screen feel too similar
- Putting too much interaction into the lock screen
- Overloading V1 with high-fidelity rendering work

## Mitigations

- Shared surface state model
- Surface-specific responsibility split
- Lightweight-first visual strategy
- Card-first implementation order
- Strict non-goals for V1

## Final Recommendation

Current recommendation:

1. Keep the shared surface-state layer and hardened desktop card as the active baseline.
2. Continue using this document as the design target for LiveView behavior.
3. Revisit lock-screen LiveView implementation only after SDK / capability alignment provides a reliable public path.

This keeps the shipped surface strategy stable today while preserving the approved future direction.
