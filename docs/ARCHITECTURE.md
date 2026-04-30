# PetDesk 系统架构

## 1. 总体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        用户触点 (UI Surfaces)                    │
├─────────────┬──────────────┬──────────────┬────────────────────┤
│ App 主界面   │ 桌面服务卡片  │ 锁屏实况窗    │ 桌面端 (Phase 2)    │
│ (ArkUI Page)│ (FormExtAbi) │ (Deferred)   │ (Electron)         │
└──────┬──────┴───────┬──────┴───────┬──────┴─────────┬──────────┘
       │              │              │                │
       └──────────────┴──────┬───────┴────────────────┘
                             │
        ┌────────────────────▼─────────────────────┐
        │      Surface-State Layer (共享表面态)      │
        │ PetSurfaceService / PetQuickActionService│
        │      App-level PetSurfacePublisher       │
        └────────────────────┬─────────────────────┘
                             │
        ┌────────────────────▼─────────────────────┐
        │           PetEngine (业务核心)            │
        │  ┌──────────┐  ┌──────────┐  ┌────────┐ │
        │  │  Pet3D   │  │Interact- │  │Schedul-│ │
        │  │ Renderer │  │   ion    │  │   er   │ │
        │  └────┬─────┘  └────┬─────┘  └───┬────┘ │
        │       │             │            │      │
        │  ┌────▼─────────────▼────────────▼────┐ │
        │  │        PetState (状态机)            │ │
        │  │  current_action / mood / energy …  │ │
        │  └────┬───────────────────────────────┘ │
        └───────┼──────────────────────────────────┘
                │
   ┌────────────┼────────────┬─────────────┬───────────┐
   │            │            │             │           │
┌──▼────┐  ┌────▼─────┐  ┌───▼──────┐  ┌──▼───────┐ ┌─▼────────┐
│Photo2 │  │  Mood    │  │ Storage  │  │Distribut.│ │ Resource │
│ Skin  │  │ Sensor   │  │ (Prefs + │  │   Sync   │ │  Loader  │
│       │  │ (HRV/HR) │  │  RDB)    │  │          │ │ (glTF)   │
└───┬───┘  └────┬─────┘  └──────────┘  └────┬─────┘ └──────────┘
    │           │                            │
    │      ┌────▼────────┐         ┌─────────▼─────────┐
    │      │ Health Kit  │         │ Distributed Data  │
    │      │ Sensor Kit  │         │     Object        │
    │      └─────────────┘         └───────────────────┘
    │
