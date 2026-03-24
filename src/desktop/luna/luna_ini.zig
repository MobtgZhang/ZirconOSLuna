//! 极简 `luna.ini`（`KEY=value` 每行）；解析结果由 Shell 合并进 `ShellConfig`。

const std = @import("std");

fn trim(s: []const u8) []const u8 {
    var a: usize = 0;
    var b = s.len;
    while (a < b and (s[a] == ' ' or s[a] == '\t')) : (a += 1) {}
    while (b > a and (s[b - 1] == ' ' or s[b - 1] == '\t' or s[b - 1] == '\r')) : (b -= 1) {}
    return s[a..b];
}

pub const Parsed = struct {
    auto_logon: ?bool = null,
    auto_logon_user: [64]u8 = [_]u8{0} ** 64,
    auto_logon_user_len: usize = 0,
};

/// 解析文本（忽略未知键与 `#` 注释行）。
pub fn parse(text: []const u8) Parsed {
    var out: Parsed = .{};
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        const L = trim(line);
        if (L.len == 0 or L[0] == '#') continue;
        const eq = std.mem.indexOfScalar(u8, L, '=') orelse continue;
        const key = trim(L[0..eq]);
        const val = trim(L[eq + 1 ..]);
        if (std.ascii.eqlIgnoreCase(key, "AUTOLOGON")) {
            out.auto_logon = std.ascii.eqlIgnoreCase(val, "1") or std.ascii.eqlIgnoreCase(val, "true") or std.ascii.eqlIgnoreCase(val, "yes");
        } else if (std.ascii.eqlIgnoreCase(key, "AUTOLOGON_USER")) {
            const n = @min(val.len, out.auto_logon_user.len);
            @memcpy(out.auto_logon_user[0..n], val[0..n]);
            out.auto_logon_user_len = n;
        }
    }
    return out;
}

test "autologon keys" {
    const p = parse(
        \\AUTOLOGON=1
        \\AUTOLOGON_USER=Zircon
    );
    try std.testing.expect(p.auto_logon.?);
    try std.testing.expectEqualStrings("Zircon", p.auto_logon_user[0..p.auto_logon_user_len]);
}
