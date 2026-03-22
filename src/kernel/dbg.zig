//! 与 `build_config.kernel_debug_log` 绑定的串口详细日志（Debug 构建 / -Dkernel-debug-log=true）。
//! Release 仅保留关键行，便于终端与 CI 阅读。

const build_config = @import("build_config");
const serial = @import("hal/serial.zig");

pub const verbose: bool = build_config.kernel_debug_log;

pub fn print(msg: []const u8) void {
    if (!verbose) return;
    serial.writeStr(msg);
}

pub fn println(msg: []const u8) void {
    if (!verbose) return;
    serial.writeStrLn(msg);
}

pub fn printHex(v: u64, width: u6) void {
    if (!verbose) return;
    serial.writeHex(v, width);
}

pub fn printU64Dec(v: u64) void {
    if (!verbose) return;
    serial.writeU64Dec(v);
}
