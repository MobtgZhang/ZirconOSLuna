//! Default resource paths for Luna assets (wallpapers, icons).
//! 路径相对于 **本主题包根目录** `src/desktop/luna/`，
//! 宿主加载时应将 `resources/...` 解析到该目录下。

const theme = @import("theme.zig");

pub const wallpapers = struct {
    pub const bliss_default = "resources/wallpapers/bliss_default.png";
    pub const olive_green = "resources/wallpapers/wallpaper_olive_green.png";
    pub const silver = "resources/wallpapers/wallpaper_silver.png";
};

pub const icons = struct {
    pub const system_dir = "resources/icons/system/";
    pub const my_computer = "resources/icons/system/icon_mycomputer.png";
    pub const my_documents = "resources/icons/system/icon_mydocuments.png";
    pub const recycle_empty = "resources/icons/system/icon_recyclebin_empty.png";
    pub const recycle_full = "resources/icons/system/icon_recyclebin_full.png";
    pub const network = "resources/icons/system/icon_network.png";
    pub const control_panel = "resources/icons/system/icon_controlpanel.png";
    pub const printer = "resources/icons/system/icon_printer.png";
    pub const help = "resources/icons/system/icon_help.png";
    pub const search = "resources/icons/system/icon_search.png";
    pub const run = "resources/icons/system/icon_run.png";
    pub const shutdown = "resources/icons/system/icon_shutdown.png";
    pub const logoff = "resources/icons/system/icon_logoff.png";
    pub const user_default = "resources/icons/system/icon_user_default.png";
};

pub const ui = struct {
    pub const start_button = "resources/taskbar/ui_start_button.png";
    pub const titlebar_buttons = "resources/titlebar/ui_titlebar_buttons.png";
};

pub const cursors = struct {
    pub const arrow = "resources/cursors/cursor_arrow.png";
    pub const wait = "resources/cursors/cursor_wait.png";
};

pub fn wallpaperPathForScheme(scheme: theme.ColorScheme) []const u8 {
    return switch (scheme) {
        .blue => wallpapers.bliss_default,
        .olive_green => wallpapers.olive_green,
        .silver => wallpapers.silver,
    };
}
