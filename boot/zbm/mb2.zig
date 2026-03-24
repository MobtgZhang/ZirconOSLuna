//! 从 UEFI 内存图构造 Multiboot2 信息块：bootloader 名、mmap、可选 framebuffer tag。
//! Framebuffer 与 mmap 中显存区间由 ZBM 在 SetMode 后填入，供内核映射与 PMM 保留。

const std = @import("std");
const uefi = std.os.uefi;

pub const info_magic: u32 = 0x36D76289;

fn align8(n: u32) u32 {
    return (n + 7) & ~@as(u32, 7);
}

/// 写入 Multiboot2 framebuffer tag（type 8）的 RGB 直彩色域说明（与 GRUB 一致）。
pub const FramebufferRgb = struct {
    addr: u64,
    pitch: u32,
    width: u32,
    height: u32,
    /// UEFI `Mode.frame_buffer_size`（mmap 保留用，可大于 pitch×height）
    mem_size: u64,
    bpp: u8,
    red_field_position: u8,
    red_mask_size: u8,
    green_field_position: u8,
    green_mask_size: u8,
    blue_field_position: u8,
    blue_mask_size: u8,
};

fn countMmapEntries(mmap: uefi.tables.MemoryMapSlice, fb_base: ?u64, fb_end: ?u64) u32 {
    const fb_b = fb_base orelse return countRawMmap(mmap);
    const fb_e = fb_end orelse return countRawMmap(mmap);
    var n: u32 = 0;
    var it = mmap.iterator();
    while (it.next()) |d| {
        const base = d.physical_start;
        const len = d.number_of_pages * 4096;
        if (len == 0) continue;
        const end = base + len;
        if (d.type != .conventional_memory or end <= fb_b or base >= fb_e) {
            n += 1;
            continue;
        }
        const ov_s = @max(base, fb_b);
        const ov_e = @min(end, fb_e);
        if (ov_s >= ov_e) {
            n += 1;
            continue;
        }
        if (base < ov_s) n += 1;
        n += 1; // reserved overlap
        if (end > ov_e) n += 1;
    }
    return n;
}

fn countRawMmap(mmap: uefi.tables.MemoryMapSlice) u32 {
    var n: u32 = 0;
    var it = mmap.iterator();
    while (it.next()) |_| n += 1;
    return n;
}

fn mbTypForUefi(t: uefi.tables.MemoryType) u32 {
    return if (t == .conventional_memory) @as(u32, 1) else 2;
}

fn writeMmapEntries(buf: []u8, o: u32, mmap: uefi.tables.MemoryMapSlice, fb_base: ?u64, fb_end: ?u64) u32 {
    var eo: u32 = o;
    var it = mmap.iterator();
    while (it.next()) |d| {
        const base = d.physical_start;
        const len = d.number_of_pages * 4096;
        if (len == 0) continue;
        const end = base + len;
        const fb_b = fb_base orelse {
            writeMmapEnt(buf, &eo, base, len, mbTypForUefi(d.type));
            continue;
        };
        const fb_e = fb_end orelse {
            writeMmapEnt(buf, &eo, base, len, mbTypForUefi(d.type));
            continue;
        };
        if (d.type != .conventional_memory or end <= fb_b or base >= fb_e) {
            writeMmapEnt(buf, &eo, base, len, mbTypForUefi(d.type));
            continue;
        }
        const ov_s = @max(base, fb_b);
        const ov_e = @min(end, fb_e);
        if (ov_s >= ov_e) {
            writeMmapEnt(buf, &eo, base, len, mbTypForUefi(d.type));
            continue;
        }
        if (base < ov_s) {
            writeMmapEnt(buf, &eo, base, ov_s - base, 1);
        }
        writeMmapEnt(buf, &eo, ov_s, ov_e - ov_s, 2);
        if (end > ov_e) {
            writeMmapEnt(buf, &eo, ov_e, end - ov_e, 1);
        }
    }
    return eo;
}

fn writeMmapEnt(buf: []u8, eo: *u32, base: u64, len: u64, typ: u32) void {
    std.mem.writeInt(u64, buf[eo.*..][0..8], base, .little);
    eo.* += 8;
    std.mem.writeInt(u64, buf[eo.*..][0..8], len, .little);
    eo.* += 8;
    std.mem.writeInt(u32, buf[eo.*..][0..4], typ, .little);
    eo.* += 4;
    std.mem.writeInt(u32, buf[eo.*..][0..4], 0, .little);
    eo.* += 4;
}

