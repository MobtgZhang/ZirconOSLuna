//! PS/2 键盘（扫描码集 1）：轮询 0x60，无 IRQ 依赖。

const port = @import("port.zig");

const PS2_DATA: u16 = 0x60;
const PS2_STATUS: u16 = 0x64;
const PS2_CMD: u16 = 0x64;

var shift_l: bool = false;
var shift_r: bool = false;
var ctrl: bool = false;

pub fn init() void {
    // 等待控制器可写，启用键盘口
    waitWrite();
    port.outb(PS2_CMD, 0xAE);
}

fn waitWrite() void {
    var n: u32 = 0;
    while (n < 100000) : (n += 1) {
        if ((port.inb(PS2_STATUS) & 2) == 0) return;
    }
}

/// 轮询一次：有按键且为通码时返回 ASCII（含 \r 表示 Enter），无则 null。
/// 若 status 标明辅助端口数据（常见为 bit5），留给 `ps2_mouse.poll` 读取。
pub fn pollKey() ?u8 {
    const st = port.inb(PS2_STATUS);
    if ((st & 1) == 0) return null;
    if ((st & 0x20) != 0) return null;
    const sc = port.inb(PS2_DATA);
    if (sc == 0xE0) {
        // 扩展键前缀：再读一字节（简化：忽略）
        if ((port.inb(PS2_STATUS) & 1) != 0) _ = port.inb(PS2_DATA);
        return null;
    }
    if (sc >= 0x80) {
        // 断码
        switch (sc) {
            0xAA => shift_l = false,
            0xB6 => shift_r = false,
            0x9D, 0xB8 => ctrl = false,
            else => {},
        }
        return null;
    }
    switch (sc) {
        0x2A => {
            shift_l = true;
            return null;
        },
        0x36 => {
            shift_r = true;
            return null;
        },
        0x1D => {
            ctrl = true;
            return null;
        },
        0x01 => return null, // Esc
        0x0E => return 0x08, // Backspace
        0x1C => return '\r', // Enter
        0x39 => return ' ',  // Space
        else => {},
    }
    const sh = shift_l or shift_r;
    return scancodeToAscii(sc, sh);
}

fn scancodeToAscii(sc: u8, sh: bool) ?u8 {
    // 数字行 1-9,0
    const digit_row = [_]u8{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' };
    if (sc >= 0x02 and sc <= 0x0B) {
        if (sh) {
            const sym = "!@#$%^&*()";
            return sym[sc - 0x02];
        }
        return digit_row[sc - 0x02];
    }
    // 字母区（小写 / Shift 大写）
    const letters: []const struct { sc: u8, lo: u8, hi: u8 } = &.{
        .{ .sc = 0x10, .lo = 'q', .hi = 'Q' },
        .{ .sc = 0x11, .lo = 'w', .hi = 'W' },
        .{ .sc = 0x12, .lo = 'e', .hi = 'E' },
        .{ .sc = 0x13, .lo = 'r', .hi = 'R' },
        .{ .sc = 0x14, .lo = 't', .hi = 'T' },
        .{ .sc = 0x15, .lo = 'y', .hi = 'Y' },
        .{ .sc = 0x16, .lo = 'u', .hi = 'U' },
        .{ .sc = 0x17, .lo = 'i', .hi = 'I' },
        .{ .sc = 0x18, .lo = 'o', .hi = 'O' },
        .{ .sc = 0x19, .lo = 'p', .hi = 'P' },
        .{ .sc = 0x1E, .lo = 'a', .hi = 'A' },
        .{ .sc = 0x1F, .lo = 's', .hi = 'S' },
        .{ .sc = 0x20, .lo = 'd', .hi = 'D' },
        .{ .sc = 0x21, .lo = 'f', .hi = 'F' },
        .{ .sc = 0x22, .lo = 'g', .hi = 'G' },
        .{ .sc = 0x23, .lo = 'h', .hi = 'H' },
        .{ .sc = 0x24, .lo = 'j', .hi = 'J' },
        .{ .sc = 0x25, .lo = 'k', .hi = 'K' },
        .{ .sc = 0x26, .lo = 'l', .hi = 'L' },
        .{ .sc = 0x2C, .lo = 'z', .hi = 'Z' },
        .{ .sc = 0x2D, .lo = 'x', .hi = 'X' },
        .{ .sc = 0x2E, .lo = 'c', .hi = 'C' },
        .{ .sc = 0x2F, .lo = 'v', .hi = 'V' },
        .{ .sc = 0x30, .lo = 'b', .hi = 'B' },
        .{ .sc = 0x31, .lo = 'n', .hi = 'N' },
        .{ .sc = 0x32, .lo = 'm', .hi = 'M' },
    };
    for (letters) |L| {
        if (L.sc == sc) return if (sh) L.hi else L.lo;
    }
    // 符号
    return switch (sc) {
        0x0C => if (sh) '_' else '-',
        0x0D => if (sh) '+' else '=',
        0x33 => if (sh) '<' else ',',
        0x34 => if (sh) '>' else '.',
        0x35 => if (sh) '?' else '/',
        0x0B => if (sh) ')' else '0',
        else => null,
    };
}
