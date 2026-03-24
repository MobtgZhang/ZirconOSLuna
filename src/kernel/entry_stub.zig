//! 非 x86_64 最小可链接内核入口（WFI/WFE/idle 停机）；bring-up 前占位。

const builtin = @import("builtin");
const nt52_common = @import("common/nt52_spec.zig");

export fn kernel_main() noreturn {
    _ = nt52_common.version_major;
    while (true) {
        switch (builtin.cpu.arch) {
            .riscv64 => asm volatile ("wfi"),
            .aarch64 => asm volatile ("wfe"),
            .loongarch64 => asm volatile ("idle 0"),
            else => asm volatile ("nop"),
        }
    }
}