┌───▼──────────────┐
│ AI Image Service │ (本地颜色提取 → 后期云端 3D 重建)
└──────────────────┘
```

## 2. 模块职责

### 2.1 PetEngine（业务核心，常驻）

承载宠物的"大脑"：
- **PetState**：单例状态机，持有当前动作、心情、精力、饥饿度等。主页面直接消费该状态，系统表面通过 `PetSurfaceService` 派生快照。
- **Scheduler**：基于真实时钟的作息表 (cron-like)。例：`07:00 → 起床伸懒腰`、`心情低落事件 → 触发安慰行为`。M2 实现详见下文 §3。
- **Interaction**：响应用户手势（点击、拖拽、长按），转发为状态机事件。M2 已支持 8 种行为。
- **Pet3DRenderer**：把 `PetState` 翻译成 3D 模型的动画 clip 和材质参数，驱动 `Component3D`。

设计原则：**UI / Surface ↔ Engine 单向数据流**。主页面只发事件（`engine.dispatch(event)`）并直接订阅状态；外部系统表面只消费派生后的轻量快照，不直接读取页面状态。

### 2.2 Photo2Skin（照片 → 外观）

MVP 路径：
1. 用户选 1~5 张宠物照片 (`PhotoViewPicker`)
2. 本地 ImageKit 解码 → `PixelMap` 缩放到 96×96 RGBA_8888
3. 中心 60% 区域采样 + 背景启发式过滤
4. K-means k=4 提取主色板
5. 写入 `SkinProfile`，发布到 `AppStorage('skin:<petId>')`，3D 渲染层自动响应

详见 [DESIGN-PHOTO2SKIN.md](./DESIGN-PHOTO2SKIN.md)。

### 2.3 Mood（手表心情感知，M3 部分实现）

当前 M3 第一版已经把 mood 主干接入到应用结构中：

- **MoodInferrer**：纯规则推断层，根据 `HealthReading` + baseline 推断 `relaxed` / `normal` / `stressed` / `low`
- **MoodStateRepo**：Preferences + AppStorage 状态仓储，保存最近 mood 快照和 baseline
- **MoodEngineService**：前台 refresh 编排层，负责“读数据 -> 推断 -> 节流 -> 必要时派发 `mood_signal`”
- **HealthProvider**：Health SDK 适配边界，当前代码里已隔离出统一入口，但真实 `HealthServiceKit` 方法仍待在本地 DevEco SDK 中补齐

当前策略仍是**前台刷新优先**：`EntryAbility.onCreate` 和 `onForeground` 触发一次 refresh，不做后台常驻监听。详见 [DESIGN-MOOD.md](./DESIGN-MOOD.md)。

### 2.4 Storage

| 数据 | 存储 | 状态 | 说明 |
|---|---|---|---|
| SkinProfile | **Preferences** `petdesk_skins.xml` | ✅ M1 | JSON-serialized, 由 SkinRepo 管理 |
| Daily Schedule | **Preferences** `petdesk_schedule.xml` | ✅ M2 | 用户编辑的 cron 时间表 |
| 用户偏好 | Preferences (单独 store) | M3 | 主题、音效、Mood 灵敏度 |
| Pet 列表 (多宠物) | Relational Store | M3 | 当前单 pet 用 Preferences 索引足够 |
| 用户上传照片 | App 沙箱 `files/photos/` | M2+ | 当前只存 URI |
| 模型 cache | App 沙箱 `cache/models/` | M4 | 云端 3D 重建结果 |
| 跨端同步状态 | Distributed Data Object | M3 | 仅同步轻量状态 |
| AppStorage `skin:<petId>` | 内存 | ✅ M1 | 给 `@StorageLink` 用的响应式发布渠道 |
| AppStorage `mood:current` / `mood:baseline` | 内存 | ✅ M3 部分 | 给 `PetHome` mood 预览和后续系统表面消费 |

**写路径**: `SkinRepo.save(profile)` → 内存 cache → AppStorage publish → `Preferences.putSync` + `flush()`

**读路径 (启动)**: `EntryAbility.onCreate` → `bootstrapPersistence(ctx)` → `SkinRepo.init` → 异步 `getPreferences` + `hydrate` → 每条都 publish 到 AppStorage → `@StorageLink` 自动触发 UI 重渲染

### 2.5 Surface-State Layer（M3 已实现）

- **PetSurfaceSnapshot**：面向系统表面的轻量只读模型，压缩宠物当前展示所需的最小状态。
- **PetSurfaceService**：从 `PetEngine`、`SkinRepo`、`ScheduleRepo` 等组合出稳定的 surface snapshot。
- **PetQuickActionService**：承接服务卡片的 quick action，把系统表面事件翻译回 `PetEngine.dispatch(...)`，并提供轻量反馈态。
- **PetSurfacePublisher**：应用侧统一发布入口，负责快照构建、缓存，以及向共享 form registry / form fan-out 路径分发更新。

### 2.6 Mood Slice（M3 部分实现）

- **HealthProvider**：统一隔离 Health Kit / Sensor Kit 的 SDK 细节，当前仍有一层待本地 SDK 补齐的真实读取实现
- **MoodInferrer**：纯逻辑、可测试，不直接依赖 Harmony kit
- **MoodStateRepo**：沿用现有 repo 模式，负责 mood snapshot / baseline 的持久化与 AppStorage 发布
- **MoodEngineService**：应用级 orchestrator，按前台生命周期刷新 mood，并在 `stressed` / `low` 时驱动 `PetEngine` 进入安慰态

### 2.7 UI Surfaces

- **App Page** (`pages/PetHome.ets`)：主交互，全屏 3D 宠物 + 互动菜单 + 作息状态条
- **App Mood Preview** (`pages/PetHome.ets` 内调试条)：已实现，用于显示最近 mood 状态与 baseline 样本数，验证真实链路
- **Form (服务卡片)** (`FormExtensionAbility` + `PetCardForm`)：已实现的桌面卡片路径，走共享 surface-state + form registry fan-out，当前以轻量文本/精灵态和 hardened quick-action 反馈为主。
- **LiveView (实况窗)**：设计保留，但当前未实现；在现有 SDK 12 基线（`compatibleSdkVersion: 5.0.0(12)`）下暂不具备稳定可靠的公开实现基础，后续待 capability 对齐后再落地。
- **Desktop (Electron)**：Phase 2 (M4+)

## 3. Scheduler v2 (M2)

### 3.1 数据模型

`DailySchedule` 是一组按钟表时间触发的"自动行为"规则:

```typescript
interface ScheduleRule {
  id: string;                // 'morning_stretch'
  hour: number;              // 0..23
  minute: number;            // 0..59
  action: PetAction;         // PetAction.HAPPY_JUMP
  reason: string;            // '该起床啦'
  enabled: boolean;
  weekdays: number[];        // [0..6], 空数组 = 每天
}

