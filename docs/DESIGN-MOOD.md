# Mood Engine · 手表心情感知

## Status

- Scope: Huawei Watch + HarmonyOS phone first
- Current implementation status: partially implemented in repo
- Chosen delivery strategy: **real watch data first, foreground refresh first**
- First version goal: connect real Health data to a minimal comfort-response loop without committing to always-on background monitoring
- Landed in code:
  - `MoodReading`
  - `MoodInferrer`
  - `MoodStateRepo`
  - `MoodEngineService`
  - `EntryAbility` startup / foreground refresh hook
  - `PetHome` mood preview strip
- Still pending:
  - replace `HealthProvider`'s current placeholder read path with the exact `HealthServiceKit` / local DevEco SDK calls available in the target environment
  - complete real-device verification with Huawei Watch authorization and live readings

## 目标

通过华为手表的健康数据，**轻量、无监督地**判定用户当前状态，在需要时触发宠物的安慰行为。

本模块的目标是做出一条稳定的真实链路：

`Huawei Watch / Health Kit -> HealthProvider -> MoodEngineService -> MoodInferrer -> MoodStateRepo -> PetEngine.dispatch(mood_signal)`

⚠️ **不做医疗诊断，只做陪伴体验的触发信号。**

## 第一版边界

### In scope

- 仅支持 `Huawei Watch`
- 接入真实健康数据读取
- App 启动完成后进行一次 mood 刷新
- App 回到前台时再次刷新
- 记录最近一次 mood 结果和刷新时间
- 当结果为 `stressed` 或 `low` 时，驱动宠物进入安慰态
- 在主页面提供轻量 mood 状态预览，方便验证链路

### Out of scope

- 常驻后台持续监听
- 高频实时心率流处理
- 医疗/健康结论解释
- 锁屏或 LiveView 联动
- 跨品牌手表

## 数据源

| 指标 | API | 第一版角色 |
|---|---|---|
| 心率 (HR) | `@kit.SensorServiceKit` 或 `@kit.HealthServiceKit` 中可稳定获取的最近读数 | 判断急性紧张 |
| HRV | `@kit.HealthServiceKit` | 判断恢复与低落倾向 |
| 压力评分 | `@kit.HealthServiceKit` | 作为紧张辅助信号 |
| 睡眠质量 / 最近睡眠上下文 | `@kit.HealthServiceKit` | 作为低落判断修正项 |

说明：

- 第一版以**最近一次可稳定读取的数据**为主，不承诺全量时间序列分析。
- API 细节可能因实际 Harmony / Health Kit 版本而略有差异，因此实现层会收敛成统一 `HealthReading`，不把 SDK 类型扩散到业务层。

## 心情维度

```typescript
export type MoodLevel = 'relaxed' | 'normal' | 'stressed' | 'low';
```

语义约定：

- `relaxed`: 当前状态较放松，只记录，不主动高频打扰
- `normal`: 无需特殊陪伴反馈
- `stressed`: 当前更像紧张 / 压力偏高，需要安慰触发
- `low`: 当前更像低活力 / 低落，需要安慰触发

## 架构拆分

### `HealthProvider`

负责与手表 / Health Kit 交互，读取最近一次可用健康数据，并输出统一格式的 `HealthReading`。

职责：

- 判断当前是否具备读取条件
- 执行一次读取
- 归一化不同 API 的返回结构
- 屏蔽底层 SDK 差异

### `MoodInferrer`

纯规则层，不直接依赖 Harmony SDK。

职责：

- 根据 `HealthReading` + baseline + 时间上下文推断 mood
- 保持规则可测试
- 避免把权限、设备、存储逻辑混进推断代码

### `MoodStateRepo`

负责持久化和发布当前 mood 状态。

职责：

- 保存最近一次 `MoodReading`
- 保存最近一次成功 refresh 时间
- 保存最近一次触发时间
- 保存静默窗口状态
- 发布到 `AppStorage('mood:current')`

### `MoodEngineService`

负责编排整个 mood 流程。

职责：

- 调用 `HealthProvider` 拉取真实数据
- 调用 `MoodInferrer` 做推断
- 应用节流 / 静默策略
- 更新 `MoodStateRepo`
- 必要时调用 `PetEngine.dispatch({ type: 'mood_signal', ... })`

