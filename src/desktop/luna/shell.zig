//! Shell - ZirconOS Luna Desktop Shell (explorer.exe equivalent)
//! Main entry point for the desktop environment. Coordinates
//! login, desktop, taskbar, start menu, and window management.
//! Reference: ReactOS explorer (base/shell/explorer/)

const std = @import("std");
const theme = @import("theme.zig");
const render = @import("render.zig");
const host_abi = @import("host_abi.zig");
const winlogon = @import("winlogon.zig");
const desktop = @import("desktop.zig");
const taskbar = @import("taskbar.zig");
const startmenu = @import("startmenu.zig");
const window_decorator = @import("window_decorator.zig");
const controls = @import("controls.zig");
const shell_model = @import("shell_model.zig");
const surface_mod = @import("surface.zig");
const user_profile = @import("user_profile.zig");
const luna_ini = @import("luna_ini.zig");
const resources = @import("resources.zig");

// ── Shell State ──

pub const ShellState = enum(u8) {
    not_started = 0,
    initializing = 1,
    login_screen = 2,
    loading_desktop = 3,
    desktop_active = 4,
    locking = 5,
    locked = 6,
    logging_off = 7,
    shutting_down = 8,
};

pub const ShellEvent = enum(u8) {
    none = 0,
    mouse_move = 1,
    mouse_left_down = 2,
    mouse_left_up = 3,
    mouse_right_down = 4,
    mouse_right_up = 5,
    mouse_double_click = 6,
    key_down = 7,
    key_up = 8,
    timer_tick = 9,
    window_created = 10,
    window_destroyed = 11,
    window_activated = 12,
    user_logon = 13,
    user_logoff = 14,
    start_menu_toggle = 15,
    shutdown_requested = 16,
};

pub const ShellConfig = struct {
    screen_width: i32 = 800,
    screen_height: i32 = 600,
    color_depth: u32 = 32,
    color_scheme: theme.ColorScheme = .blue,
    auto_logon: bool = false,
    auto_logon_user: [64]u8 = [_]u8{0} ** 64,
    auto_logon_user_len: usize = 0,
    /// UTF-8 path to Luna theme root (`src/desktop/luna`), for loading `resources/...` PNGs.
    theme_root: [512]u8 = [_]u8{0} ** 512,
    theme_root_len: usize = 0,

    pub fn setThemeRoot(self: *ShellConfig, path: []const u8) void {
        const n = @min(path.len, self.theme_root.len);
        @memcpy(self.theme_root[0..n], path[0..n]);
        self.theme_root_len = n;
    }
};

// ── Open Window Tracking ──

pub const MAX_SHELL_WINDOWS: usize = 32;

pub const ShellWindow = struct {
    hwnd: u64 = 0,
    chrome: window_decorator.WindowChrome = .{},
    is_active: bool = false,
    z_order: u32 = 0,

    pub fn getTitle(self: *const ShellWindow) []const u8 {
        return self.chrome.getTitle();
    }
};

/// 桌面命中（与 [compositor.zig](compositor.zig) `hitTestAt` 一致）；定义在 shell 以避免与 compositor 循环引用。
pub const DesktopHitPick = struct {
    pub const Kind = enum {
        none,
        shell_window,
        start_menu,
        task_start,
        task_quick_launch,
        task_button,
        tray_icon,
        context_menu,
        desktop_icon,
    };
    kind: Kind = .none,
    index: usize = 0,
    hwnd: u64 = 0,
};

// ── Global State ──

var shell_state: ShellState = .not_started;
var config: ShellConfig = .{};

var shell_windows: [MAX_SHELL_WINDOWS]ShellWindow = [_]ShellWindow{.{}} ** MAX_SHELL_WINDOWS;
var window_count: usize = 0;
var active_window_index: i32 = -1;
var next_z_order: u32 = 1;

var mouse_x: i32 = 0;
var mouse_y: i32 = 0;
var shell_tick_count: u64 = 0;
var shell_initialized: bool = false;

var cursor_busy: bool = false;
pub var launch_callback: ?*const fn ([]const u8) void = null;

