//! 非 x86_64 的 UEFI 占位引导（完整 ZBM 菜单与 ELF 加载仅在 x86_64 `main.zig`）。
//! 架构名由 `zbm_stub_config` 注入，避免与 `kernel-arch` 混淆。

const uefi = @import("std").os.uefi;
const cfg = @import("zbm_stub_config");

pub fn main() noreturn {
    const st = uefi.system_table;
    if (st.con_out) |o| {
        printLine(o, cfg.banner_line1);
        printLine(o, cfg.banner_line2);
        printLine(o, cfg.banner_line3);
    }
    while (true) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn printLine(con: *uefi.protocol.SimpleTextOutput, ascii: []const u8) void {
    var tmp: [200:0]u16 = undefined;
    @memset(tmp[0..199], 0);
    var i: usize = 0;
    for (ascii) |c| {
        if (i + 3 >= tmp.len) break;
        tmp[i] = c;
        i += 1;
    }
    tmp[i] = '\r';
    tmp[i + 1] = '\n';
    tmp[i + 2] = 0;
    _ = con.outputString(@ptrCast(&tmp)) catch {};
}