interface DailySchedule {
  rules: ScheduleRule[];
  createdAt: number;
  updatedAt: number;
}
```

### 3.2 默认作息

| 时间 | 行为 | 说明 |
|---|---|---|
| 07:00 | HAPPY_JUMP | 起床伸懒腰 |
| 09:00 | PLAY_BALL | 上午玩耍 |
| 12:00 | EAT | 午饭 |
| 14:00 | SLEEP | 午睡 |
| 17:00 | SCRATCH | 抓抓板 |
| 19:00 | EAT | 晚饭 |
| 21:00 | PLAY_TOY | 睡前玩耍 |
| 22:30 | SLEEP | 入睡 |

### 3.3 调度循环

`Scheduler.start()` 启动一个 30 秒一次的 tick:
1. 拉取当前时间 `(hour, minute)`
2. 在规则表里找 "本分钟尚未触发过" 的规则
3. 派发 `{ type: 'schedule_fire', rule }` 给 PetEngine
4. 用一张 `firedKey -> timestamp` 的 LRU map 防 1 分钟内重复触发

同时 30s 派发一次 `{ type: 'scheduler_tick' }`, 让 PetEngine 衰减 energy/hunger.

### 3.4 用户编辑入口

`pages/Settings.ets` (M2 占位): 列出当前规则, 可拖拽时间、关掉单条、新增。修改后 `ScheduleRepo.save` 持久化。

## 4. 进程与生命周期

- **EntryAbility**：App 主入口
- **PetEngineAbility (BackgroundAbility)** (M3)：常驻轻量后台，承担 Scheduler 和 Mood 监听
- **FormExtensionAbility** (M3)：已实现，服务卡片入口；通过共享 form registry 接收 `PetSurfacePublisher` fan-out 更新。
- **LiveViewExtensionAbility**：未实现，待 SDK / capability 基线具备可靠公开方案后再落地。
- **Mood refresh**：当前由 `EntryAbility.onCreate` / `onForeground` 触发，不做后台常驻 service。

后台心率订阅需考虑省电：仅在用户进入 App 或 Form 触发时拉一次最近窗口数据，不做常驻订阅。

## 5. 关键非功能性需求

| 维度 | 目标 |
|---|---|
| 启动到首帧 | < 600ms |
| 主页 3D 帧率 | ≥ 30fps（中端机），≥ 60fps（旗舰） |
| 卡片刷新 | 单次 < 200ms |
| 包体积 | 首装 < 60MB（模型按需下载） |
| 隐私 | 照片仅本地处理；HRV 数据不出端，云端 3D 重建需用户显式授权 |

## 6. 后续待补

- [ ] 详细的 PetState 状态图（DESIGN-STATE.md）
- [x] Scheduler v2 设计（本文 §3）
- [x] Photo2Skin 算法细节（DESIGN-PHOTO2SKIN.md）
- [x] Mood 规则与训练计划（DESIGN-MOOD.md）
- [ ] 跨端同步协议（DESIGN-SYNC.md, M3）
