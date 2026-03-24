//! ZirconOSLuna 内核入口 — x86-64 freestanding（Multiboot2）。
//! 分层初始化见 `init.zig`；界面由 `build_config.desktop` 选择。

const init = @import("init.zig");
const build_config = @import("build_config");
const serial = @import("hal/serial.zig");

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

    if (eql(build_config.desktop, "luna")) {
        if (init.framebuffer) |*fb_ref| {
            if (fb_ref.bpp != 32 or fb_ref.fb_type != 1) {
                serial.writeStrLn("[KE] luna: need 32bpp RGB framebuffer");
                hang();
            }
            const mapped = @import("mm/fb_map.zig").mapFramebuffer(fb_ref) orelse {
                serial.writeStrLn("[KE] luna: fb_map failed");
                hang();
            };
            @import("gui/luna_desktop.zig").run(mapped, fb_ref);
        } else {
            serial.writeStrLn("[KE] luna: no Multiboot2 framebuffer tag (use UEFI ZBM + GOP)");
            hang();
        }
    }

    // none / 未知：简单 VGA 提示后停机
    const vga = @import("hal/vga_text.zig");
    vga.clear();
    vga.setAttr(0x0F);
    vga.puts("ZirconOSLuna kernel — desktop=none\r\n");
    vga.puts("Set KERNEL_DESKTOP=cmd|luna (luna needs UEFI ZBM + GOP).\r\n");
    while (true) {
        asm volatile ("hlt"
            :
            :
            : .{ .memory = true });
    }
}

fn hang() noreturn {
    while (true) {
        asm volatile ("cli; hlt" ::: .{ .memory = true });
    }
}