const EVENT_QUEUE_CAP: usize = 256;
const QueuedEvent = struct { e: ShellEvent, p1: i32, p2: i32 };
var event_queue: [EVENT_QUEUE_CAP]QueuedEvent = undefined;
var event_q_head: usize = 0;
var event_q_tail: usize = 0;

pub fn postEvent(event: ShellEvent, param1: i32, param2: i32) bool {
    const next = (event_q_tail + 1) % EVENT_QUEUE_CAP;
    if (next == event_q_head) return false;
    event_queue[event_q_tail] = .{ .e = event, .p1 = param1, .p2 = param2 };
    event_q_tail = next;
    return true;
}

pub fn dispatchPendingEvents() void {
    while (event_q_head != event_q_tail) {
        const qe = event_queue[event_q_head];
        event_q_head = (event_q_head + 1) % EVENT_QUEUE_CAP;
        dispatchEventDirect(qe.e, qe.p1, qe.p2);
    }
}

fn installQuickLaunchFromModel() void {
    taskbar.clearQuickLaunch();
    for (shell_model.default_quick_launch) |seed| {
        taskbar.addQuickLaunchItem(seed.name, seed.target, 0);
    }
    taskbar.relayout();
}

fn registerTrayNotifyDefaults() void {
    _ = shell_model.trayNotifyRegister(.{ .id = 1, .icon_rel_path = "resources/icons/tray/icon_tray_volume.png", .tooltip = "Volume" });
    _ = shell_model.trayNotifyRegister(.{ .id = 2, .icon_rel_path = "resources/icons/tray/icon_tray_network.png", .tooltip = "Network" });
    _ = shell_model.trayNotifyRegister(.{ .id = 3, .icon_rel_path = resources.icons.user_default, .tooltip = "ZirconOS" });
}

// ── Shell Lifecycle ──

pub fn start(cfg: ShellConfig) void {
    var merged = cfg;
    if (std.fs.cwd().openFile("luna.ini", .{})) |f| {
        defer f.close();
        const txt = f.readToEndAlloc(std.heap.page_allocator, 64 * 1024) catch null;
        if (txt) |t| {
            defer std.heap.page_allocator.free(t);
            const parsed = luna_ini.parse(t);
            if (parsed.auto_logon) |v| merged.auto_logon = v;
            if (parsed.auto_logon_user_len > 0) {
                const n = @min(parsed.auto_logon_user_len, merged.auto_logon_user.len);
                @memcpy(merged.auto_logon_user[0..n], parsed.auto_logon_user[0..n]);
                merged.auto_logon_user_len = n;
            }
        }
    } else |_| {}

    config = merged;
    shell_state = .initializing;

    render.init(config.screen_width, config.screen_height);

    theme.init();
    theme.setColorScheme(cfg.color_scheme);

    winlogon.init();
    desktop.init();
    taskbar.init();
    startmenu.init();
    window_decorator.init();
    controls.init();

    installQuickLaunchFromModel();
    registerTrayNotifyDefaults();

    desktop.setDesktopSize(config.screen_width, config.screen_height);
    taskbar.setScreenSize(config.screen_width, config.screen_height);

    if (cfg.auto_logon and cfg.auto_logon_user_len > 0) {
        performAutoLogon();
    } else {
        shell_state = .login_screen;
    }

    shell_initialized = true;
}

fn performAutoLogon() void {
    const name = config.auto_logon_user[0..config.auto_logon_user_len];
    const result = winlogon.authenticate(name, "");
    if (result == .success) {
        transitionToDesktop();
    } else {
        shell_state = .login_screen;
    }
}

fn transitionToDesktop() void {
    shell_state = .loading_desktop;

    startmenu.setUserInfo(winlogon.getCurrentUsername(), 0);
    user_profile.setActiveUsername(winlogon.getCurrentUsername());

    shell_state = .desktop_active;
}

// ── Event Handling ──

fn dispatchEventDirect(event: ShellEvent, param1: i32, param2: i32) void {
    shell_tick_count += 1;

    switch (shell_state) {
        .login_screen => handleLoginEvent(event, param1, param2),
        .desktop_active, .shutting_down, .logging_off => handleDesktopEvent(event, param1, param2),
        .locked => handleLockedEvent(event, param1, param2),
        else => {},
    }
}

