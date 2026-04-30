# PetDesk Roadmap

> 目标：用最快速度让"我家宠物住在我手机里"这件事变成现实，再逐步增厚体验。

## M0 · 项目奠基（1 周） ✅

- [x] 需求拆解 + 技术选型决策
- [x] 项目骨架（鸿蒙 + 桌面端 + shared）
- [x] README / ARCHITECTURE / ROADMAP 文档
- [ ] DevEco Studio 工程能成功打开（保留首次手动打开）
- [ ] CI 占位（鸿蒙 hvigor 构建流水线）

---

## M1 · 桌面宠物 MVP（2~3 周） ✅ 软件完成 (待美术)

### 交付清单
- [x] App 主页 `PetHome.ets`
- [x] Pet3DRenderer：用 `@kit.ArkGraphics3D` + `Component3D` 加载 glTF
- [x] 模型注册表 `ModelRegistry.ets`
- [ ] **3 个预设模型 .glb** ← 美术资源
- [ ] **每个模型 4 个动画 clip** ← 美术资源
- [x] PetState 状态机
- [x] Photo2Skin v0：照片选择 → K-means 提主色 → 替换模型 baseColor
- [x] 数据持久化：SkinProfile 落到 Preferences
- [ ] 真机跑通（依赖美术）

---

## M2 · 互动与作息（2 周） ✅ 当前

### 交付清单
- [x] 互动行为（≥5 个）：撸毛、丢球、喂骨头、抓猫抓板、玩逗猫棒、晒太阳、伸懒腰
- [x] Scheduler v2：基于真实时钟 + cron-like 规则触发
- [x] 默认作息表：07:00 起床 → 09:00 玩耍 → 12:00 吃饭 → 14:00 睡觉 → 17:00 抓板 → 19:00 吃饭 → 21:00 玩耍 → 22:30 睡觉
- [x] 作息表持久化 (`ScheduleRepo` + Preferences)
- [x] 用户可在 Settings 页查看作息（编辑功能 M2.1）
- [x] PetState 增加 energy/hunger/affection 数值衰减
- [x] 行为转移防抖（防止 1 分钟内同规则重复触发）
- [x] PetHome 显示"下一项作息"提示

---

## M3 · 跨端与手表（3 周） ⏳ 部分完成

- [x] 服务卡片（`FormExtensionAbility` + `PetCardForm` + shared surface-state / form fan-out）
- [ ] 实况窗（LiveView）：设计已确认，轻量文本 contract test 保留；当前受 SDK 12 / `compatibleSdkVersion: 5.0.0(12)` 公共能力基线限制，代码实现延期
- [~] Health Kit 接入（已落 `HealthProvider` 适配边界与权限/生命周期接线；真实 `HealthServiceKit` 本地 SDK 方法仍待补齐）
- [~] Mood Engine v1（`MoodInferrer` / `MoodStateRepo` / `MoodEngineService` / `PetHome` mood 预览已落地，真手表闭环待 `HealthProvider` 真读数完成）
- [ ] 跨端（Distributed Data Object）

---

## M4 · AI 真 3D 与桌面端（4 周+）

- [ ] 接入云端 3D 重建：Tripo / Hunyuan3D
- [ ] 自动绑骨流程
- [ ] Electron 桌面端 v1
- [ ] 多宠物管理

---

## M5+ · 长期愿景

- AR 模式：在手机摄像头里把数字分身放进真实房间
- 语音互动
- 社交：朋友家的宠物来串门
- 跨品牌手表：Apple Watch / Garmin / 小米手表

---

## 当前焦点

🟢 **当前已完成**：M0、M1（软件层）、M2，以及 M3 的 shared surface-state + 服务卡片路径
🟡 **M3 当前进度**：服务卡片已落地并做过加固；LiveView 因 SDK / capability baseline 暂缓；Health / Mood 主干已接上但 `HealthProvider` 真实本地 SDK 读数仍待补齐；Distributed Data Object 仍待实现
🟡 **下一步候选**：D（拉美术资源跑通真机） / 补齐 `HealthProvider` 真读数并做真机验证 / M3 余项（Sync） / LiveView 能力基线对齐 / Settings 编辑器
