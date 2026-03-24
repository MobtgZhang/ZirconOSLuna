//! 极简 zbm.ini（UTF-8 文本，行式 key=value），供 ZBM 读取启动项。

const std = @import("std");

pub const max_entries: usize = 8;
pub const path_utf16_len: usize = 128;

pub const Entry = struct {
    title: []const u8,
    /// UTF-16 LE，下标 0..path_len-1 有效，path_len 含尾 0
    path_utf16: [path_utf16_len]u16 = @splat(0),
    path_len: u32 = 0,
    active: bool = false,
};

pub const subtitle_line_cap: usize = 160;

pub const Parsed = struct {
    timeout_sec: u32,
    default_index: u32,
    gfx_menu: bool,
    /// 可选：配置侧「机型/路线」说明（如 LoongArch），避免误以为菜单即固件 ISA。
    profile_line: [subtitle_line_cap]u8 = @splat(0),
    profile_len: u32 = 0,
    /// 1 = 不打印「本 .efi 为 x86_64」等长说明（仍须用 x86_64 内核才能启动）。
    brief_menu: bool = false,
    entries: [max_entries]Entry = undefined,
    entry_count: u32,
};

fn trim(s: []const u8) []const u8 {
    var a: usize = 0;
    var b = s.len;
    while (a < b and (s[a] == ' ' or s[a] == '\t')) a += 1;
    while (b > a and (s[b - 1] == ' ' or s[b - 1] == '\t' or s[b - 1] == '\r' or s[b - 1] == '\n')) b -= 1;
    return s[a..b];
}

fn parseU32(s: []const u8, default: u32) u32 {
    if (s.len == 0) return default;
    var v: u32 = 0;
    for (s) |c| {
        if (c < '0' or c > '9') return default;
        v = v * 10 + (c - '0');
        if (v > 3600) return default;
    }
    return v;
}

/// 将 `\BOOT\FILE` 转为 UTF-16 LE 写入 `out`，返回写入的 code units 数（含尾 0）。
pub fn utf8PathToUtf16Le(path: []const u8, out: *[path_utf16_len]u16) u32 {
    const out_max = path_utf16_len - 1;
    var w: usize = 0;
    var i: usize = 0;
    while (i < path.len and w < out_max) {
        const c = path[i];
        if (c < 0x80) {
            out[w] = c;
            w += 1;
            i += 1;
        } else {
            // 非 ASCII 路径简化：跳过异常字节
            i += 1;
        }
    }
    out[w] = 0;
    return @intCast(w + 1);
}

/// 解析 `buf`（完整文件内容）；失败或空条目时 `entry_count` 可为 0，由调用方回退默认。
pub fn parse(buf: []const u8) Parsed {
    var result = Parsed{
        .timeout_sec = 10,
        .default_index = 0,
        .gfx_menu = false,
        .entry_count = 0,
    };

    var lines = std.mem.splitScalar(u8, buf, '\n');
    while (lines.next()) |raw_line| {
        const line = trim(raw_line);
        if (line.len == 0 or line[0] == '#') continue;

        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = trim(line[0..eq]);
        const val = trim(line[eq + 1 ..]);

        if (std.mem.eql(u8, key, "timeout")) {
            result.timeout_sec = parseU32(val, 10);
        } else if (std.mem.eql(u8, key, "default")) {
            result.default_index = parseU32(val, 0);
        } else if (std.mem.eql(u8, key, "gfx_menu")) {
            result.gfx_menu = parseU32(val, 0) != 0;
        } else if (std.mem.eql(u8, key, "profile") or std.mem.eql(u8, key, "platform_profile")) {
            const n = @min(val.len, subtitle_line_cap - 1);
            @memcpy(result.profile_line[0..n], val[0..n]);
            result.profile_len = @intCast(n);
        } else if (std.mem.eql(u8, key, "brief_menu")) {
            result.brief_menu = parseU32(val, 0) != 0;
        } else if (std.mem.startsWith(u8, key, "entry") and std.mem.endsWith(u8, key, "_title")) {
            const idx = parseEntryIndex(key) orelse continue;
            if (idx < max_entries) {
                result.entries[idx].title = val;
                result.entries[idx].active = true;
            }
        } else if (std.mem.startsWith(u8, key, "entry") and std.mem.endsWith(u8, key, "_kernel")) {
            const idx = parseEntryIndex(key) orelse continue;
            if (idx < max_entries) {
                const n = utf8PathToUtf16Le(val, &result.entries[idx].path_utf16);
                result.entries[idx].path_len = n;
                result.entries[idx].active = true;
            }
        }
    }

    var count: u32 = 0;
    for (0..max_entries) |i| {
        if (result.entries[i].active and result.entries[i].path_len > 1) {
            count += 1;
        }
    }
    result.entry_count = count;
    return result;
}

fn parseEntryIndex(key: []const u8) ?usize {
    // entry{N}_title / entry{N}_kernel
    if (key.len < 8) return null;
    if (!std.mem.startsWith(u8, key, "entry")) return null;
    var i: usize = 5;
    var n: usize = 0;
    while (i < key.len) : (i += 1) {
        const c = key[i];
        if (c == '_') break;
        if (c < '0' or c > '9') return null;
        n = n * 10 + (c - '0');
        if (n >= max_entries) return null;
    }
    return n;
}

pub fn collectActiveIndices(p: *const Parsed, out_indices: *[max_entries]u32) u32 {
    var n: u32 = 0;
    var i: usize = 0;
    while (i < max_entries) : (i += 1) {
        if (p.entries[i].active and p.entries[i].path_len > 1) {
            out_indices[n] = @intCast(i);
            n += 1;
        }
    }
    return n;
}
