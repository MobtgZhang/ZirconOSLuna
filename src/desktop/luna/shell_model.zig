//! Known-folder / tray / desktop-host placeholders (Shell namespace concepts, Zig-only).

const desktop = @import("desktop.zig");

/// 快速启动种子（与任务栏顺序一致）；`icon_png` 为主题根下相对路径。
pub const QuickLaunchSeed = struct {
    name: []const u8,
    target: []const u8,
    icon_png: []const u8,
};

pub const default_quick_launch: []const QuickLaunchSeed = &.{
    .{ .name = "Show Desktop", .target = "shell:desktop", .icon_png = "resources/icons/system/icon_mycomputer.png" },
    .{ .name = "Internet Explorer", .target = "C:\\Program Files\\Internet Explorer\\iexplore.exe", .icon_png = "resources/icons/quicklaunch/icon_internet.png" },
    .{ .name = "Windows Media Player", .target = "C:\\Program Files\\Windows Media Player\\wmplayer.exe", .icon_png = "resources/icons/system/icon_mydocuments.png" },
};

pub fn quickLaunchPngRel(ordinal: usize) ?[]const u8 {
    if (ordinal >= default_quick_launch.len) return null;
    return default_quick_launch[ordinal].icon_png;
}

pub const KnownFolderId = enum(u8) {
    desktop,
    documents,
    pictures,
    music,
    computer,
    network,
};

/// Logical link: display name + resolved path (Win32 .lnk / PIDL 思想的极简版).
pub const ShellLink = struct {
    display: []const u8,
    target: []const u8,
    folder: KnownFolderId,
};

/// Future `Shell_NotifyIcon` 映射用记录。
pub const TrayNotify = struct {
    id: u32,
    icon_rel_path: []const u8,
    tooltip: []const u8,
};

var tray_registry: [16]TrayNotify = [_]TrayNotify{.{ .id = 0, .icon_rel_path = "", .tooltip = "" }} ** 16;
var tray_registry_count: usize = 0;

/// 登记托盘项（逻辑层）；与 `taskbar.addTrayIcon` 成对由 Shell 调用。
pub fn trayNotifyRegister(entry: TrayNotify) bool {
    if (tray_registry_count >= tray_registry.len) return false;
    tray_registry[tray_registry_count] = entry;
    tray_registry_count += 1;
    return true;
}

pub fn trayNotifyUnregister(id: u32) void {
    var i: usize = 0;
    while (i < tray_registry_count) : (i += 1) {
        if (tray_registry[i].id == id) {
            var j = i;
            while (j + 1 < tray_registry_count) : (j += 1) {
                tray_registry[j] = tray_registry[j + 1];
            }
            tray_registry_count -= 1;
            return;
        }
    }
}

pub fn trayNotifyFind(id: u32) ?TrayNotify {
    for (tray_registry[0..tray_registry_count]) |e| {
        if (e.id == id) return e;
    }
    return null;
}

var desktop_host_refresh: u32 = 0;

pub const DesktopHost = struct {
    pub fn refreshVersion() u32 {
        return desktop_host_refresh;
    }
};

pub fn desktopHostBumpRefresh() void {
    desktop_host_refresh +%= 1;
    desktop.rearrangeIcons();
}
