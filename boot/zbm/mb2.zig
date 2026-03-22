//! 从 UEFI 内存图构造 Multiboot2 信息块（mmap + bootloader 名）。

const std = @import("std");
const uefi = std.os.uefi;

pub const info_magic: u32 = 0x36D76289;

fn align8(n: u32) u32 {
    return (n + 7) & ~@as(u32, 7);
}

/// 将信息写入 `buf`，返回写入字节数（含 8 字节总头）。
pub fn build(buf: []u8, mmap: uefi.tables.MemoryMapSlice) error{BufferTooSmall}!u32 {
    const bootloader_name = "ZirconOS Boot Manager\x00";
    const bl_tag_size = align8(12 + @as(u32, @intCast(bootloader_name.len)));

    var it = mmap.iterator();
    var nent: u32 = 0;
    while (it.next()) |_| nent += 1;

    // mmap 标签：type+flags+size(12) + entry_size + version + 条目
    const mmap_tag_size = align8(20 + nent * 24);
    const end_tag: u32 = 8;
    const total: u32 = 8 + bl_tag_size + mmap_tag_size + end_tag;
    if (buf.len < total) return error.BufferTooSmall;

    @memset(buf[0..total], 0);

    std.mem.writeInt(u32, buf[0..4], total, .little);
    // reserved [4..8] = 0

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
    var eo: u32 = o + 20; // 首条 mmap 起点
    it = mmap.iterator();
    while (it.next()) |d| {
        const base = d.physical_start;
        const len = d.number_of_pages * 4096;
        const typ: u32 = if (d.type == .conventional_memory) 1 else 2;
        std.mem.writeInt(u64, buf[eo..][0..8], base, .little);
        eo += 8;
        std.mem.writeInt(u64, buf[eo..][0..8], len, .little);
        eo += 8;
        std.mem.writeInt(u32, buf[eo..][0..4], typ, .little);
        eo += 4;
        std.mem.writeInt(u32, buf[eo..][0..4], 0, .little);
        eo += 4;
    }
    o += mmap_tag_size;

    // tag: end (0)
    std.mem.writeInt(u32, buf[o..][0..4], 0, .little);
    std.mem.writeInt(u32, buf[o + 4 ..][0..4], 0, .little);

    return total;
}
