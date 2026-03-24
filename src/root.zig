//! ZirconOSLuna — Windows XP Luna 风格 Shell / 主题库。
//! 模块根为 `src/`，以包含 `config/`、`hal/`、`drivers/` 等与内核工程同名的目录。
//! 全栈说明见 `docs/KERNEL_AND_STACK_CN.md`、`docs/REPOSITORY_LAYOUT_CN.md`。

const std = @import("std");

pub const defaults = @import("config/defaults.zig");
pub const arch_abi = @import("arch/abi.zig");
pub const arch_x86_64 = @import("arch/x86_64/paging.zig");

pub const hal = struct {
    pub const framebuffer = @import("hal/framebuffer.zig");
    pub const timer = @import("hal/timer.zig");
    pub const irq = @import("hal/irq.zig");
};

pub const ke = struct {
    pub const irql = @import("ke/irql.zig");
    pub const sync = @import("ke/sync.zig");
    pub const dpc = @import("ke/dpc.zig");
};

pub const mm = struct {
    pub const va_layout = @import("mm/va_layout.zig");
    pub const pages = @import("mm/pages.zig");
};

pub const ob = struct {
    pub const types = @import("ob/types.zig");
    pub const handle = @import("ob/handle.zig");
};

pub const ps = struct {
    pub const ids = @import("ps/ids.zig");
    pub const state = @import("ps/state.zig");
};

pub const se = struct {
    pub const sid = @import("se/sid.zig");
    pub const access = @import("se/access.zig");
};

pub const io = struct {
    pub const irp = @import("io/irp.zig");
};

pub const lpc = struct {
    pub const port = @import("lpc/port.zig");
};

pub const loader = struct {
    pub const pe = @import("loader/pe.zig");
};

pub const rtl = @import("rtl/log.zig");
pub const win32 = @import("libs/win32/surface.zig");
pub const drivers = struct {
    pub const video = @import("drivers/video/display_manager.zig");
};

/// NT 5.2 产品线规范常量（非内核镜像）；见 `kernel/nt52/README.md`。
pub const kernel = struct {
    pub const nt52 = @import("kernel/nt52/spec.zig");
};

pub const nt_target = @import("desktop/luna/nt_target.zig");
pub const host_abi = @import("desktop/luna/host_abi.zig");
pub const theme = @import("desktop/luna/theme.zig");
pub const resources = @import("desktop/luna/resources.zig");
pub const render = @import("desktop/luna/render.zig");
pub const winlogon = @import("desktop/luna/winlogon.zig");
pub const desktop = @import("desktop/luna/desktop.zig");
pub const taskbar = @import("desktop/luna/taskbar.zig");
pub const startmenu = @import("desktop/luna/startmenu.zig");
pub const window_decorator = @import("desktop/luna/window_decorator.zig");
pub const shell = @import("desktop/luna/shell.zig");
pub const controls = @import("desktop/luna/controls.zig");
pub const compositor = @import("desktop/luna/compositor.zig");
pub const resource_cache = @import("desktop/luna/resource_cache.zig");
pub const shell_model = @import("desktop/luna/shell_model.zig");
pub const surface = @import("desktop/luna/surface.zig");
pub const shell_session = @import("desktop/luna/shell_session.zig");
pub const user_profile = @import("desktop/luna/user_profile.zig");
pub const luna_ini = @import("desktop/luna/luna_ini.zig");
pub const display_hal = @import("desktop/luna/display_hal.zig");
pub const input_event = @import("desktop/luna/input_event.zig");
pub const csrss_placeholder = @import("desktop/luna/csrss_placeholder.zig");

pub const ColorScheme = theme.ColorScheme;
pub const ThemeColors = theme.ThemeColors;
pub const COLORREF = theme.COLORREF;
pub const RGB = theme.RGB;

pub const ShellState = shell.ShellState;
pub const ShellEvent = shell.ShellEvent;
pub const ShellConfig = shell.ShellConfig;
pub const SessionState = winlogon.SessionState;
pub const AuthResult = winlogon.AuthResult;
pub const UserRole = winlogon.UserRole;

pub fn initLunaDesktop(cfg: ShellConfig) void {
    shell.start(cfg);
}

pub fn handleShellEvent(event: ShellEvent, param1: i32, param2: i32) void {
    shell.handleEvent(event, param1, param2);
}

pub fn getShellState() ShellState {
    return shell.getShellState();
}