pub fn handleEvent(event: ShellEvent, param1: i32, param2: i32) void {
    _ = postEvent(event, param1, param2);
    dispatchPendingEvents();
}

fn handleLoginEvent(event: ShellEvent, param1: i32, _: i32) void {
    switch (event) {
        .mouse_left_down => {},
        .key_down => {
            const key: u8 = @intCast(param1 & 0xFF);
            if (key == 0x0D) {
                const result = winlogon.submitPassword("");
                if (result == .success) {
                    transitionToDesktop();
                }
            }
        },
        .user_logon => transitionToDesktop(),
        else => {},
    }
}

fn handleDesktopEvent(event: ShellEvent, param1: i32, param2: i32) void {
    switch (event) {
        .mouse_move => {
            mouse_x = param1;
            mouse_y = param2;
            if (startmenu.isOpen()) {
                _ = startmenu.hitTestItem(param1, param2);
            }
        },
        .mouse_left_down => {
            const mx = param1;
            const my = param2;

            if (desktop.getContextMenu().is_visible) {
                if (desktop.hitTestContextMenuItem(mx, my)) |cmd| {
                    handleContextCommand(cmd);
                }
                desktop.hideContextMenu();
                render.invalidateDesktopArea();
            }

            if (startmenu.isOpen()) {
                const rect = startmenu.getMenuRect();
                if (mx < rect.x or mx >= rect.x + rect.w or
                    my < rect.y or my >= rect.y + rect.h)
                {
                    startmenu.closeMenu();
                    taskbar.setStartButtonState(.normal);
                } else {
                    if (startmenu.hitTestFooter(mx, my)) |fb| {
                        switch (fb) {
                            .log_off => logoff(),
                            .shut_down => beginShutdown(),
                        }
                        startmenu.closeMenu();
                        taskbar.setStartButtonState(.normal);
                        return;
                    }
                    if (startmenu.activateHitItem(mx, my)) |path| {
                        launchTarget(path);
                        startmenu.closeMenu();
                        taskbar.setStartButtonState(.normal);
                        return;
                    }
                }
            }

            if (hitTestShellWindow(mx, my)) |hwnd| {
                handleShellWindowMouse(mx, my, hwnd);
                return;
            }

            const sb = taskbar.getStartButton();
            if (sb.hitTest(mx, my)) {
                taskbar.toggleStartMenu();
                if (taskbar.isStartMenuOpen()) {
                    startmenu.openMenu(0, taskbar.getTaskbarY());
                } else {
                    startmenu.closeMenu();
                }
                return;
            }

            if (taskbar.hitTestQuickLaunch(mx, my)) |qli| {
                if (taskbar.getQuickLaunchPath(qli)) |p| {
                    launchTarget(p);
                }
                return;
            }

            if (taskbar.hitTestTaskHwnd(mx, my)) |hwnd| {
                if (restoreIfMinimized(hwnd)) {
                    render.invalidateFull();
                    return;
                }
                activateWindow(hwnd);
                taskbar.setActiveTask(hwnd);
                render.invalidateFull();
                return;
            }

            if (taskbar.hitTestTrayIcon(mx, my)) |_| {
                return;
            }

            if (desktop.hitTestIcon(mx, my)) |idx| {
                desktop.selectIcon(idx);
                return;
            }

            desktop.deselectAll();
        },
        .mouse_right_down => {
            if (!startmenu.isOpen()) {
                desktop.showContextMenu(param1, param2);
            }
        },
        .mouse_double_click => {
            if (desktop.hitTestIcon(param1, param2)) |idx| {
                if (desktop.getIcon(idx)) |ic| {
                    launchTarget(ic.getTargetPath());
                }
            }
        },
        .key_down => {
            const key: u8 = @intCast(param1 & 0xFF);
            if (key == 0x20 and param2 != 0) {
                if (getActiveWindow()) |aw| {
                    if (findWindowMut(aw.hwnd)) |w| {
                        w.chrome.system_menu_visible = !w.chrome.system_menu_visible;
                        render.invalidateFull();
                    }
                }
            }
            if (startmenu.isOpen()) {
                switch (key) {
                    0x1B => {
                        startmenu.closeMenu();
                        taskbar.setStartButtonState(.normal);
                    },
                    0x0D => {
                        if (startmenu.activateHighlighted()) |path| {
                            launchTarget(path);
                            startmenu.closeMenu();
                            taskbar.setStartButtonState(.normal);
                        }
                    },
                    else => {
                        if (key == 0x26) startmenu.moveMenuHighlight(-1);
                        if (key == 0x28) startmenu.moveMenuHighlight(1);
                    },
                }
            } else if (key == 0x5B or key == 0x5C) {
                taskbar.toggleStartMenu();
                if (taskbar.isStartMenuOpen()) {
                    startmenu.openMenu(0, taskbar.getTaskbarY());
                } else {
                    startmenu.closeMenu();
                }
            }
        },
        .timer_tick => {
            const tick = @as(u32, @intCast(shell_tick_count & 0xFFFFFFFF));
            const seconds = tick % 60;
            const minutes = (tick / 60) % 60;
            const hours = (tick / 3600) % 24;
            taskbar.updateClock(@intCast(hours), @intCast(minutes), @intCast(seconds));
        },
        .window_created => {
            const hwnd = host_abi.hwndFromParams(param1, param2);
            _ = registerWindow(hwnd, "New Window");
            _ = taskbar.addTaskButton(hwnd, "New Window", 0);
            render.invalidateFull();
        },
        .window_destroyed => {
            const hwnd = host_abi.hwndFromParams(param1, param2);
            _ = taskbar.removeTaskButton(hwnd);
            removeWindow(hwnd);
            render.invalidateFull();
        },
        .window_activated => {
            const hwnd = host_abi.hwndFromParams(param1, param2);
            taskbar.setActiveTask(hwnd);
            activateWindow(hwnd);
            render.invalidateFull();
        },
        .start_menu_toggle => {
            taskbar.toggleStartMenu();
            if (taskbar.isStartMenuOpen()) {
                startmenu.openMenu(0, taskbar.getTaskbarY());
            } else {
                startmenu.closeMenu();
            }
        },
        .user_logoff => logoff(),
        .shutdown_requested => beginShutdown(),
        else => {},
    }
}

