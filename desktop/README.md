# PetDesk Desktop (Phase 2)

> Electron + React + Three.js 桌面常驻宠物. **当前为占位目录**, 等鸿蒙端 M3 完成后启动.

## 计划技术栈

| 层 | 选型 |
|---|---|
| Shell | Electron (透明窗口、always-on-top、点击穿透切换) |
| UI | React + Tailwind |
| 3D | Three.js + react-three-fiber + drei |
| 状态同步 | 与鸿蒙 App 共享同一份 SkinProfile (走华为账号 / WebSocket 中继) |

## 目录约定

```
desktop/
├── src/
│   ├── main/         # Electron 主进程
│   ├── renderer/     # React 渲染端
│   └── assets/models # 复用 shared/ 中的 glTF
└── public/
```

## M4 启动时
```bash
npm create electron-vite@latest .
npm install three @react-three/fiber @react-three/drei
```
