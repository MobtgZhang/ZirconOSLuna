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

/// 内核映像末尾标记（`boot/kernel_image_end.S`，位于 `.bss` 之后）；PMM 从其后一页边界起 bump。
/// 勿再用固定 2MiB：大内核可延伸到十余 MiB，曾从 2MiB 起分配踩 `.text` 致随机取指 #PF。
extern const kernel_image_end: u8;

/// `boot/entry.S` 用 512×2MiB 大页恒等映射低 1GiB；PMM 页表页须落在此范围内以便 `clearPage` 等访问。
/// 注意：帧缓冲若在 1GiB 以上物理地址，须走 `fb_map` 高半部映射；双缓冲后景在高半部帧缓冲场景下亦须 `mapFramebufferBackBuffer`，勿仅用裸物理指针写后景。
fn kernelReservedTopPhys() u64 {
    return alignUp(@intFromPtr(&kernel_image_end) +% 1, 4096);
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
    dbg.println("[PMM] linear fallback on ([kernel_end]..+16MiB)");
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

/// 分配一页（4KiB）。成功返回物理地址；失败或池未初始化返回 **0**（与页 0 区分：池自 `kernel_image_end` 对齐后起）。
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

/// 自页池 bump 一段**物理连续**内存（向上取整到 4KiB）。用于帧缓冲后景等。
/// 失败返回 `null`（池未初始化或空间不足）。
pub fn tryAllocContiguousBytes(bytes: u64) ?u64 {
    if (!inited or bytes == 0) return null;
    const need = (bytes + 4095) & ~@as(u64, 4095);
    if (pool_next + need > pool_limit) return null;
    const base = pool_next;
    pool_next += need;
    return base;
}
