//! 物理页分配器（NT MM 中 PFN/空闲链的极简占位：单区 bump）。
//! 从 Multiboot2 mmap 选取内核映像之上的可用区，仅满足页表/扩展映射等早期需求。

const dbg = @import("../dbg.zig");
const mboot2 = @import("mboot2.zig");

const PoolRegion = struct {
    base: u64,
    len: u64,
};

var pool_next: u64 = 0;
var pool_limit: u64 = 0;
var inited: bool = false;

/// 内核与引导页表占用的物理地址上界（保守值）。
/// `boot/entry.S` 恒等映射首 2MiB；在此之下含 1MiB 加载基址、早期页表与 BSS/栈。
fn kernelReservedTopPhys() u64 {
    return 2 * 1024 * 1024;
}

fn alignUp(v: u64, alignment: u64) u64 {
    return (v + alignment - 1) & ~(alignment - 1);
}

/// 用 mmap 在 `kernel_end` 之上建立至少 `reserve_bytes` 的物理页池。
pub fn initFromMultiboot(info_phys: usize, reserve_bytes: u64) bool {
    const min_addr = alignUp(kernelReservedTopPhys(), 4096);
    if (findPool(info_phys, min_addr, reserve_bytes)) |r| {
        pool_next = alignUp(@max(r.base, min_addr), 4096);
        pool_limit = r.base + r.len;
        inited = true;
        dbg.print("[PMM] pool 0x");
        dbg.printHex(pool_next, 16);
        dbg.print(" .. 0x");
        dbg.printHex(pool_limit, 16);
        dbg.println("");
        return true;
    }
    dbg.println("[PMM] no mmap pool (will try linear fallback)");
    return false;
}

/// 无 Multiboot mmap 时的开发用后备：假定 [2MiB, 2MiB+16MiB) 可安全 bump（QEMU 典型）。
pub fn initLinearFallback() void {
    const base: u64 = kernelReservedTopPhys();
    const size: u64 = 16 * 1024 * 1024;
    pool_next = alignUp(base, 4096);
    pool_limit = pool_next + size;
    inited = true;
    dbg.println("[PMM] linear fallback on (2MiB..+16MiB)");
}

fn findPool(info_phys: usize, min_addr: u64, need: u64) ?PoolRegion {
    var best: ?PoolRegion = null;
    const hdr: *align(1) const extern struct {
        total_size: u32,
        reserved: u32,
    } = @ptrFromInt(info_phys);

    var off: u32 = 8;
    while (off + @sizeOf(mboot2.TagHeader) <= hdr.total_size) {
        const tag: *align(1) const mboot2.TagHeader = @ptrFromInt(info_phys + off);
        if (tag.typ == @intFromEnum(mboot2.TagType.end)) break;

        if (tag.typ == @intFromEnum(mboot2.TagType.mmap) and tag.size > 16) {
            const p: *align(1) const extern struct {
                t: mboot2.TagHeader,
                entry_size: u32,
                entry_version: u32,
            } = @ptrFromInt(info_phys + off);
            var eoff: u32 = 16;
            while (eoff + p.entry_size <= tag.size) {
                if (p.entry_size == 0) break;
                const ent: *align(1) const mboot2.MmapEntry = @ptrFromInt(info_phys + off + eoff);
                if (ent.typ == mboot2.MMAP_AVAILABLE) {
                    const seg_end = ent.base + ent.len;
                    if (seg_end > min_addr) {
                        const start = @max(ent.base, min_addr);
                        if (seg_end > start) {
                            const len = seg_end - start;
                            if (len >= need) {
                                if (best == null or len > best.?.len) {
                                    best = .{ .base = start, .len = len };
                                }
                            }
                        }
                    }
                }
                eoff += p.entry_size;
            }
        }
        off += (tag.size + 7) & ~@as(u32, 7);
    }
    return best;
}

/// 分配一页（4KiB）。成功返回物理地址；失败或池未初始化返回 **0**（与页 0 区分：本池自 2MiB 起）。
pub fn tryAllocPage() u64 {
    if (!inited) return 0;
    const p = pool_next;
    if (p + 4096 > pool_limit) return 0;
    pool_next += 4096;
    return p;
}

pub fn poolRemainingBytes() u64 {
    if (!inited or pool_next >= pool_limit) return 0;
    return pool_limit - pool_next;
}
