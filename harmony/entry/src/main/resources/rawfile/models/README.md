# 3D 模型存放目录

`PetSceneController` 找不到对应 .glb 时会平滑回退到 emoji 占位 (App 不闪退).
补充模型后自动切换到 3D 渲染.

## 推荐文件
- `shorthair_cat.glb`
- `longhair_cat.glb`
- `shiba.glb`
- `golden_retriever.glb`
- `border_collie.glb`
- `rabbit_lop.glb`
- `hamster.glb`

## 每个模型应包含的动画 clip

| clip 名 | 何时使用 |
|---|---|
| `idle` | 默认待机 |
| `walk` | 走动 |
| `sit` | 坐下 |
| `sleep` | 睡觉 |
| `eat` | 吃饭 (M2) |
| `play` | 玩耍 (M2) |
| `scratch` | 抓抓板 (M2) |
| `jump` | 开心跳跃 (M2) |
| `stretch` | 伸懒腰 (M2) |
| `sunbathe` | 晒太阳 (M2) |

clip 名称在 `features/pet3d/ModelRegistry.ets` 中通过 `DEFAULT_ANIMS` 映射到 `PetAction`,
若你的美术资源使用其它命名, 改 ModelRegistry 即可, 业务代码不用动.

## UV 划分约定 (用于 Photo2Skin 换肤)

- 主色区 (身体大面积): UV 0 通道
- 副色区 (肚皮/胸口/手脚末端): UV 1 通道
- 鼻子/眼睛: 单独子材质

## 推荐来源
- Sketchfab CC0 / CC-BY (二次加工)
- 自家美术或在 Blender 里调通用模型
- AI 工具 (Hunyuan3D / Tripo) 生成基础模型再人工修