fn handleLockedEvent(event: ShellEvent, param1: i32, _: i32) void {
    switch (event) {
        .key_down => {
            const key: u8 = @intCast(param1 & 0xFF);
            if (key == 0x0D) {
                const result = winlogon.unlockWorkstation("");
                if (result == .success) {
                    shell_state = .desktop_active;
                }
            }
        },
        else => {},
    }
}

// ── Window Management ──

fn findWindowMut(hwnd: u64) ?*ShellWindow {
    for (shell_windows[0..window_count]) |*w| {
        if (w.hwnd == hwnd) return w;
    }
    return null;
}

pub fn hitTestShellWindow(mx: i32, my: i32) ?u64 {
    var best: u64 = 0;
    var best_z: u32 = 0;
    for (shell_windows[0..window_count]) |*win| {
        if (win.hwnd == 0 or win.chrome.is_minimized) continue;
        const ht = window_decorator.hitTestFrame(&win.chrome, mx, my);
        if (ht != .nowhere and win.z_order >= best_z) {
            best_z = win.z_order;
            best = win.hwnd;
        }
    }
    return if (best == 0) null else best;
}

pub fn desktopHitPick(mx: i32, my: i32) DesktopHitPick {
    if (shell_state != .desktop_active) return .{};

    const cm = desktop.getContextMenu();
    if (cm.is_visible) {
        const w: i32 = 180;
        var total_h: i32 = 0;
        for (cm.items[0..cm.item_count]) |it| {
            if (it.item_type == .separator) total_h += 4 else total_h += theme.MENU_ITEM_HEIGHT;
        }
        if (mx >= cm.x and mx < cm.x + w and my >= cm.y and my < cm.y + total_h + 4) {
            return .{ .kind = .context_menu };
        }
    }

    if (startmenu.isOpen()) {
        const r = startmenu.getMenuRect();
        if (mx >= r.x and mx < r.x + r.w and my >= r.y and my < r.y + r.h) {
            return .{ .kind = .start_menu };
        }
    }

    if (hitTestShellWindow(mx, my)) |hw| {
        return .{ .kind = .shell_window, .hwnd = hw };
    }

    const sb = taskbar.getStartButton();
    if (sb.hitTest(mx, my)) return .{ .kind = .task_start };

    if (taskbar.hitTestQuickLaunch(mx, my)) |q| {
        return .{ .kind = .task_quick_launch, .index = q };
    }

    if (taskbar.hitTestTaskHwnd(mx, my)) |hwnd| {
        return .{ .kind = .task_button, .hwnd = hwnd };
    }

    if (taskbar.hitTestTrayIcon(mx, my)) |ti| {
        return .{ .kind = .tray_icon, .index = ti };
    }

    if (desktop.hitTestIcon(mx, my)) |idx| {
        return .{ .kind = .desktop_icon, .index = idx };
    }

    return .{};
}

