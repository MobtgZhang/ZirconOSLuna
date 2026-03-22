//! Luna Shell 默认配置（可与宿主配置文件合并）。

const theme = @import("../desktop/luna/theme.zig");
const shell_mod = @import("../desktop/luna/shell.zig");

pub const default_shell_config = shell_mod.ShellConfig{
    .screen_width = 1024,
    .screen_height = 768,
    .color_depth = 32,
    .color_scheme = .blue,
    .auto_logon = false,
    .auto_logon_user = [_]u8{0} ** 64,
    .auto_logon_user_len = 0,
};

pub fn defaultResolution() struct { w: i32, h: i32 } {
    return .{ .w = default_shell_config.screen_width, .h = default_shell_config.screen_height };
}

pub fn colorSchemeOrDefault(s: ?theme.ColorScheme) theme.ColorScheme {
    return s orelse .blue;
}
