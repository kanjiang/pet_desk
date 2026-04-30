# Scheduler v2 · 作息调度器

## 目标

让宠物**主动有事做**: 早上 7 点伸懒腰、中午 12 点找吃的、晚上 10 点半睡觉。
不是被动等用户点按钮才动。

## 数据模型

```typescript
interface ScheduleRule {
  id: string;          // 'morning_stretch' (稳定 key, 用户编辑时定位)
  hour: number;        // 0..23
  minute: number;      // 0..59
  action: PetAction;
  reason: string;      // 给 UI 显示的人话, '该起床啦'
  enabled: boolean;
  weekdays: number[];  // 0=周日..6=周六, 空数组 = 每天
}

interface DailySchedule {
  rules: ScheduleRule[];
  createdAt: number;
  updatedAt: number;
}
```

## 默认作息

| 时间 | 行为 | reason |
|---|---|---|
| 07:00 | HAPPY_JUMP | 起床伸懒腰 |
| 09:00 | PLAY_BALL | 上午精力旺,玩会儿球 |
| 12:00 | EAT | 午饭时间到 |
| 14:00 | SLEEP | 午睡 |
| 17:00 | SCRATCH | 抓抓板磨爪 |
| 19:00 | EAT | 晚饭 |
| 21:00 | PLAY_TOY | 睡前活动一下 |
| 22:30 | SLEEP | 该睡觉啦 |

## 调度循环

`Scheduler.start()` 每 30s tick 一次, 做两件事:

1. **scheduler_tick 事件**: 给 PetEngine 派发, 用于 energy/hunger 衰减
2. **作息扫描**:
   - `now.hour, now.minute` 当前时间
   - 找规则中 `hour===now.hour && minute===now.minute && enabled` 的项
   - 检查 `firedKey = id + ':' + dateKey + ':' + hourMinute` 是否在 1 分钟内已触发, 是则跳过 (防抖)
   - 派发 `{ type: 'schedule_fire', rule }` 给 PetEngine

为什么 30s 而不是 60s: 即使 tick 错过了精确分钟整点, 也能在下一次 tick 命中同分钟内.

为什么不用系统 cron: 鸿蒙没有进程外 cron 的概念给普通 App; M2 阶段先在 App 进程内用 setInterval. 后台触发等 M3 后台 Ability 上线.

## 持久化

`ScheduleRepo` 同 SkinRepo 一样:
- 内存 cache + Preferences XML (`petdesk_schedule.xml`)
- 启动时 hydrate
- save 时 putSync + flush

`DailySchedule` 整体序列化成一条 JSON, 不需要按 rule 拆 key.

## 用户编辑入口

`pages/Settings.ets` (M2 当前): 列出所有规则, 显示时间/行为/reason/开关
`pages/ScheduleEditor.ets` (M2.1): 拖拽时间、增删、星期选择

## 与 PetEngine 的契约

新增事件:
```typescript
| { type: 'schedule_fire'; rule: ScheduleRule }
```

PetEngine.reduce 处理: 把 `rule.action` 设为 current_action, 同时按 action 类型做副作用 (吃饭降饥饿、睡觉补精力).

## 测试技巧

调试时不想等到真实时间: Settings 页加"立即触发该规则"按钮, 直接 dispatch `schedule_fire`.

## 模块文件

```
features/scheduler/
├── ScheduleRule.ets       # 数据模型 + 默认规则
├── ScheduleRepo.ets       # 持久化
└── Scheduler.ets          # 调度器循环
```