pub fn isDesktopActive() bool {
    return shell.isDesktopActive();
}

pub fn isLoginScreen() bool {
    return shell.isLoginScreen();
}

pub fn getCurrentUsername() []const u8 {
    return winlogon.getCurrentUsername();
}

pub fn getThemeName() []const u8 {
    return theme.getThemeName();
}

pub fn setColorScheme(scheme: ColorScheme) void {
    theme.setColorScheme(scheme);
    desktop.setWallpaper(resources.wallpaperPathForScheme(scheme), .stretch);
}

pub fn logoff() void {
    shell.logoff();
}

pub fn lockWorkstation() void {
    shell.lockWorkstation();
}

pub fn shutdown() void {
    shell.beginShutdown();
}

pub fn selectLoginUser(index: u32) AuthResult {
    return shell.selectLoginUser(index);
}

pub fn submitLoginPassword(password: []const u8) AuthResult {
    return shell.submitLoginPassword(password);
}

pub fn getVersion() []const u8 {
    return "ZirconOS Luna Desktop v0.1.0";
}

pub fn initCompositor(allocator: std.mem.Allocator) void {
    resource_cache.init(allocator);
}

pub fn deinitCompositor() void {
    resource_cache.deinit();
}

pub fn composeDesktopFrame(pixels: []u8, width: u32, height: u32) void {
    compositor.composeFrame(pixels, width, height);
}

pub fn setShellLaunchCallback(cb: ?*const fn ([]const u8) void) void {
    shell.setLaunchCallback(cb);
}

test "luna compositor login screen pixel" {
    resource_cache.init(std.testing.allocator);
    defer resource_cache.deinit();
    shell.init();
    var cfg = ShellConfig{};
    cfg.setThemeRoot("src/desktop/luna");
    cfg.screen_width = 128;
    cfg.screen_height = 96;
    shell.start(cfg);
    var buf: [128 * 96 * 4]u8 = undefined;
    @memset(&buf, 0);
    compositor.composeFrame(&buf, 128, 96);
    try std.testing.expect(buf[0] != 0 or buf[1] != 0 or buf[2] != 0);
}

test "taskbar quick launch geometry" {
    taskbar.init();
    taskbar.setScreenSize(800, 600);
    taskbar.clearQuickLaunch();
    taskbar.addQuickLaunchItem("A", "shell:a", 0);
    taskbar.relayout();
    try std.testing.expect(taskbar.getQuickLaunchCellX(0) != null);
}

test "desktop default icon paths" {
    try std.testing.expectEqualStrings(
        "resources/icons/system/icon_mycomputer.png",
        desktop.defaultIconResourcePath(.my_computer),
    );
    try std.testing.expectEqualStrings(
        "resources/icons/system/icon_network.png",
        desktop.defaultIconResourcePath(.network_places),
    );
}

test "shell desktopHitPick start button" {
    shell.init();
    defer shell.init();
    var cfg = ShellConfig{};
    cfg.screen_width = 800;
    cfg.screen_height = 600;
    cfg.setThemeRoot("src/desktop/luna");
    cfg.auto_logon = true;
    cfg.auto_logon_user_len = 4;
    @memcpy(cfg.auto_logon_user[0..4], "User");
    shell.start(cfg);
    const sb = taskbar.getStartButton();
    const pick = shell.desktopHitPick(sb.x + 2, sb.y + 2);
    try std.testing.expectEqual(shell.DesktopHitPick.Kind.task_start, pick.kind);
}

test "render invalidateLayer taskbar" {
    render.init(1024, 768);
    render.invalidateFull();
    render.presentComplete();
    render.invalidateLayer(.taskbar);
    try std.testing.expect(render.needsRedraw());
}

test "compositor frame hash stable when idle" {
    resource_cache.init(std.testing.allocator);
    defer resource_cache.deinit();
    shell.init();
    var cfg = ShellConfig{};
    cfg.setThemeRoot("src/desktop/luna");
    cfg.screen_width = 64;
    cfg.screen_height = 48;
    shell.start(cfg);
    var px: [64 * 48 * 4]u8 = undefined;
    compositor.composeFrame(&px, 64, 48);
    const h = std.hash.Wyhash.hash(0, &px);
    compositor.composeFrame(&px, 64, 48);
    try std.testing.expectEqual(h, std.hash.Wyhash.hash(0, &px));
}
