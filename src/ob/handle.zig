//! 句柄类型与语义。64 位下 HANDLE 与指针同宽。

const std = @import("std");
const arch = @import("../arch/abi.zig");

pub const HANDLE = arch.uintptr;
pub const PVOID = ?*anyopaque;

pub const INVALID_HANDLE_VALUE: HANDLE = @bitCast(@as(arch.intptr, -1));

pub fn isValid(h: HANDLE) bool {
    return h != INVALID_HANDLE_VALUE and h != 0;
}

test "handle" {
    try std.testing.expect(!isValid(INVALID_HANDLE_VALUE));
    try std.testing.expect(!isValid(0));
}
