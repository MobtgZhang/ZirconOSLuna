//! 系统时钟与计时器频率常量。本仓库不实现 PIT/APIC。

const std = @import("std");

/// 典型 PC 兼容系统约 100 Hz（10 ms 节拍）
pub const SYSTEM_TICK_HZ: u32 = 100;

pub const TICKS_PER_SECOND: u64 = SYSTEM_TICK_HZ;

test "timer" {
    try std.testing.expect(TICKS_PER_SECOND == 100);
}
