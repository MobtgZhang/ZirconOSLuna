# 桌面管理器与 NT 5.2 / Windows XP x64 对应关系

本文档固定 **ZirconOSLuna 宿主 Luna** 中各模块与 Windows Server 2003 / **Windows XP Professional x64**（内核 NT 5.2，`_WIN32_WINNT` 0x0502）概念的映射，便于与 ReactOS `explorer` / `winlogon` 对照。

## 分层对照

| 本仓库模块 | NT 5.2 / Shell 概念 | 职责摘要 |
|------------|---------------------|----------|
| [winlogon.zig](../src/desktop/luna/winlogon.zig) | `winlogon.exe` | 会话状态、凭据、注销/关机占位。 |
| [shell.zig](../src/desktop/luna/shell.zig) | `explorer.exe`（Shell 主循环） | 登录后协调桌面、任务栏、开始菜单、窗口列表；**事件队列**与 `dispatch`。 |
| [desktop.zig](../src/desktop/luna/desktop.zig) | 桌面文件夹 + `Progman` 侧逻辑 | 壁纸、图标、右键菜单模型。 |
| [taskbar.zig](../src/desktop/luna/taskbar.zig) | 任务栏、`ITaskbarList` 思想 | 开始按钮、快速启动、任务按钮、通知区、时钟。 |
| [startmenu.zig](../src/desktop/luna/startmenu.zig) | 开始菜单 UI | 两栏菜单、高亮、键盘导航。 |
| [compositor.zig](../src/desktop/luna/compositor.zig) | User 态合成（非 XP DWM） | 软件 RGBA 合成；**绘制顺序**与 `hitTestAt` **逆序**一致。 |
| [render.zig](../src/desktop/luna/render.zig) | 脏区 / `InvalidateRect` 聚合 | 全屏或矩形失效、`RenderLayer` 提示。 |
| [window_decorator.zig](../src/desktop/luna/window_decorator.zig) | `uxtheme` + 非客户区 | 标题栏、边框、系统菜单模型、命中测试。 |
| [shell_model.zig](../src/desktop/luna/shell_model.zig) | Shell 命名空间占位 | 已知文件夹、快速启动种子、托盘扩展点。 |
| [host_abi.zig](../src/desktop/luna/host_abi.zig) | LLP64 Win32 | `HWND` 等 64 位句柄与 `param1`/`param2` 拆分约定。 |

## 与「内核 Luna」的边界

- **内核** [luna_desktop.zig](../src/kernel/gui/luna_desktop.zig)：freestanding 帧缓冲上的极简壳，**不是**完整 Win32k。
- 将来若引入用户态 Shell 进程，显示路径应对齐 [display_hal.zig](../src/desktop/luna/display_hal.zig) 与 [input_event.zig](../src/desktop/luna/input_event.zig)。

## 命中测试顺序（与合成层逆序）

自顶向下（先命中者赢）：**光标 → 叠加层（右键菜单等）→ 开始菜单 → Shell 窗口（Z 序大者在上）→ 任务栏 → 桌面图标 → 壁纸区**。

实现见 [compositor.zig](../src/desktop/luna/compositor.zig) 的 `hitTestAt`。
