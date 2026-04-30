# PetDesk · 我的口袋宠物分身

> 把自家的猫猫狗狗变成 3D 数字分身，让它住在你的鸿蒙手机、手表和桌面里 —— 陪你睡觉、陪你工作、在你心情低落时跑出来逗你笑。

[![HarmonyOS NEXT](https://img.shields.io/badge/HarmonyOS-NEXT_API12+-blue)](https://developer.huawei.com/consumer/cn/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
[![Status](https://img.shields.io/badge/status-MVP_in_progress-orange)]()

---

## ✨ 项目愿景

市面上的桌面宠物大多是固定形象。**PetDesk 的核心差异**是：你输入自己家宠物的照片，App 把它变成专属的 3D 数字分身，而不是又一只通用的小狗。再加上鸿蒙生态的多端协同 —— 手机锁屏、桌面卡片、华为手表 —— 让这只数字分身成为你生活里真正的"宠物伙伴"。

## 🎯 核心功能

| 功能 | 说明 | 阶段 |
|---|---|---|
| 📸 **照片生成宠物** | 上传 1~5 张宠物照片，提取毛色花纹生成专属外观（MVP）；后期升级 AI 真 3D 重建 | M1 / M4 |
| 🐕 **3D 桌面宠物** | 基于 ArkGraphics 3D 渲染，可在 App 内、服务卡片、锁屏实况窗显示 | M1 |
| 👆 **互动玩耍** | 点击撸毛、拖拽、喂骨头、丢球、抓猫抓板 | M2 |
| ⏰ **作息系统** | 按时间自动触发：早晨伸懒腰、中午吃饭、下午玩耍、晚上睡觉 | M2 |
| ⌚ **手表心情感知** | 通过华为手表心率/HRV/压力值，识别"心情低落"，触发宠物主动安慰 | M3 |
| 🔄 **跨端漫游** | 手机 → 平板 → 桌面 PC，宠物状态分布式同步 | M4 |
| 🔒 **锁屏陪伴** | 通过 Live View Kit 实况窗，在锁屏沉浸态展示宠物 | M3 |

## 🧱 技术选型

### 主端：HarmonyOS NEXT App

| 维度 | 选型 | 原因 |
|---|---|---|
| 语言 / 框架 | **ArkTS + ArkUI** | 鸿蒙原生，开发效率高 |
| 3D 渲染 | **ArkGraphics 3D** (`@kit.ArkGraphics3D`) | 系统原生，glTF 支持，性能好 |
| 健康数据 | **Health Service Kit** + **Sensor Service Kit** | 接入华为手表心率/HRV |
| 锁屏展示 | **Live View Kit** (实况窗) | 沉浸态锁屏卡片官方方案 |
| 桌面卡片 | **FormExtensionAbility** (服务卡片) | 桌面常驻入口 |
| 跨端同步 | **Distributed Data Object** | 鸿蒙分布式能力 |
| 本地存储 | **Preferences + Relational Store** | 系统级 KV + 关系型存储 |
| 高性能计算 | （可选）**Cangjie / NAPI C++** | 图像处理、AI 推理 |

### 辅端：桌面应用 (Phase 2)

| 维度 | 选型 |
|---|---|
| 框架 | **Electron + React + Three.js** |
| 3D 渲染 | Three.js + react-three-fiber |
| 与手机同步 | 通过华为账号 / WebSocket 中继 |

### 照片→3D 路线

- **MVP（M1）**：预设 8~10 个高质量宠物 3D 模型（短毛猫/长毛猫/柴犬/金毛/边牧/兔子/仓鼠…），从用户照片提取**主色 + 花纹遮罩**，作为贴图替换写入模型 PBR 材质
- **Phase 2（M4+）**：接入 AI 真 3D 重建（Tripo / Hunyuan3D 云端 API），生成专属网格 + 自动绑骨

## 🗂 仓库结构

```
pet_desk/
├── README.md                  # 你在看的这份
├── docs/                      # 设计文档
│   ├── ARCHITECTURE.md        # 系统架构
│   ├── ROADMAP.md             # 分阶段里程碑
│   ├── DESIGN-PHOTO2SKIN.md   # 照片→宠物外观算法
│   └── DESIGN-MOOD.md         # 手表心情识别算法
├── harmony/                   # 鸿蒙 App (主端)
│   └── entry/src/main/ets/
│       ├── pages/             # ArkUI 页面
│       ├── features/          # 业务模块
│       │   ├── pet3d/         # 3D 宠物渲染与动画
│       │   ├── interaction/   # 玩耍互动
│       │   ├── scheduler/     # 作息调度
│       │   ├── mood/          # 心情感知
│       │   ├── photo2skin/    # 照片→外观
│       │   └── storage/       # 持久化
│       ├── common/            # 通用模型/工具/服务
│       └── entryability/      # App 入口
├── desktop/                   # 桌面端 (Electron, Phase 2 占位)
├── shared/                    # 跨端共享：JSON Schema、示例资源
├── scripts/                   # 构建/发布脚本
└── ci/                        # CI 配置
```

## 🚀 快速开始

> ⚠️ 当前处于 **M1 MVP 启动期**，仅有项目骨架。具体跑通步骤将随 M1 完成更新。

### 鸿蒙端开发环境
1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) 5.0+（建议 NEXT 版本）
2. HarmonyOS SDK API 12+
3. 真机：HarmonyOS NEXT 手机；可选：HUAWEI WATCH 系列（GT4 / Watch 4 及以上）
4. 打开 `harmony/` 目录，DevEco Studio 自动识别为 Stage 模型工程

### 跑 Demo（M1 完成后可用）
```bash
# 在 DevEco Studio 中
File -> Open -> 选择 pet_desk/harmony
点击右上角 Run -> 选择真机或模拟器
```

## 🗺 路线图（摘要）

| 阶段 | 周期 | 交付物 |
|---|---|---|
| **M0 · 项目奠基** | 1 周 ✅ | 文档、骨架、技术调研 |
| **M1 · 桌面宠物 MVP** | 2~3 周 | 3 种预设宠物 + 照片换肤 + 基本动画 + App 内展示 |
| **M2 · 互动与作息** | 2 周 | 5+ 互动行为，时间表调度 |
| **M3 · 跨端与手表** | 3 周 | 服务卡片、锁屏实况窗、华为手表心情触发 |
| **M4 · AI 真 3D & 桌面端** | 4 周+ | 接入 Tripo/Hunyuan3D，Electron 桌面端 |

详见 [docs/ROADMAP.md](./docs/ROADMAP.md)。

## 🤝 参与贡献

目前是单人项目阶段，欢迎 issue 提想法。MVP 跑通后会开放 PR。

## 📜 License

MIT © PetDesk Contributors