fn handleShellWindowMouse(mx: i32, my: i32, hwnd: u64) void {
    const win = findWindowMut(hwnd) orelse return;
    const ht = window_decorator.hitTestFrame(&win.chrome, mx, my);
    switch (ht) {
        .close_button => {
            _ = taskbar.removeTaskButton(hwnd);
            removeWindow(hwnd);
        },
        .minimize_button => {
            win.chrome.is_minimized = true;
            taskbar.setTaskButtonMinimized(hwnd, true);
        },
        else => {
            activateWindow(hwnd);
            taskbar.setActiveTask(hwnd);
        },
    }
    render.invalidateFull();
}

pub fn restoreIfMinimized(hwnd: u64) bool {
    const win = findWindowMut(hwnd) orelse return false;
    if (!win.chrome.is_minimized) return false;
    win.chrome.is_minimized = false;
    taskbar.setTaskButtonMinimized(hwnd, false);
    activateWindow(hwnd);
    taskbar.setActiveTask(hwnd);
    return true;
}

pub fn paintShellWindowsToSurface(s: *surface_mod.RgbaSurface) void {
    var idxs: [MAX_SHELL_WINDOWS]usize = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < window_count) : (i += 1) {
        if (shell_windows[i].hwnd == 0) continue;
        if (shell_windows[i].chrome.is_minimized) continue;
        idxs[n] = i;
        n += 1;
    }
    var c: usize = 1;
    while (c < n) : (c += 1) {
        var j = c;
        while (j > 0 and shell_windows[idxs[j - 1]].z_order > shell_windows[idxs[j]].z_order) : (j -= 1) {
            std.mem.swap(usize, &idxs[j - 1], &idxs[j]);
        }
    }
    var k: usize = 0;
    while (k < n) : (k += 1) {
        window_decorator.drawChromeToSurface(s, &shell_windows[idxs[k]].chrome);
    }
}

pub fn registerWindow(hwnd: u64, title: []const u8) ?*ShellWindow {
    if (window_count >= MAX_SHELL_WINDOWS) return null;

    var win = &shell_windows[window_count];
    win.* = .{};
    win.hwnd = hwnd;
    win.chrome.hwnd = hwnd;
    win.chrome.setTitle(title);
    win.chrome.window_x = 100;
    win.chrome.window_y = 100;
    win.chrome.window_width = 480;
    win.chrome.window_height = 320;
    win.z_order = next_z_order;
    next_z_order += 1;

    window_decorator.layoutButtons(&win.chrome);

    window_count += 1;
    return win;
}

pub fn removeWindow(hwnd: u64) void {
    for (shell_windows[0..window_count]) |*win| {
        if (win.hwnd == hwnd) {
            win.hwnd = 0;
            return;
        }
    }
}

