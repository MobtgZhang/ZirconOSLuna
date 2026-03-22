//! NT 5.2（Windows XP Professional x64 / Windows Server 2003 x64 家族）规范化常量。
//! **不是** ntoskrnl 实现——见同目录 `README.md` 与 `docs/NT52_KERNEL_ARCH_CN.md`。
//!
//! 构建号等数值来自公开文档与社区资料，宿主 OS 可能因补丁集不同而存在差异。

const std = @import("std");

/// 内核主/次版本（RtlGetVersion 风格语义，非本库运行环境查询结果）。
pub const version_major: u32 = 5;
pub const version_minor: u32 = 2;

/// 常见 XP x64 RTM 构建号（文档/工具中常见；非运行时探测）。
pub const build_xp_x64_rtm: u32 = 3790;

/// 用户态虚拟地址空间上限数量级：8 TB（见 `ideas/arch_doc.md` / `docs/NT52_KERNEL_ARCH_CN.md`）。
pub const user_space_max_tb: u64 = 8;

/// 与 WOW64 / SysWOW64 相关的宿主路径提示（字符串仅作文档性常量，不由本库访问磁盘）。
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
