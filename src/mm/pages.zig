//! 物理页与页帧类型常量。4 级页表下 4KB 为基础单位。

const std = @import("std");
const va = @import("va_layout.zig");

/// 4 KB 页内偏移掩码
pub const PAGE_OFFSET_MASK_4K: u64 = 0xFFF;

/// 页帧号（PFN）类型：物理页索引
pub const PFN = u64;

/// 大页（2 MB）偏移掩码
pub const PAGE_OFFSET_MASK_2M: u64 = 0x1_FFFF;

/// 巨页（1 GB）偏移掩码
pub const PAGE_OFFSET_MASK_1G: u64 = 0x3F_FFFF;

pub const PAGE_SIZE_4K: u32 = @intFromEnum(va.PageSize.kb4);
pub const PAGE_SIZE_2M: u32 = @intFromEnum(va.PageSize.mb2);
pub const PAGE_SIZE_1G: u32 = @intFromEnum(va.PageSize.gb1);

test "page sizes" {
    try std.testing.expect(PAGE_SIZE_4K == 4096);
    try std.testing.expect(PAGE_SIZE_2M == 2 * 1024 * 1024);
}
