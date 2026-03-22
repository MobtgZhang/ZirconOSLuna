//! x86-64 IDT 装载（与 boot/entry.S 中代码段选择子 0x08 一致）。

const dbg = @import("../dbg.zig");

/// `lidt` 伪描述符：limit(u16, LE) + base(u64, LE)，共 10 字节（与 `boot/idt_load.S` 一致）。
export var kernel_idt_descriptor: [10]u8 = [_]u8{0} ** 10;

extern fn arch_load_idt() callconv(.c) void;

fn writeIdtDescriptor(limit: u16, base: u64) void {
    kernel_idt_descriptor[0] = @truncate(limit & 0xFF);
    kernel_idt_descriptor[1] = @truncate(limit >> 8);
    inline for (0..8) |i| {
        kernel_idt_descriptor[2 + i] = @truncate((base >> @as(u6, @intCast(8 * i))) & 0xFF);
    }
}

var idt_table: [256 * 16]u8 align(16) = [_]u8{0} ** (256 * 16);

extern fn isr_stub_0() void;
extern fn isr_stub_1() void;
extern fn isr_stub_2() void;
extern fn isr_stub_3() void;
extern fn isr_stub_4() void;
extern fn isr_stub_5() void;
extern fn isr_stub_6() void;
extern fn isr_stub_7() void;
extern fn isr_stub_8() void;
extern fn isr_stub_9() void;
extern fn isr_stub_10() void;
extern fn isr_stub_11() void;
extern fn isr_stub_12() void;
extern fn isr_stub_13() void;
extern fn isr_stub_14() void;
extern fn isr_stub_15() void;
extern fn isr_stub_16() void;
extern fn isr_stub_17() void;
extern fn isr_stub_18() void;
extern fn isr_stub_19() void;
extern fn isr_stub_20() void;
extern fn isr_stub_21() void;
extern fn isr_stub_22() void;
extern fn isr_stub_23() void;
extern fn isr_stub_24() void;
extern fn isr_stub_25() void;
extern fn isr_stub_26() void;
extern fn isr_stub_27() void;
extern fn isr_stub_28() void;
extern fn isr_stub_29() void;
extern fn isr_stub_30() void;
extern fn isr_stub_31() void;
extern fn isr_stub_reserved() void;

fn setGate(slot: usize, handler: usize, selector: u16) void {
    const h: u64 = @truncate(handler);
    const base = slot * 16;
    idt_table[base + 0] = @truncate(h & 0xFF);
    idt_table[base + 1] = @truncate((h >> 8) & 0xFF);
    idt_table[base + 2] = @truncate(selector & 0xFF);
    idt_table[base + 3] = @truncate((selector >> 8) & 0xFF);
    idt_table[base + 4] = 0; // IST
    idt_table[base + 5] = 0x8E; // 64-bit interrupt gate, present, DPL0
    idt_table[base + 6] = @truncate((h >> 16) & 0xFF);
    idt_table[base + 7] = @truncate((h >> 24) & 0xFF);
    const hi: u32 = @truncate(h >> 32);
    idt_table[base + 8] = @truncate(hi & 0xFF);
    idt_table[base + 9] = @truncate((hi >> 8) & 0xFF);
    idt_table[base + 10] = @truncate((hi >> 16) & 0xFF);
    idt_table[base + 11] = @truncate((hi >> 24) & 0xFF);
    idt_table[base + 12] = 0;
    idt_table[base + 13] = 0;
    idt_table[base + 14] = 0;
    idt_table[base + 15] = 0;
}

pub fn installEarlyHandlers() void {
    setGate(0, @intFromPtr(&isr_stub_0), 0x08);
    setGate(1, @intFromPtr(&isr_stub_1), 0x08);
    setGate(2, @intFromPtr(&isr_stub_2), 0x08);
    setGate(3, @intFromPtr(&isr_stub_3), 0x08);
    setGate(4, @intFromPtr(&isr_stub_4), 0x08);
    setGate(5, @intFromPtr(&isr_stub_5), 0x08);
    setGate(6, @intFromPtr(&isr_stub_6), 0x08);
    setGate(7, @intFromPtr(&isr_stub_7), 0x08);
    setGate(8, @intFromPtr(&isr_stub_8), 0x08);
    setGate(9, @intFromPtr(&isr_stub_9), 0x08);
    setGate(10, @intFromPtr(&isr_stub_10), 0x08);
    setGate(11, @intFromPtr(&isr_stub_11), 0x08);
    setGate(12, @intFromPtr(&isr_stub_12), 0x08);
    setGate(13, @intFromPtr(&isr_stub_13), 0x08);
    setGate(14, @intFromPtr(&isr_stub_14), 0x08);
    setGate(15, @intFromPtr(&isr_stub_15), 0x08);
    setGate(16, @intFromPtr(&isr_stub_16), 0x08);
    setGate(17, @intFromPtr(&isr_stub_17), 0x08);
    setGate(18, @intFromPtr(&isr_stub_18), 0x08);
    setGate(19, @intFromPtr(&isr_stub_19), 0x08);
    setGate(20, @intFromPtr(&isr_stub_20), 0x08);
    setGate(21, @intFromPtr(&isr_stub_21), 0x08);
    setGate(22, @intFromPtr(&isr_stub_22), 0x08);
    setGate(23, @intFromPtr(&isr_stub_23), 0x08);
    setGate(24, @intFromPtr(&isr_stub_24), 0x08);
    setGate(25, @intFromPtr(&isr_stub_25), 0x08);
    setGate(26, @intFromPtr(&isr_stub_26), 0x08);
    setGate(27, @intFromPtr(&isr_stub_27), 0x08);
    setGate(28, @intFromPtr(&isr_stub_28), 0x08);
    setGate(29, @intFromPtr(&isr_stub_29), 0x08);
    setGate(30, @intFromPtr(&isr_stub_30), 0x08);
    setGate(31, @intFromPtr(&isr_stub_31), 0x08);

    const reserved = @intFromPtr(&isr_stub_reserved);
    var slot: usize = 32;
    while (slot < 256) : (slot += 1) {
        setGate(slot, reserved, 0x08);
    }

    writeIdtDescriptor(
        @as(u16, @intCast(idt_table.len - 1)),
        @intFromPtr(&idt_table),
    );
    arch_load_idt();
    dbg.println("[KE] IDT installed (0-31 CPU + reserved 32-255)");
}