## 数据模型

建议第一版收敛成以下轻量模型：

```typescript
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

## 规则引擎 v1

### 基线策略

第一版不要求“必须先积满 7 天才能工作”。

采用两段式：

1. **冷启动阶段**
   - 当基线不足时，允许使用保守默认阈值
   - 只在明显异常时判为 `stressed` 或 `low`
   - 其他情况回落到 `normal`

2. **基线稳定阶段**
   - 当累积到足够样本后，优先使用相对个人基线
   - 使用中位数 / 稳健统计，避免被单次异常值带偏

### 判定规则

```typescript
if (hr is clearly above baseline && stress is high) -> 'stressed'
if (hrv is clearly below baseline && sleepScore is poor) -> 'low'
if (hrv is above baseline && stress is low) -> 'relaxed'
else -> 'normal'
```

第一版设计原则：

- 宁可少报，不要频繁误报
- 单次读数不直接等于用户“情绪”
- `normal` 只更新状态，不触发宠物行为

## 触发节流

- 同一 mood 在 30 分钟内最多触发一次宠物行为
- `normal` 不触发 `PetEngine` 行为
- 如果后续加入“用户忽略安慰反馈”的计数，可扩展为 24 小时静默，但第一版允许先只实现时间节流
- 手动刷新允许更新状态，但不强制重复触发宠物动作

## 宠物反应映射

| mood | PetEngine 事件 | 第一版行为 |
|---|---|---|
| `stressed` | `mood_signal('stressed')` | 进入 `COMFORT` + `CONCERNED` |
| `low` | `mood_signal('low')` | 进入 `COMFORT` + `CONCERNED` |
| `relaxed` | `mood_signal('relaxed')` 或仅更新状态 | 第一版建议只记录，不强制切动作 |
| `normal` | 无 | 不触发 |

说明：

- 第一版主线是“在你状态不好时宠物来安慰你”
- `relaxed` 先不做高频打扰型反馈，避免体验太吵
- 对外文案不直接说“你压力大了”，降低被监视感

## 生命周期与刷新策略

第一版刷新时机：

1. `EntryAbility.onCreate` 完成基础初始化后刷新一次
2. `EntryAbility.onForeground` 时刷新一次
3. 后续如果有“手动刷新”入口，可调用同一个 `MoodEngineService.refresh()`

第一版不做：

- 后台常驻心率订阅
- 长时运行 service
- 高频定时轮询

## UI 与调试呈现

第一版只在 `PetHome` 中增加一个轻量 mood 预览区，显示：

- 是否已有最近一次 mood 结果
- 最近 mood level
- 最近刷新时间
- 可选调试说明（如最近一次原因文案）

这样可以验证真实链路，而不需要先设计复杂的情绪中心页面。

## 错误处理

### 读取失败

- 不要让 App 启动失败
- 保留上一次成功的 mood 状态
- 记录日志，UI 允许显示“暂未获取到新数据”

### 权限未授权

- 不强行触发宠物安慰逻辑
- UI 显示未连接 / 未授权状态
- 保持主功能可用

### 手表无数据

- 回退到 `normal` 或“未知状态”，而不是伪造安慰事件

## 隐私

- HR / HRV / 压力原始数据**永不上云**
- 只保存 mood 派生结果和必要的最近一次读数摘要
- 明示“仅作陪伴体验，不可用于健康判断”
- 允许未来添加导出 / 删除衍生数据能力

## 测试策略

### 自动化测试

- `MoodInferrer`：规则推断单测
- `MoodStateRepo`：持久化 / 节流单测
- `MoodEngineService`：mock provider 下的编排单测

### 手动验证

- 华为手表授权链路是否可用
- App 前台时能否拉到最近数据
- 主页面是否显示最近 mood 状态
- `stressed` / `low` 是否能驱动宠物进入安慰态

## v2 计划

- 从“前台 refresh”升级到更强的实时监听
- 引入更稳定的 baseline builder
- 加入用户忽略 / 接受反馈循环
- 让 surface card / future LiveView 消费 mood 状态

## 模块文件

```text
features/mood/
├── HealthProvider.ets
├── MoodEngineService.ets
├── MoodInferrer.ets
├── MoodReading.ets
└── MoodStateRepo.ets
```
