//! IRQL（Interrupt Request Level）— NT 内核中断请求等级。
//! 规范类型，无调度实现。见 docs/NT52_KERNEL_ARCH_CN.md、arch_doc.md 第五节。

const std = @import("std");

pub const KIRQL = u8;

pub const PASSIVE_LEVEL: KIRQL = 0;
pub const APC_LEVEL: KIRQL = 1;
pub const DISPATCH_LEVEL: KIRQL = 2;
pub const DIRQL_START: KIRQL = 27;
pub const HIGH_LEVEL: KIRQL = 31;

pub fn isValid(level: KIRQL) bool {
    return level <= HIGH_LEVEL;
}

test "irql range" {
    try std.testing.expect(isValid(PASSIVE_LEVEL));
    try std.testing.expect(isValid(APC_LEVEL));
    try std.testing.expect(isValid(DISPATCH_LEVEL));
    try std.testing.expect(isValid(HIGH_LEVEL));
}
