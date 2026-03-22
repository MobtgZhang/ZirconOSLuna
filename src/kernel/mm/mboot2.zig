//! Multiboot2 信息块遍历（GRUB / ZBM 等引导器）。仅解析引导所需子集。

const serial = @import("../hal/serial.zig");
const dbg = @import("../dbg.zig");

pub const MB2_MAGIC: u32 = 0x36D76289;

pub const TagType = enum(u32) {
    end = 0,
    cmdline = 1,
    bootloader = 2,
    module = 3,
    basic_mem = 4,
    bootdev = 5,
    mmap = 6,
    vbe = 7,
    framebuffer = 8,
    elf_sections = 9,
    apm = 10,
    _,
};

/// Multiboot2 内存映射条目（type=1 为可用 RAM）。
pub const MmapEntry = extern struct {
    base: u64 align(1),
    len: u64 align(1),
    typ: u32 align(1),
    reserved: u32 align(1),
};

pub const MMAP_AVAILABLE: u32 = 1;

pub const TagHeader = extern struct {
    typ: u32 align(1),
    flags: u32 align(1),
    size: u32 align(1),
};

fn align8(x: u32) u32 {
    return (x + 7) & ~@as(u32, 7);
}

/// 校验 magic 并打印引导器名称、基本内存与 mmap 摘要。
pub fn dumpInfo(magic: u32, info_phys: usize) void {
    if (magic != MB2_MAGIC) {
        serial.writeStrLn("[MBOOT2] invalid magic");
        return;
    }
    const hdr: *align(1) const extern struct {
        total_size: u32,
        reserved: u32,
    } = @ptrFromInt(info_phys);

    dbg.print("[MBOOT2] total_size=");
    dbg.printU64Dec(hdr.total_size);
    dbg.println("");

    var off: u32 = 8;
    while (off + @sizeOf(TagHeader) <= hdr.total_size) {
        const tag: *align(1) const TagHeader = @ptrFromInt(info_phys + off);
        if (tag.typ == @intFromEnum(TagType.end)) break;

        const step = align8(tag.size);
        if (step == 0) break;

        switch (tag.typ) {
            @intFromEnum(TagType.bootloader) => {
                if (tag.size >= 12) {
                    const name_len = tag.size - 12;
                    const p: [*]const u8 = @ptrFromInt(info_phys + off + 12);
                    dbg.print("[MBOOT2] bootloader: ");
                    dbg.print(p[0..@min(name_len, 128)]);
                    dbg.println("");
                }
            },
            @intFromEnum(TagType.basic_mem) => {
                if (tag.size >= 16) {
                    const p: *align(1) const extern struct {
                        t: TagHeader,
                        mem_lower: u32,
                        mem_upper: u32,
                    } = @ptrFromInt(info_phys + off);
                    dbg.print("[MBOOT2] mem_lower=");
                    dbg.printU64Dec(p.mem_lower);
                    dbg.print(" KB mem_upper=");
                    dbg.printU64Dec(p.mem_upper);
                    dbg.println(" KB");
                }
            },
            @intFromEnum(TagType.mmap) => {
                if (tag.size > 16) {
                    const p: *align(1) const extern struct {
                        t: TagHeader,
                        entry_size: u32,
                        entry_version: u32,
                    } = @ptrFromInt(info_phys + off);
                    var eoff: u32 = 16;
                    dbg.println("[MBOOT2] mmap:");
                    while (eoff + p.entry_size <= tag.size) {
                        if (p.entry_size == 0) break;
                        const ent: *align(1) const MmapEntry = @ptrFromInt(info_phys + off + eoff);
                        dbg.print("  base=0x");
                        dbg.printHex(ent.base, 16);
                        dbg.print(" len=0x");
                        dbg.printHex(ent.len, 16);
                        dbg.print(" type=");
                        dbg.printU64Dec(ent.typ);
                        dbg.println("");
                        eoff += p.entry_size;
                    }
                }
            },
            else => {},
        }
        off += step;
    }
}

/// 在 mmap 中查找第一块长度 ≥ need 的可用区域，且起始 ≥ min_addr。
pub fn findAvailableRegion(info_phys: usize, min_addr: u64, need: u64) ?struct { base: u64, len: u64 } {
    const hdr: *align(1) const extern struct {
        total_size: u32,
        reserved: u32,
    } = @ptrFromInt(info_phys);

    var off: u32 = 8;
    while (off + @sizeOf(TagHeader) <= hdr.total_size) {
        const tag: *align(1) const TagHeader = @ptrFromInt(info_phys + off);
        if (tag.typ == @intFromEnum(TagType.end)) break;

        const step = (tag.size + 7) & ~@as(u32, 7);
        if (step == 0) break;

        if (tag.typ == @intFromEnum(TagType.mmap) and tag.size > 16) {
            const p: *align(1) const extern struct {
                t: TagHeader,
                entry_size: u32,
                entry_version: u32,
            } = @ptrFromInt(info_phys + off);
            var eoff: u32 = 16;
            while (eoff + p.entry_size <= tag.size) {
                if (p.entry_size == 0) break;
                const ent: *align(1) const MmapEntry = @ptrFromInt(info_phys + off + eoff);
                if (ent.typ == MMAP_AVAILABLE and ent.len >= need) {
                    if (ent.base + ent.len > min_addr) {
                        const start = @max(ent.base, min_addr);
                        const end = ent.base + ent.len;
                        if (end > start) {
                            const avail = end - start;
                            if (avail >= need) return .{ .base = start, .len = avail };
                        }
                    }
                }
                eoff += p.entry_size;
            }
        }
        off += step;
    }
    return null;
}