pub fn activateWindow(hwnd: u64) void {
    for (shell_windows[0..window_count], 0..) |*win, i| {
        if (win.hwnd == hwnd) {
            win.is_active = true;
            win.chrome.is_active = true;
            win.z_order = next_z_order;
            next_z_order += 1;
            active_window_index = @intCast(i);
        } else {
            win.is_active = false;
            win.chrome.is_active = false;
        }
    }
}

pub fn getActiveWindow() ?*const ShellWindow {
    if (active_window_index >= 0 and @as(usize, @intCast(active_window_index)) < window_count) {
        return &shell_windows[@intCast(active_window_index)];
    }
    return null;
}

pub fn getWindowCount() usize {
    var count: usize = 0;
    for (shell_windows[0..window_count]) |*win| {
        if (win.hwnd != 0) count += 1;
    }
    return count;
}

// ── Session Control ──

pub fn logoff() void {
    shell_state = .logging_off;
    render.invalidateFull();
    startmenu.closeMenu();
    taskbar.setStartButtonState(.normal);
    winlogon.logoff();
    window_count = 0;
    active_window_index = -1;
    shell_state = .login_screen;
}

pub fn lockWorkstation() void {
    shell_state = .locking;
    startmenu.closeMenu();
    winlogon.lockWorkstation();
    shell_state = .locked;
}

pub fn beginShutdown() void {
    shell_state = .shutting_down;
    startmenu.closeMenu();
    winlogon.shutdown(.shutdown);
    render.invalidateFull();
}

pub fn setShellStateIfInitialized(st: ShellState) void {
    if (shell_initialized) shell_state = st;
}

pub fn trayNotifyAdd(id: u32, owner: u64, icon_id: u32, tooltip: []const u8) bool {
    _ = shell_model.trayNotifyRegister(.{ .id = id, .icon_rel_path = "", .tooltip = tooltip });
    return taskbar.addTrayIcon(id, owner, icon_id, tooltip);
}

pub fn trayNotifyRemove(id: u32) void {
    shell_model.trayNotifyUnregister(id);
    _ = taskbar.removeTrayIcon(id);
    render.invalidateLayer(.taskbar);
}

// ── State Query ──

pub fn getShellState() ShellState {
    return shell_state;
}

pub fn isDesktopActive() bool {
    return shell_state == .desktop_active;
}

pub fn isLoginScreen() bool {
    return shell_state == .login_screen;
}

pub fn getMousePosition() struct { x: i32, y: i32 } {
    return .{ .x = mouse_x, .y = mouse_y };
}

pub fn getConfig() *const ShellConfig {
    return &config;
}

pub fn getThemeRoot() []const u8 {
    return config.theme_root[0..config.theme_root_len];
}

pub fn setCursorBusy(busy: bool) void {
    cursor_busy = busy;
}

pub fn isCursorBusy() bool {
    return cursor_busy;
}

pub fn setLaunchCallback(cb: ?*const fn ([]const u8) void) void {
    launch_callback = cb;
}

pub fn launchTarget(path: []const u8) void {
    if (launch_callback) |cb| {
        cb(path);
    } else {
        std.log.info("shell.launchTarget: {s}", .{path});
    }
}

pub fn getTickCount() u64 {
    return shell_tick_count;
}

fn handleContextCommand(cmd: u32) void {
    switch (cmd) {
        101 => shell_model.desktopHostBumpRefresh(),
        102 => launchTarget("shell:paste"),
        120 => launchTarget("shell:desk_props"),
        130 => launchTarget("shell:display_props"),
        140 => launchTarget("shell:run"),
        else => {},
    }
    render.invalidateDesktopArea();
}

// ── Login Helpers ──

pub fn selectLoginUser(index: u32) winlogon.AuthResult {
    return winlogon.beginLogon(index);
}

pub fn submitLoginPassword(password: []const u8) winlogon.AuthResult {
    const result = winlogon.submitPassword(password);
    if (result == .success) {
        transitionToDesktop();
    }
    return result;
}

// ── Initialization ──

pub fn init() void {
    shell_state = .not_started;
    window_count = 0;
    active_window_index = -1;
    next_z_order = 1;
    mouse_x = 0;
    mouse_y = 0;
    shell_tick_count = 0;
    shell_initialized = false;
}