fn writeFramebufferTag(buf: []u8, o: u32, fb: FramebufferRgb) u32 {
    // type 8, flags 0, size = align8(12 + 8 + 4*3 + 2 + 6) = 48
    const tag_size: u32 = 48;
    std.mem.writeInt(u32, buf[o..][0..4], 8, .little);
    std.mem.writeInt(u32, buf[o + 4 ..][0..4], 0, .little);
    std.mem.writeInt(u32, buf[o + 8 ..][0..4], tag_size, .little);
    std.mem.writeInt(u64, buf[o + 12 ..][0..8], fb.addr, .little);
    std.mem.writeInt(u32, buf[o + 20 ..][0..4], fb.pitch, .little);
    std.mem.writeInt(u32, buf[o + 24 ..][0..4], fb.width, .little);
    std.mem.writeInt(u32, buf[o + 28 ..][0..4], fb.height, .little);
    buf[o + 32] = fb.bpp;
    buf[o + 33] = 1; // MULTIBOOT_FRAMEBUFFER_TYPE_RGB
    std.mem.writeInt(u16, buf[o + 34 ..][0..2], 0, .little); // reserved
    buf[o + 36] = fb.red_field_position;
    buf[o + 37] = fb.red_mask_size;
    buf[o + 38] = fb.green_field_position;
    buf[o + 39] = fb.green_mask_size;
    buf[o + 40] = fb.blue_field_position;
    buf[o + 41] = fb.blue_mask_size;
    @memset(buf[o + 42 ..][0 .. tag_size - 42], 0);
    return o + tag_size;
}

/// 将信息写入 `buf`，返回写入字节数（含 8 字节总头）。`fb == null` 时不写 framebuffer tag。
pub fn build(buf: []u8, mmap: uefi.tables.MemoryMapSlice, fb: ?FramebufferRgb) error{BufferTooSmall}!u32 {
    const bootloader_name = "ZirconOS Boot Manager\x00";
    const bl_tag_size = align8(12 + @as(u32, @intCast(bootloader_name.len)));

    const fb_base: ?u64 = if (fb) |f| f.addr else null;
    const fb_end: ?u64 = if (fb) |f| f.addr +% f.mem_size else null;

    const nent = countMmapEntries(mmap, fb_base, fb_end);
    const mmap_tag_size = align8(20 + nent * 24);
    const fb_tag_size: u32 = if (fb != null) align8(48) else 0;
    const end_tag: u32 = 8;
    const total: u32 = 8 + bl_tag_size + mmap_tag_size + fb_tag_size + end_tag;
    if (buf.len < total) return error.BufferTooSmall;

    @memset(buf[0..total], 0);

    std.mem.writeInt(u32, buf[0..4], total, .little);

    var o: u32 = 8;
    // tag: bootloader (2)
    std.mem.writeInt(u32, buf[o..][0..4], 2, .little);
    std.mem.writeInt(u32, buf[o + 4 ..][0..4], 0, .little);
    std.mem.writeInt(u32, buf[o + 8 ..][0..4], bl_tag_size, .little);
    @memcpy(buf[o + 12 ..][0..bootloader_name.len], bootloader_name);
    o += bl_tag_size;

    // tag: mmap (6)
    std.mem.writeInt(u32, buf[o..][0..4], 6, .little);
    std.mem.writeInt(u32, buf[o + 4 ..][0..4], 0, .little);
    std.mem.writeInt(u32, buf[o + 8 ..][0..4], mmap_tag_size, .little);
    std.mem.writeInt(u32, buf[o + 12 ..][0..4], 24, .little);
    std.mem.writeInt(u32, buf[o + 16 ..][0..4], 0, .little);
    _ = writeMmapEntries(buf, o + 20, mmap, fb_base, fb_end);

    o += mmap_tag_size;

    if (fb) |f| {
        o = writeFramebufferTag(buf, o, f);
    }

    // tag: end (0)
    std.mem.writeInt(u32, buf[o..][0..4], 0, .little);
    std.mem.writeInt(u32, buf[o + 4 ..][0..4], 0, .little);

    return total;
}
