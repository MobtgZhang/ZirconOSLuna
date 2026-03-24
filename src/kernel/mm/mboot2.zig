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

/// Multiboot2 framebuffer tag（type 8，RGB 直彩）解析结果。
pub const FbInfo = struct {
    addr: u64,
    pitch: u32,
    width: u32,
    height: u32,
    bpp: u8,
    fb_type: u8,

    pub fn mapBytes(self: FbInfo) u64 {
        return @as(u64, self.pitch) *% @as(u64, self.height);
    }
};

fn align8(x: u32) u32 {
    return (x + 7) & ~@as(u32, 7);
}

fn readU32(p: usize) u32 {
    const b: *align(1) const [4]u8 = @ptrFromInt(p);
    return @as(u32, b[0]) | (@as(u32, b[1]) << 8) | (@as(u32, b[2]) << 16) | (@as(u32, b[3]) << 24);
}

fn readU64(p: usize) u64 {
    const lo = readU32(p);
    const hi = readU32(p + 4);
    return @as(u64, lo) | (@as(u64, hi) << 32);
}

/// 遍历 Multiboot2 信息块，返回第一个 framebuffer tag；无则 null。
pub fn findFramebuffer(info_phys: usize) ?FbInfo {
    const hdr: *align(1) const extern struct {
        total_size: u32,
        reserved: u32,
    } = @ptrFromInt(info_phys);

    var off: u32 = 8;
    while (off + @sizeOf(TagHeader) <= hdr.total_size) {
        const tag: *align(1) const TagHeader = @ptrFromInt(info_phys + off);
        if (tag.typ == @intFromEnum(TagType.end)) break;

        const step = align8(tag.size);
        if (step == 0) break;

        if (tag.typ == @intFromEnum(TagType.framebuffer) and tag.size >= 42) {
            const base = info_phys + off + 12;
            return FbInfo{
                .addr = readU64(base),
                .pitch = readU32(base + 8),
                .width = readU32(base + 12),
                .height = readU32(base + 16),
                .bpp = @as(*align(1) const u8, @ptrFromInt(base + 20)).*,
                .fb_type = @as(*align(1) const u8, @ptrFromInt(base + 21)).*,
            };
        }
        off += step;
    }
    return null;
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
            @intFromEnum(TagType.framebuffer) => {
                if (tag.size >= 28 and dbg.verbose) {
                    const base = info_phys + off + 12;
                    dbg.print("[MBOOT2] framebuffer: addr=0x");
                    dbg.printHex(readU64(base), 16);
                    dbg.print(" pitch=");
                    dbg.printU64Dec(readU32(base + 8));
                    dbg.print(" ");
                    dbg.printU64Dec(readU32(base + 12));
                    dbg.print("x");
                    dbg.printU64Dec(readU32(base + 16));
                    dbg.println("");
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
