//! COM1 早期内核日志（对应 NT 调试串口习惯；非完整 HAL）。

const port = @import("port.zig");

const COM1: u16 = 0x3F8;
const UART_THR: u16 = 0;
const UART_LCR: u16 = 3;
const UART_LCR_8N1: u8 = 0x03;
const UART_FCR: u16 = 2;
const UART_FCR_ENABLE: u8 = 0x01;
const UART_IER: u16 = 1;
const UART_DLL: u16 = 0;
const UART_DLH: u16 = 1;

var initialized: bool = false;

pub fn init() void {
    if (initialized) return;
    port.outb(COM1 + UART_LCR, 0x80);
    port.outb(COM1 + UART_DLL, 0x03);
    port.outb(COM1 + UART_DLH, 0);
    port.outb(COM1 + UART_LCR, UART_LCR_8N1);
    port.outb(COM1 + UART_FCR, UART_FCR_ENABLE);
    port.outb(COM1 + UART_IER, 0);
    initialized = true;
}

pub fn writeByte(c: u8) void {
    if (!initialized) init();
    port.outb(COM1 + UART_THR, c);
}

pub fn writeNewline() void {
    writeByte('\r');
    writeByte('\n');
}

pub fn writeStr(s: []const u8) void {
    for (s) |c| writeByte(c);
}

pub fn writeStrLn(s: []const u8) void {
    writeStr(s);
    writeNewline();
}

/// 十六进制小写，固定宽度（width 1..16），高位补 0。
pub fn writeHex(v: u64, width: u6) void {
    var buf: [16]u8 = undefined;
    const w: u6 = @max(1, @min(16, width));
    var i: u6 = w;
    var x = v;
    while (i > 0) {
        i -= 1;
        const digit: u8 = @truncate(x & 0xF);
        buf[@intCast(i)] = if (digit < 10) '0' + digit else 'a' + (digit - 10);
        x >>= 4;
    }
    writeStr(buf[0..@intCast(w)]);
}

pub fn writeU64Dec(v: u64) void {
    if (v == 0) {
        writeByte('0');
        return;
    }
    var buf: [20]u8 = undefined;
    var n = v;
    var i: usize = buf.len;
    while (n > 0) {
        i -= 1;
        buf[i] = @truncate('0' + (n % 10));
        n /= 10;
    }
    writeStr(buf[i..]);
}
