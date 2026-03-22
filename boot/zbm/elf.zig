//! 极简 ELF64 加载（PT_LOAD → 物理 p_paddr），供 ZBM 按 ELF 布局放置内核。

const std = @import("std");

pub const PT_LOAD: u32 = 1;
pub const EM_X86_64: u16 = 62;

pub const Ehdr64 = extern struct {
    ident: [16]u8,
    @"type": u16,
    machine: u16,
    version: u32,
    entry: u64,
    phoff: u64,
    shoff: u64,
    flags: u32,
    ehsize: u16,
    phentsize: u16,
    phnum: u16,
    shentsize: u16,
    shnum: u16,
    shstrndx: u16,
};

pub const Phdr64 = extern struct {
    @"type": u32,
    flags: u32,
    offset: u64,
    vaddr: u64,
    paddr: u64,
    filesz: u64,
    memsz: u64,
    p_align: u64,
};

pub fn isElf64(e: *const Ehdr64) bool {
    return e.ident[0] == 0x7f and
        e.ident[1] == 'E' and e.ident[2] == 'L' and e.ident[3] == 'F' and
        e.ident[4] == 2; // ELFCLASS64
}

pub fn loadSegments(kernel: []const u8) error{ BadElf, OutOfBounds, BadPhdr }!u64 {
    if (kernel.len < @sizeOf(Ehdr64)) return error.BadElf;
    const e: *align(@alignOf(Ehdr64)) const Ehdr64 = @ptrCast(@alignCast(kernel.ptr));
    if (!isElf64(e)) return error.BadElf;
    if (e.machine != EM_X86_64) return error.BadElf;
    if (e.phentsize < @sizeOf(Phdr64)) return error.BadPhdr;

    var max_end: u64 = 0;
    var i: u16 = 0;
    while (i < e.phnum) : (i += 1) {
        const off = e.phoff + @as(u64, i) * e.phentsize;
        if (off + @sizeOf(Phdr64) > kernel.len) return error.OutOfBounds;
        const ph: *align(1) const Phdr64 = @ptrCast(&kernel[@intCast(off)]);
        if (ph.type != PT_LOAD) continue;

        const dest = ph.paddr;
        if (ph.filesz > ph.memsz) return error.BadPhdr;
        if (ph.offset > kernel.len or ph.offset + ph.filesz > kernel.len) return error.OutOfBounds;

        const dst: [*]u8 = @ptrFromInt(dest);
        const src = kernel[@intCast(ph.offset)..][0..@intCast(ph.filesz)];
        @memcpy(dst[0..src.len], src);
        if (ph.memsz > ph.filesz) {
            const z = @as(usize, @intCast(ph.memsz - ph.filesz));
            @memset(dst[src.len..][0..z], 0);
        }
        const seg_end = dest + ph.memsz;
        max_end = @max(max_end, seg_end);
    }
    return max_end;
}

/// PT_LOAD 覆盖的物理页：向下对齐到 4KiB 的基址与页数，以及 ELF 入口（物理）。
pub fn loadSpan(kernel: []const u8) error{ BadElf, OutOfBounds, BadPhdr }!struct {
    base: u64,
    page_count: usize,
    entry: u64,
} {
    if (kernel.len < @sizeOf(Ehdr64)) return error.BadElf;
    const e: *align(@alignOf(Ehdr64)) const Ehdr64 = @ptrCast(@alignCast(kernel.ptr));
    if (!isElf64(e)) return error.BadElf;
    if (e.machine != EM_X86_64) return error.BadElf;
    if (e.phentsize < @sizeOf(Phdr64)) return error.BadPhdr;

    var min_p: u64 = std.math.maxInt(u64);
    var max_p: u64 = 0;
    var i: u16 = 0;
    while (i < e.phnum) : (i += 1) {
        const off = e.phoff + @as(u64, i) * e.phentsize;
        if (off + @sizeOf(Phdr64) > kernel.len) return error.OutOfBounds;
        const ph: *align(1) const Phdr64 = @ptrCast(&kernel[@intCast(off)]);
        if (ph.type != PT_LOAD) continue;
        min_p = @min(min_p, ph.paddr);
        max_p = @max(max_p, ph.paddr + ph.memsz);
    }
    if (min_p == std.math.maxInt(u64) or max_p == 0) return error.BadElf;
    const base = min_p & ~@as(u64, 4095);
    const span = max_p - base;
    const page_count: usize = @intCast((span + 4095) / 4096);
    return .{ .base = base, .page_count = page_count, .entry = e.entry };
}
