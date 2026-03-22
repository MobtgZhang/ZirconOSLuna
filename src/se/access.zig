//! ACCESS_MASK 与 GENERIC 映射常量。

const std = @import("std");

pub const ACCESS_MASK = u32;

pub const GENERIC_READ: ACCESS_MASK = 0x80000000;
pub const GENERIC_WRITE: ACCESS_MASK = 0x40000000;
pub const GENERIC_EXECUTE: ACCESS_MASK = 0x20000000;
pub const GENERIC_ALL: ACCESS_MASK = 0x10000000;

pub const DELETE: u32 = 0x00010000;
pub const READ_CONTROL: u32 = 0x00020000;
pub const WRITE_DAC: u32 = 0x00040000;
pub const WRITE_OWNER: u32 = 0x00080000;
pub const SYNCHRONIZE: u32 = 0x00100000;

test "access mask" {
    try std.testing.expect(GENERIC_READ == 0x80000000);
}
