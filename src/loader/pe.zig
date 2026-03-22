//! PE 头魔数与常量。本仓库不实现映像加载器。

const std = @import("std");

pub const IMAGE_DOS_SIGNATURE: u16 = 0x5A4D;
pub const IMAGE_NT_SIGNATURE: u32 = 0x00004550;

pub const IMAGE_FILE_MACHINE_AMD64: u16 = 0x8664;

pub const IMAGE_NUMBEROF_DIRECTORY_ENTRIES: u8 = 16;

pub const IMAGE_DIRECTORY_ENTRY_EXPORT: u8 = 0;
pub const IMAGE_DIRECTORY_ENTRY_IMPORT: u8 = 1;
pub const IMAGE_DIRECTORY_ENTRY_TLS: u8 = 9;
pub const IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG: u8 = 10;

test "pe" {
    try std.testing.expect(IMAGE_DOS_SIGNATURE == 0x5A4D);
    try std.testing.expect(IMAGE_NT_SIGNATURE == 0x00004550);
}
