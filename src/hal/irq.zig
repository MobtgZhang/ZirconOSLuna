//! IRQ 线号占位常量。x86 传统 0–15，MSI 等可扩展。

const std = @import("std");

pub const IRQL = u8;

pub const IRQ_TIMER: u8 = 0;
pub const IRQ_KEYBOARD: u8 = 1;
pub const IRQ_COM2: u8 = 3;
pub const IRQ_COM1: u8 = 4;

pub const MAX_LEGACY_IRQ: u8 = 15;

test "irq" {
    try std.testing.expect(IRQ_TIMER == 0);
}
