# Luna 桌面壳层（Zig）

本目录实现 **Explorer 等价物** 的状态机与几何布局（任务栏、开始菜单、桌面图标、脏区提示）。像素合成由 [compositor.zig](compositor.zig) + [surface.zig](surface.zig) 完成；PNG 由 [png_lite.zig](png_lite.zig) 解码并缓存在 [resource_cache.zig](resource_cache.zig)。

## 宿主绘制契约

- **参考实现**：`RgbaSurface`（[surface.zig](surface.zig)）— RGBA8888 顶向下，`fillRect` / `blitStretch` / `blitCopy`。
- **帧合成入口**：`compositor.composeFrame(pixels, width, height)` 或根模块 `composeDesktopFrame`。
- **主题根路径**：`ShellConfig.setThemeRoot("…/src/desktop/luna")`，用于解析 `resources.zig` 中的相对 PNG 路径。
- **启动前**：在宿主侧调用 `initCompositor(allocator)`；结束 `deinitCompositor()`。

## ShellEvent 与 Win32 消息（对照表）

| ShellEvent | 典型 Win32 来源 | 说明 |
|------------|-----------------|------|
| `mouse_move` | `WM_MOUSEMOVE` | `param1=x`, `param2=y`（客户区或屏幕坐标，需与宿主一致） |
| `mouse_left_down` | `WM_LBUTTONDOWN` | 同上 |
| `mouse_left_up` | `WM_LBUTTONUP` | |
| `mouse_right_down` | `WM_RBUTTONDOWN` | 桌面右键菜单 |
| `mouse_double_click` | `WM_LBUTTONDBLCLK` | 打开图标目标 |
| `key_down` | `WM_KEYDOWN` | `param1 = vk & 0xFF`（简化）；开始菜单：`VK_ESCAPE`/`VK_RETURN`/方向键 |
| `key_up` | `WM_KEYUP` | |
| `timer_tick` | `WM_TIMER` | 时钟等 |
| `window_created` | 应用创建顶层窗 | `host_abi.hwndFromParams` |
| `window_destroyed` | `WM_DESTROY` / 壳层跟踪 | |
| `window_activated` | `WM_ACTIVATE` | |
| `user_logoff` / `shutdown_requested` | 开始菜单 / `ExitWindowsEx` 语义 | |

托盘、任务栏按钮的 **自定义消息**（如 `TrayNotify`）尚未绑定 Win32；见 [shell_model.zig](shell_model.zig)。

## 进程启动

- `shell.launchTarget(path)`：若已 `setLaunchCallback`，则调用宿主；否则 `std.log` 占位。
- 根导出：`setShellLaunchCallback`。

## 与内核 `luna_desktop.zig` 的关系

| 能力 | 用户态（本目录） | 内核 `src/kernel/gui/luna_desktop.zig` |
|------|------------------|----------------------------------------|
| 壁纸 | `compositor.paintWallpaper` + PNG 拉伸 | 嵌入 `wallpaper_bliss_320x180.rgba`（脚本生成），`fb.blitRgbaStretch` 铺满工作区 |
| 开始菜单 | `startmenu.zig` + `compositor.paintStartMenu` + 宿主字体/PNG | `kstart_menu.zig`：简化双栏、顶栏、底栏，8×8 点阵字 |
| 光标 | `resources/cursors/*.png` + `paintCursorOverlay` | 嵌入 `cursor_arrow.rgba`，热点 (1,1) |
| 合成 | 单层 RGBA 缓冲 | 可选双缓冲（PMM 后景 + `blitFullScreen`） |

运行 `KERNEL_DESKTOP=luna` 时走的是 **内核列**；`zig build` 后的 `main` / `composeDesktopFrame` 走的是 **用户态列**。二者视觉对齐依赖同一套 `gen_luna_resources.py` 产出的 PNG/RGBA。

**性能**：内核路径每帧整帧 blit 到显存；若分辨率很高且需省电，可后续做任务栏/菜单/光标的脏矩形，仅拷贝变化区域（当前未实现）。
