//! 将 GOP 帧缓冲物理区映射到固定高半部虚拟地址，供内核图形路径写入。
//! 恒等映射仅覆盖低 1GiB；高于此的物理地址必须通过本模块建立 4K 页表链。

const pmm = @import("pmm.zig");
const serial = @import("../hal/serial.zig");
const dbg = @import("../dbg.zig");

const mboot2 = @import("mboot2.zig");

/// 与 `pml4Index(0xFFFF800000000000)` 一致。
pub const FB_VIRT_BASE: u64 = 0xFFFF_8000_0000_0000;

const PML4_PHYS: u64 = 0x1000;

fn pml4Index(va: u64) u9 {
    return @truncate((va >> 39) & 0x1FF);
}
fn pdptIndex(va: u64) u9 {
    return @truncate((va >> 30) & 0x1FF);
}
fn pdIndex(va: u64) u9 {
    return @truncate((va >> 21) & 0x1FF);
}
fn ptIndex(va: u64) u9 {
    return @truncate((va >> 12) & 0x1FF);
}

fn alignUp(v: u64, a: u64) u64 {
    return (v + a - 1) & ~(a - 1);
}

fn clearPage(pa: u64) void {
    const p: [*]u8 = @ptrFromInt(pa);
    @memset(p[0..4096], 0);
}

fn mapBytes(fb: *const mboot2.FbInfo) u64 {
    return alignUp(fb.mapBytes(), 4096);
}

/// 页表页须落在恒等映射区内（当前引导器映射低 1GiB）。
fn physOkForTable(pa: u64) bool {
    return pa != 0 and pa + 4096 <= (1024 * 1024 * 1024);
}

/// 建立映射；成功返回线性虚拟指针，失败返回 null。
pub fn mapFramebuffer(fb: *const mboot2.FbInfo) ?[*]align(4096) volatile u8 {
    if (fb.bpp != 32 or fb.fb_type != 1) {
        serial.writeStrLn("[fb_map] unsupported bpp/type (need 32bpp RGB)");
        return null;
    }
    const total = mapBytes(fb);
    if (total == 0) return null;
    const n_pages = total / 4096;

    // 已落在恒等区内则直接返回物理指针（避免改页表）。
    const end_phys = fb.addr +% total;
    if (fb.addr < (1024 * 1024 * 1024) and end_phys <= (1024 * 1024 * 1024)) {
        dbg.println("[fb_map] framebuffer inside identity map, direct phys");
        return @ptrFromInt(fb.addr);
    }

    const pdpt_pa = pmm.tryAllocPage();
    if (!physOkForTable(pdpt_pa)) {
        serial.writeStrLn("[fb_map] no PMM page for PDPT");
        return null;
    }
    clearPage(pdpt_pa);
    const pml4: [*]u64 = @ptrFromInt(PML4_PHYS);
    const pi: usize = @intCast(pml4Index(FB_VIRT_BASE));
    if (pml4[pi] & 1 != 0) {
        serial.writeStrLn("[fb_map] PML4[256] already used");
        return null;
    }
    pml4[pi] = pdpt_pa | 3;

    const pdpt: [*]u64 = @ptrFromInt(pdpt_pa);

    var p: u32 = 0;
    while (p < n_pages) : (p += 1) {
        const va = FB_VIRT_BASE +% @as(u64, p) *% 4096;
        const phys = fb.addr +% @as(u64, p) *% 4096;

        const i_pdpt: usize = @intCast(pdptIndex(va));
        if (pdpt[i_pdpt] & 1 == 0) {
            const pd_pa = pmm.tryAllocPage();
            if (!physOkForTable(pd_pa)) {
                serial.writeStrLn("[fb_map] PD alloc or phys too high");
                return null;
            }
            clearPage(pd_pa);
            pdpt[i_pdpt] = pd_pa | 3;
        }
        const pd: [*]u64 = @ptrFromInt(pdpt[i_pdpt] & 0xffff_ffff_f000);

        const i_pd: usize = @intCast(pdIndex(va));
        if (pd[i_pd] & 1 == 0) {
            const pt_pa = pmm.tryAllocPage();
            if (!physOkForTable(pt_pa)) {
                serial.writeStrLn("[fb_map] PT alloc or phys too high");
                return null;
            }
            clearPage(pt_pa);
            pd[i_pd] = pt_pa | 3;
        }
        const pt: [*]u64 = @ptrFromInt(pd[i_pd] & 0xffff_ffff_f000);

        const i_pt: usize = @intCast(ptIndex(va));
        pt[i_pt] = (phys & 0x000f_ffff_ffff_f000) | 3;
    }

    asm volatile ("mov %%cr3, %%rax\n\tmov %%rax, %%cr3" ::: .{ .memory = true, .rax = true });

    dbg.print("[fb_map] mapped ");
    dbg.printU64Dec(n_pages);
    dbg.println(" pages at 0xFFFF800000000000");
    return @ptrFromInt(FB_VIRT_BASE);
}

