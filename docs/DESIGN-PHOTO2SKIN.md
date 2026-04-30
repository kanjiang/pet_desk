# Photo2Skin · 照片 → 宠物外观

## 目标

把用户的 1~5 张宠物照片，**在本地、几秒内**转化为可以套到预设 3D 模型上的"皮肤"（PBR 贴图 + 颜色参数）。

## 阶段策略

| 阶段 | 方案 | 处理时长 | 效果 |
|---|---|---|---|
| M1 | 本地颜色提取 + 模板换肤 | < 3s | 颜色像就够了 |
| M2 | + 简单花纹遮罩（虎斑/奶牛色） | < 5s | 能看出"是只橘猫"还是"奶牛猫" |
| M4 | 云端 AI 真 3D 重建 | 30s ~ 2min | 真的是它本猫 |

---

## M1 算法（本地，纯 ArkTS + ImageKit）

### 流程

```
[原图 URI] → [fileIo 读 ArrayBuffer] → [ImageSource → PixelMap 96x96 RGBA_8888]
           → [中心 60% 区域采样 + 背景启发式过滤]
           → [K-means k=4]
           → [主色板 4 色: primary/secondary/nose/eyes]
           → [写入 SkinProfile]
           → [SkinRepo.save → Preferences + AppStorage publish]
           → [PetRenderer 自动响应换色]
```

### 像素格式坑

`image.createPixelMap` 默认 **BGRA_8888**, 会导致颜色翻转(红蓝互换)。
解决: 显式 `desiredPixelFormat: image.PixelMapFormat.RGBA_8888`.

### 背景启发式过滤

`shouldSkip` 跳过这几类常见污染:
- 接近纯白 (rgb 全部 > 235): 墙、相纸
- 接近纯黑 (rgb 全部 < 18): 阴影、镜头黑边
- 低饱和高亮度 (sat < 0.08 且 max > 200): 灰背景

这能避免"主色被中性色挤掉" - 否则黑猫被识别成深灰。

### 数据结构

```typescript
export interface SkinProfile {
  petId: string;
  petName: string;
  baseModelId: BaseModelId;
  palette: { primary; secondary; nose; eyes };
  patternMaskUri?: string;
  sourcePhotos: string[];
  createdAt: number;
  updatedAt: number;
}
```

---

## M2 增强：花纹遮罩

虎斑/奶牛色仅靠主色还原差别大. 方案:
1. LAB 通道方差找"高对比"区域
2. 二值化得 mask
3. 投到模型 UV 空间 (仿射对齐预设 UV 模板)
4. fragment shader: `mix(primary, secondary, mask)`

不追求精准对应，但"虎斑感"出来就够。

---

## M4 真 3D 重建（云端）

| 服务 | 优点 | 缺点 |
|---|---|---|
| Tripo SR | 免费可自部署 | 质量中等 |
| Hunyuan3D | 中文友好 | 需企业账号 |
| Meshy.ai | 质量稳 | 收费 |
| Rodin | 角色重建强 | 主打数字人 |

流程: 用户授权 → 上传 1~2 张照片 → 调云端 3D API → 自动绑骨 → 下载 glTF → idle/walk/sit/sleep retarget. 失败回退 M1 换肤.

隐私: 照片不长期存储,处理完即删.

---

## 模块文件规划

```
features/photo2skin/
├── ColorExtractor.ets       # K-means
├── PixelSampler.ets         # URI -> PixelMap -> RgbColor[]
├── Photo2SkinService.ets    # 编排器
├── PatternExtractor.ets     # M2: 花纹遮罩
└── CloudReconstructor.ets   # M4: 云端真 3D
```

## 验收标准（M1）

- [x] 上传一张橘猫 → 主色橘色
- [x] 上传一张黑猫 → 主色黑色
- [x] 上传一张二哈 → 主色黑白配色
- [x] 完整流程 < 3 秒
- [x] 失败有友好提示（不闪退）
