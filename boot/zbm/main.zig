//! ZirconOS Boot Manager — UEFI 应用：加载 ELF 内核、构造 Multiboot2、经跳板进入 32 位 _start。

const std = @import("std");
const uefi = std.os.uefi;
const elf = @import("elf.zig");
const mb2 = @import("mb2.zig");

extern const zbm_trampoline_blob_start: u8;
extern const zbm_trampoline_blob_end: u8;

const mb2_phys: u64 = 0x50000;
const tramp_phys: u64 = 0x8000;
const scratch_phys: u64 = 0x87F0;
pub fn main() noreturn {
    const st = uefi.system_table;
    const bs = st.boot_services.?;
    zbmMain(st, bs) catch {
        hang();
    };
    unreachable;
}

fn hang() noreturn {
    while (true) {
        asm volatile ("cli; hlt");
    }
}

fn zbmMain(_: *uefi.tables.SystemTable, bs: *uefi.tables.BootServices) anyerror!noreturn {
    bs.setWatchdogTimer(0, 0, null) catch {};

    const loaded = (try bs.handleProtocol(uefi.protocol.LoadedImage, uefi.handle)) orelse
        return error.NoLoadedImage;
    const dev = loaded.device_handle orelse return error.NoDevice;
    const sfs = (try bs.handleProtocol(uefi.protocol.SimpleFileSystem, dev)) orelse
        return error.NoFs;

    const root = try sfs.openVolume();
    defer root.close() catch {};

    const wpath = std.unicode.utf8ToUtf16LeStringLiteral("\\BOOT\\ZKERNEL.ELF");
    const kfile = try root.open(@as([*:0]const u16, @ptrCast(wpath)), .read, .{});
    defer kfile.close() catch {};

    const infosz = try kfile.getInfoSize(.file);
    var infobuf: [768]u8 align(8) = undefined;
    if (infosz > infobuf.len) return error.FileTooBig;
    const finfo = try kfile.getInfo(.file, infobuf[0..infosz]);
    const fsize: usize = @intCast(finfo.file_size);
    if (fsize > 16 * 1024 * 1024) return error.FileTooBig;

    const kbuf = try bs.allocatePool(.loader_data, fsize);
    try kfile.setPosition(0);
    var got: usize = 0;
    while (got < fsize) {
        const chunk_end = @min(got + 65536, fsize);
        const n = try kfile.read(kbuf[got..chunk_end]);
        if (n == 0) return error.ShortRead;
        got += n;
    }
    const span = try elf.loadSpan(kbuf[0..fsize]);
    if (span.page_count == 0) return error.NoLoad;
    if (span.entry > 0xffff_ffff) return error.NoLoad;

    const k_base: [*]align(4096) uefi.Page = @ptrFromInt(span.base);
    _ = try bs.allocatePages(.{ .address = k_base }, .loader_data, span.page_count);
    _ = try elf.loadSegments(kbuf[0..fsize]);

    const mb2_pages: usize = 16;
    const mb2_base: [*]align(4096) uefi.Page = @ptrFromInt(mb2_phys);
    _ = try bs.allocatePages(.{ .address = mb2_base }, .loader_data, mb2_pages);

    const tramp_base: [*]align(4096) uefi.Page = @ptrFromInt(tramp_phys);
    const tramp_slice = try bs.allocatePages(.{ .address = tramp_base }, .loader_data, 1);
    const tlen: usize = @intFromPtr(&zbm_trampoline_blob_end) - @intFromPtr(&zbm_trampoline_blob_start);
    if (tlen > 4096) return error.TrampolineTooLarge;
    const tdst: [*]u8 = @ptrCast(tramp_slice.ptr);
    const tsrc: [*]const u8 = @ptrCast(&zbm_trampoline_blob_start);
    @memcpy(tdst[0..tlen], tsrc[0..tlen]);

    const mmap_pool = try bs.allocatePool(.loader_data, 512 * 1024);
    const mmap_buf: []align(@alignOf(uefi.tables.MemoryDescriptor)) u8 = @alignCast(mmap_pool);

    while (true) {
        const ms = try bs.getMemoryMap(mmap_buf);
        const mb2_dst: [*]u8 = @ptrFromInt(mb2_phys);
        _ = try mb2.build(mb2_dst[0 .. mb2_pages * 4096], ms);

        const scratch: *volatile [3]u32 = @ptrFromInt(scratch_phys);
        scratch[0] = mb2.info_magic;
        scratch[1] = @truncate(mb2_phys);
        scratch[2] = @truncate(span.entry);

        bs.exitBootServices(uefi.handle, ms.info.key) catch {
            continue;
        };

        const te = @intFromPtr(tramp_slice.ptr);
        asm volatile (
            \\ movq %[e], %%rax
            \\ movabsq $0x90000, %%rsp
            \\ jmpq *%%rax
            :
            : [e] "r" (te)
            : .{ .memory = true }
        );
        unreachable;
    }
}