fn mapOne4kPage(va: u64, phys: u64) bool {
    const pml4: [*]u64 = @ptrFromInt(PML4_PHYS);
    const pi: usize = @intCast(pml4Index(va));
    if (pml4[pi] & 1 == 0) return false;
    const pdpt: [*]u64 = @ptrFromInt(pml4[pi] & 0xffff_ffff_f000);

    const i_pdpt: usize = @intCast(pdptIndex(va));
    if (pdpt[i_pdpt] & 1 == 0) {
        const pd_pa = pmm.tryAllocPage();
        if (!physOkForTable(pd_pa)) return false;
        clearPage(pd_pa);
        pdpt[i_pdpt] = pd_pa | 3;
    }
    const pd: [*]u64 = @ptrFromInt(pdpt[i_pdpt] & 0xffff_ffff_f000);

    const i_pd: usize = @intCast(pdIndex(va));
    if (pd[i_pd] & 1 == 0) {
        const pt_pa = pmm.tryAllocPage();
        if (!physOkForTable(pt_pa)) return false;
        clearPage(pt_pa);
        pd[i_pd] = pt_pa | 3;
    }
    const pt: [*]u64 = @ptrFromInt(pd[i_pd] & 0xffff_ffff_f000);

    const i_pt: usize = @intCast(ptIndex(va));
    pt[i_pt] = (phys & 0x000f_ffff_ffff_f000) | 3;
    return true;
}

/// 帧缓冲已映射到 `FB_VIRT_BASE` 时，将 PMM 连续物理页映射到紧接其后的虚拟区（供双缓冲后景）。
/// 物理地址须为 4KiB 对齐；失败返回 `null`（调用方应退回单缓冲）。
pub fn mapFramebufferBackBuffer(fb: *const mboot2.FbInfo, phys_base: u64, byte_len: u64) ?[*]align(4096) volatile u8 {
    if (fb.bpp != 32 or fb.fb_type != 1) return null;
    if (phys_base & 0xFFF != 0) return null;
    const fb_total = mapBytes(fb);
    if (fb_total == 0) return null;
    const need = alignUp(byte_len, 4096);
    const n_back = need / 4096;
    if (n_back == 0) return null;

    const pml4: [*]u64 = @ptrFromInt(PML4_PHYS);
    const pi: usize = @intCast(pml4Index(FB_VIRT_BASE));
    if (pml4[pi] & 1 == 0) {
        serial.writeStrLn("[fb_map] back buffer: no FB mapping (PML4[256] empty)");
        return null;
    }

    const va0 = FB_VIRT_BASE +% fb_total;
    var p: u64 = 0;
    while (p < n_back) : (p += 1) {
        const va = va0 +% p *% 4096;
        const phys = phys_base +% p *% 4096;
        if (!mapOne4kPage(va, phys)) {
            serial.writeStrLn("[fb_map] back buffer: mapOne4kPage failed");
            return null;
        }
    }

    asm volatile ("mov %%cr3, %%rax\n\tmov %%rax, %%cr3" ::: .{ .memory = true, .rax = true });
    dbg.println("[fb_map] back buffer mapped after framebuffer (high VA)");
    return @ptrFromInt(va0);
}
