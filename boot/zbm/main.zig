//! ZirconOS Boot Manager — UEFI：zbm.ini 菜单、加载 ELF、Multiboot2、x86_64 跳板。

const std = @import("std");
const uefi = std.os.uefi;
const elf = @import("elf.zig");
const mb2 = @import("mb2.zig");
const zbm_ini = @import("zbm_ini.zig");
const menu_boot = @import("menu_boot.zig");
const gop_setup = @import("gop_setup.zig");

extern const zbm_trampoline_blob_start: u8;
extern const zbm_trampoline_blob_end: u8;

/// Multiboot2 信息块物理基址：须低于内核 `0x100000` 且避开 trampoline `0x8000`/`scratch 0x87F0`。
/// 内核在 `init.snapshotMultibootInfo` 会拷入 BSS 再解析，降低 ExitBootServices 后低端页被复用的风险。
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

fn fmtU16Dec(buf: *[8]u8, v: u16) []const u8 {
    if (v == 0) {
        buf[0] = '0';
        return buf[0..1];
    }
    var n = v;
    var i: usize = 0;
    while (n > 0) : (n /= 10) {
        buf[i] = @intCast('0' + (n % 10));
        i += 1;
    }
    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const t = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = t;
    }
    return buf[0..i];
}

fn reportWrongKernelIsa(st: *uefi.tables.SystemTable, em: u16) noreturn {
    if (st.con_out) |co| {
        menu_boot.outputAscii(co, "\r\n*** ZBM: cannot boot this kernel ***\r\n");
        menu_boot.outputAscii(co, "This BOOTX64.EFI only starts x86_64 Multiboot2 ELF (e_machine=");
        var tmp: [8]u8 = undefined;
        menu_boot.outputAscii(co, fmtU16Dec(&tmp, elf.EM_X86_64));
        menu_boot.outputAscii(co, ").\r\nYour file: e_machine=");
        menu_boot.outputAscii(co, fmtU16Dec(&tmp, em));
        menu_boot.outputAscii(co, "\r\n");
        menu_boot.outputAscii(co, elf.machineHint(em));
        menu_boot.outputAscii(co, "\r\nUse x86_64 kernel on PC QEMU, or native LoongArch UEFI chain.\r\n");
    }
    hang();
}

fn defaultBootConfig() zbm_ini.Parsed {
    var p = zbm_ini.Parsed{
        .timeout_sec = 10,
        .default_index = 0,
        .gfx_menu = false,
        .entry_count = 1,
    };
    p.entries[0].title = "ZirconOS default";
    p.entries[0].active = true;
    p.entries[0].path_len = zbm_ini.utf8PathToUtf16Le("\\BOOT\\ZKERNEL.ELF", &p.entries[0].path_utf16);
    return p;
}

fn loadBootConfig(root: *uefi.protocol.File) zbm_ini.Parsed {
    const wini = std.unicode.utf8ToUtf16LeStringLiteral("\\BOOT\\zbm.ini");
    const f = root.open(@as([*:0]const u16, @ptrCast(wini)), .read, .{}) catch return defaultBootConfig();
    defer f.close() catch {};
    var buf: [8192]u8 = undefined;
    const n = f.read(&buf) catch return defaultBootConfig();
    const parsed = zbm_ini.parse(buf[0..n]);
    if (parsed.entry_count == 0) return defaultBootConfig();
    return parsed;
}

fn zbmMain(st: *uefi.tables.SystemTable, bs: *uefi.tables.BootServices) anyerror!noreturn {
    bs.setWatchdogTimer(0, 0, null) catch {};

    const loaded = (try bs.handleProtocol(uefi.protocol.LoadedImage, uefi.handle)) orelse
        return error.NoLoadedImage;
    const dev = loaded.device_handle orelse return error.NoDevice;
    const sfs = (try bs.handleProtocol(uefi.protocol.SimpleFileSystem, dev)) orelse
        return error.NoFs;

    const root = try sfs.openVolume();
    defer root.close() catch {};

    var cfg = loadBootConfig(root);

    var gop: ?*uefi.protocol.GraphicsOutput = null;
    var fb_tag: ?mb2.FramebufferRgb = null;
    if (cfg.gfx_menu) {
        gop = gop_setup.initGopForMenu(bs);
        if (gop) |g| {
            fb_tag = gop_setup.framebufferRgbFromGop(g);
        }
    }

    const slot = menu_boot.run(st, bs, &cfg, gop);

    if (fb_tag == null) {
        gop = gop_setup.initGopForMenu(bs);
        if (gop) |g| {
            fb_tag = gop_setup.framebufferRgbFromGop(g);
        }
    }

    const path_ptr: [*:0]const u16 = @ptrCast(&cfg.entries[slot].path_utf16);
    const kfile = try root.open(path_ptr, .read, .{});
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
    const em = elf.peekMachine(kbuf[0..fsize]) catch {
        if (st.con_out) |co| {
            menu_boot.outputAscii(co, "\r\nZBM: kernel file is not ELF64.\r\n");
        }
        hang();
    };
    if (em != elf.EM_X86_64) {
        reportWrongKernelIsa(st, em);
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
        _ = try mb2.build(mb2_dst[0 .. mb2_pages * 4096], ms, fb_tag);

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
