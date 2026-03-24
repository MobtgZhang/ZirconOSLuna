//! 每用户配置逻辑路径占位（NT「用户配置文件」思想，无真实注册表/NTUSER.DAT）。

const std = @import("std");

pub const MAX_PATH: usize = 260;

var current_username: [64]u8 = [_]u8{0} ** 64;
var current_username_len: usize = 0;

pub fn setActiveUsername(name: []const u8) void {
    const n = @min(name.len, current_username.len);
    @memcpy(current_username[0..n], name[0..n]);
    current_username_len = n;
}

pub fn getActiveUsername() []const u8 {
    return current_username[0..current_username_len];
}

/// 逻辑根：`Documents and Settings\<user>\` 风格（仅字符串，不创建目录）。
pub fn formatProfileRoot(out: []u8) usize {
    const u = getActiveUsername();
    const prefix = "Documents and Settings\\";
    var pos: usize = 0;
    if (pos + prefix.len > out.len) return 0;
    @memcpy(out[pos .. pos + prefix.len], prefix);
    pos += prefix.len;
    const nn = @min(u.len, out.len - pos - 1);
    @memcpy(out[pos .. pos + nn], u[0..nn]);
    pos += nn;
    if (pos < out.len) {
        out[pos] = '\\';
        pos += 1;
    }
    return pos;
}

pub fn wallpaperPreferencePath(buf: []u8) ?[]const u8 {
    var tmp: [MAX_PATH]u8 = undefined;
    const n = formatProfileRoot(&tmp);
    const tail = "Desktop\\wallpaper.ini";
    if (n == 0 or n + tail.len > tmp.len or n + tail.len > buf.len) return null;
    @memcpy(buf[0..n], tmp[0..n]);
    @memcpy(buf[n .. n + tail.len], tail);
    return buf[0 .. n + tail.len];
}

test "profile root contains username" {
    setActiveUsername("User");
    var b: [128]u8 = undefined;
    const n = formatProfileRoot(&b);
    try std.testing.expect(n > 0);
    try std.testing.expect(std.mem.indexOf(u8, b[0..n], "User") != null);
}
