# 贡献指南

> 当前是单人原型阶段, 欢迎以 issue / 讨论形式提建议. M1 跑通后会开放 PR.

## 开发约定

### 鸿蒙端 (ArkTS)
- 所有业务模块放在 `harmony/entry/src/main/ets/features/<模块>/`
- 数据模型放在 `harmony/entry/src/main/ets/common/models/`
- UI 与渲染层只读订阅 `PetEngine`, **禁止直接改 PetState**
- 文件头用块注释说明文件职责
- 函数尽量小; 状态机分支用 switch + 默认 return 旧状态

### 文档
- 所有架构性变更必须更新 `docs/ARCHITECTURE.md`
- 新增模块在 `docs/` 下加同名 `DESIGN-<MODULE>.md`
- README 路线图与 `docs/ROADMAP.md` 保持一致

### 隐私
- 任何涉及"用户照片"或"健康数据"的代码必须在 PR 描述中说明数据流
- 默认本地处理, 上云必须显式开关

## 提交信息
约定式提交:
```
feat(pet3d): add idle->walk animation transition
fix(scheduler): avoid double tick after resume
docs(roadmap): mark M1 photo2skin done
```
