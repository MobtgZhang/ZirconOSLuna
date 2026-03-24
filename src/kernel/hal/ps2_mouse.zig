//! PS/2 鼠标（轮询，8042 AUX）。与 `kbd.zig` 约定：键盘字节 status bit5=0，鼠标 bit5=1。

const port = @import("port.zig");

const PS2_DATA: u16 = 0x60;
const PS2_STATUS: u16 = 0x64;
const PS2_CMD: u16 = 0x64;

var pkt_idx: u8 = 0;
var pkt: [3]u8 = undefined;

fn waitWrite() void {
    var n: u32 = 0;
    while (n < 200_000) : (n += 1) {
        if ((port.inb(PS2_STATUS) & 2) == 0) return;
    }
}

fn waitRead() void {
    var n: u32 = 0;
    while (n < 200_000) : (n += 1) {
        if ((port.inb(PS2_STATUS) & 1) != 0) return;
    }
}

fn writeMouse(b: u8) void {
    waitWrite();
    port.outb(PS2_CMD, 0xD4);
    waitWrite();
    port.outb(PS2_DATA, b);
}

fn readByte() u8 {
    waitRead();
    return port.inb(PS2_DATA);
}

/// 启用第二端口并尝试打开数据上报；失败时静默（无鼠标仍可启动桌面）。
pub fn init() void {
    waitWrite();
    port.outb(PS2_CMD, 0xA8);

    writeMouse(0xFF);
    // 复位应答与自检字节因机型而异，尽量排空
    var drain: u32 = 0;
    while (drain < 8) : (drain += 1) {
        if ((port.inb(PS2_STATUS) & 1) == 0) break;
        _ = port.inb(PS2_DATA);
    }

    writeMouse(0xF4);
    _ = readByte(); // 期望 0xFA；非 FA 亦继续
    pkt_idx = 0;
}

pub const Motion = struct {
    dx: i16,
    dy: i16,
    left: bool,
};

/// 读取最多凑齐一包（3 字节）；无完整包则返回 null。
pub fn poll() ?Motion {
    const st = port.inb(PS2_STATUS);
    if ((st & 1) == 0) return null;
    if ((st & 0x20) == 0) return null;

    const b = port.inb(PS2_DATA);
    switch (pkt_idx) {
        0 => {
            if ((b & 8) == 0) return null;
            pkt[0] = b;
            pkt_idx = 1;
            return null;
        },
        1 => {
            pkt[1] = b;
            pkt_idx = 2;
            return null;
        },
        2 => {
            pkt[2] = b;
            pkt_idx = 0;
            const flags = pkt[0];
            var dx_u: u16 = pkt[1];
            var dy_u: u16 = pkt[2];
            if ((flags & 0x10) != 0) dx_u |= 0xFF00;
            if ((flags & 0x20) != 0) dy_u |= 0xFF00;
            const dx: i16 = @bitCast(dx_u);
            const dy: i16 = @bitCast(dy_u);
            return Motion{
                .dx = dx,
                .dy = dy,
                .left = (flags & 1) != 0,
            };
        },
        else => {
            pkt_idx = 0;
            return null;
        },
    }
}
