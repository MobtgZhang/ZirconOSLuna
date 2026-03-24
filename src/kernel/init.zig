//! NT 5.2 风格阶段 0 初始化（ReactOS ntoskrnl Phase0 的极简对应：HAL 日志 → KE 陷阱 → MM 引导信息）。

const serial = @import("hal/serial.zig");
const dbg = @import("dbg.zig");
const mboot2 = @import("mm/mboot2.zig");
const pmm = @import("mm/pmm.zig");
const idt = @import("arch/idt.zig");

/// UEFI 路径下 ZBM 把 Multiboot2 信息块放在低端固定物理页（如 `0x50000`）。
/// ExitBootServices 之后规范上 `EfiLoaderData` 仍归本映像使用，但为防实机/固件差异或后续误踩，
/// 在解析 mmap/帧缓冲前先整体拷入 BSS，后续只访问副本。
var mb2_info_copy: [65536]u8 align(8) = undefined;

fn snapshotMultibootInfo(info_phys: usize) usize {
    const hdr: *align(1) const extern struct {
        total_size: u32,
        reserved: u32,
    } = @ptrFromInt(info_phys);
    const n = hdr.total_size;
    if (n < 8 or n > mb2_info_copy.len) {
        if (n > mb2_info_copy.len) {
            serial.writeStrLn("[MBOOT2] info total_size too large; using phys (increase mb2_info_copy)");
        }
        return info_phys;
    }
    const src: [*]const u8 = @ptrFromInt(info_phys);
    @memcpy(mb2_info_copy[0..n], src[0..n]);
    return @intFromPtr(&mb2_info_copy);
}

/// Phase0 解析到的 Multiboot2 帧缓冲信息（无 tag 时为 null）。
pub var framebuffer: ?mboot2.FbInfo = null;
// 链入异常分发（ISR 调用 `exceptionDispatch`）。
comptime {
    _ = @import("ke/trap.zig");
}

/// Multiboot2 魔数（供入口校验）。
pub const MB2_MAGIC = mboot2.MB2_MAGIC;

/// 启用 SSE/FXSAVE（否则 Zig 生成的 SIMD 访存会 #UD）。须在任意可能触发 libc/编译器 memcpy 的路径之前调用。
pub fn enableSSE() void {
    const cr0_old = asm volatile ("mov %%cr0, %[o]"
        : [o] "={rax}" (-> u64),
    );
    const cr0_new = (cr0_old & ~(@as(u64, 1) << 2)) | (@as(u64, 1) << 1); // EM=0, MP=1
    asm volatile ("mov %[i], %%cr0" :: [i] "{rax}" (cr0_new) : .{ .memory = true });
    const cr4_old = asm volatile ("mov %%cr4, %[o]"
        : [o] "={rax}" (-> u64),
    );
    const cr4_new = cr4_old | (@as(u64, 1) << 9) | (@as(u64, 1) << 10); // OSFXSR | OSXMMEXCPT
    asm volatile ("mov %[i], %%cr4" :: [i] "{rax}" (cr4_new) : .{ .memory = true });
}

/// 由 `kernel_main` 调用：串口、Multiboot 摘要、PMM、IDT。
pub fn phase0Multiboot(magic: u32, info_phys: usize) void {
    serial.init();
    serial.writeStrLn("[HAL] serial up (COM1)");
    serial.writeStrLn("[NT] ZirconOSLuna kernel — NT 5.2 reference (not Microsoft Windows)");

    if (magic != MB2_MAGIC) {
        serial.writeStrLn("[KE] halting: bad Multiboot2 magic");
        hang();
    }

    const info_use = snapshotMultibootInfo(info_phys);
    mboot2.dumpInfo(magic, info_use);
    framebuffer = mboot2.findFramebuffer(info_use);

    const reserve_bytes: u64 = 16 * 1024 * 1024;
    if (!pmm.initFromMultiboot(info_use, reserve_bytes)) {
        pmm.initLinearFallback();
    }

    var i: u32 = 0;
    while (i < 4) : (i += 1) {
        const pa = pmm.tryAllocPage();
        if (pa != 0) {
            dbg.print("[MM] alloc page 0x");
            dbg.printHex(pa, 16);
            dbg.println("");
        } else {
            dbg.println("[MM] alloc failed");
            break;
        }
    }

    idt.installEarlyHandlers();
    serial.writeStrLn("[NT] Phase0 complete — interrupts still masked (IF=0)");
}

fn hang() noreturn {
    while (true) {
        asm volatile ("cli; hlt"
            :
            :
            : .{ .memory = true });
    }
}
