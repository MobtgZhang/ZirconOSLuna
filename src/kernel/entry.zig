//! ZirconOSLuna 内核入口 — x86-64 freestanding（Multiboot2）。
//! 分层初始化见 `init.zig`；界面由 `build_config.desktop` 选择。

const init = @import("init.zig");
const build_config = @import("build_config");

fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |ca, i| {
        if (ca != b[i]) return false;
    }
    return true;
}

/// 从 boot/entry.S 调用：EDI=magic, RSI=Multiboot2 info 物理地址
export fn kernel_main(magic: u32, info: [*]const u8) callconv(.c) void {
    init.enableSSE();
    init.phase0Multiboot(magic, @intFromPtr(info));

    if (eql(build_config.desktop, "cmd")) {
        @import("cmd/shell.zig").run();
    }

    // none / 未知：简单 VGA 提示后停机
    const vga = @import("hal/vga_text.zig");
    vga.clear();
    vga.setAttr(0x0F);
    vga.puts("ZirconOSLuna kernel — desktop=none\r\n");
    vga.puts("Set KERNEL_DESKTOP=cmd in build.conf for CMD.\r\n");
    while (true) {
        asm volatile ("hlt"
            :
            :
            : .{ .memory = true });
    }
}
