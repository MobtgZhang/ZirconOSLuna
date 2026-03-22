//! ZirconOSLuna — Windows XP Luna 风格 Shell / 主题库。
//! 模块根为 `src/`，以包含 `config/`、`hal/`、`drivers/` 等与内核工程同名的目录。
//! 全栈说明见 `docs/KERNEL_AND_STACK_CN.md`、`docs/REPOSITORY_LAYOUT_CN.md`。

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
