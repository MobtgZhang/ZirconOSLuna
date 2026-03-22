//! NT 5.2 x64 虚拟地址空间布局常量。
//! 来自 ideas/arch_doc.md 第三节。本文件仅定义常量，无页表操作。

const std = @import("std");

/// 用户态空间上界（含）：0x00000000_00000000 – 0x000007FF_FFFFFFFF = 8 TB
pub const user_space_end: u64 = 0x000007FF_FFFFFFFF;

/// 内核态空间起始（规范地址高位）：0xFFFF0800_00000000
pub const kernel_space_start: u64 = 0xFFFF0800_00000000;

/// 用户态最大可寻址字节数（8 TB）
pub const user_space_bytes: u64 = user_space_end + 1;

pub const PageSize = enum(u32) {
    kb4 = 4096,
    mb2 = 2 * 1024 * 1024,
    gb1 = 1024 * 1024 * 1024,
};

pub fn isUserAddress(va: u64) bool {
    return va <= user_space_end;
}

pub fn isKernelAddress(va: u64) bool {
    return va >= kernel_space_start;
}

test "va layout" {
    try std.testing.expect(isUserAddress(0));
    try std.testing.expect(isUserAddress(user_space_end));
    try std.testing.expect(!isUserAddress(kernel_space_start));
    try std.testing.expect(isKernelAddress(kernel_space_start));
    try std.testing.expect(user_space_bytes == 8 * 1024 * 1024 * 1024 * 1024);
}
