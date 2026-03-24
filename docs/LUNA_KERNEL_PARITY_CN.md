# 宿主 Luna 与内核 Luna 能力对照（分阶段移植）

| 能力 | 宿主 `src/desktop/luna/` | 内核 `src/kernel/gui/` | 备注 |
|------|--------------------------|-------------------------|------|
| 壁纸 | BMP/PNG、拉伸/纯色 | 嵌入 RGBA 拉伸 | 内核可后续读配置路径 |
| 桌面图标 | 多图标、选中框、右键菜单 | 固定列表 + 选中 | 对齐 `desktop.zig` 行为 |
| 任务栏渐变 + 时钟 | 有 | 有（简化） | |
| 开始菜单两栏 | 有 | 简化 `kstart_menu` | 数据驱动见 `startmenu_data.zig` |
| 快速启动 | `shell_model` + taskbar | 无 | |
| 通知区 | `TrayNotify` / taskbar | 无 | |
| Shell 窗口装饰 | `window_decorator` + 合成 | 无 | 依赖用户态窗口 |
| 事件队列 | `shell.postEvent` / `dispatchPending` | 主循环内联 | 对齐 `input_event.zig` |
| 双缓冲 | 宿主像素缓冲 + `render` 脏区 | PMM 后景 + `fb_map` | |
| 登录 / 注销 | `winlogon` + `shell` 状态机 | 无 | |

**阶段建议**：先稳定宿主协议（HAL + `ShellEvent`），再将子集搬到内核或独立 Shell 进程。
