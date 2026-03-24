//! NT 5.2 规范常量（与 ISA 无关；各架构内核与宿主共用）。
//! **不是** ntoskrnl 实现——见 `kernel/nt52/README.md` 与 `docs/NT52_KERNEL_ARCH_CN.md`。

const std = @import("std");

pub const version_major: u32 = 5;
pub const version_minor: u32 = 2;
pub const build_xp_x64_rtm: u32 = 3790;
pub const user_space_max_tb: u64 = 8;
pub const syswow64_hint: []const u8 = "SysWOW64";

pub fn describeProductLine(buffer: []u8) []const u8 {
    const s = "NT 5.2 — Windows XP x64 / Server 2003 家族（规范对照）";
    const n = @min(s.len, buffer.len);
    @memcpy(buffer[0..n], s[0..n]);
    return buffer[0..n];
}

test "nt52 version tuple" {
    try std.testing.expectEqual(@as(u32, 5), version_major);
    try std.testing.expectEqual(@as(u32, 2), version_minor);
    try std.testing.expect(build_xp_x64_rtm >= 3790);
}
