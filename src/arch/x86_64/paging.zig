//! AMD64 4 级页表布局常量。见 ideas/arch_doc.md 第三节。
//!
//! 虚拟地址 = [63:48] 符号扩展 | [47:39] PML4 | [38:30] PDPT | [29:21] PD | [20:12] PT | [11:0] 页内偏移

const std = @import("std");

pub const PML4_INDEX_SHIFT: u6 = 39;
pub const PDPT_INDEX_SHIFT: u6 = 30;
pub const PD_INDEX_SHIFT: u6 = 21;
pub const PT_INDEX_SHIFT: u6 = 12;

pub const PML4_INDEX_MASK: u64 = 0x1FF;
pub const PDPT_INDEX_MASK: u64 = 0x1FF;
pub const PD_INDEX_MASK: u64 = 0x1FF;
pub const PT_INDEX_MASK: u64 = 0x1FF;

/// 页表项标志（x86-64 规范）
pub const PTE_PRESENT: u64 = 1 << 0;
pub const PTE_WRITE: u64 = 1 << 1;
pub const PTE_USER: u64 = 1 << 2;
pub const PTE_NX: u64 = 1 << 63;

pub fn getPml4Index(va: u64) u9 {
    return @truncate((va >> PML4_INDEX_SHIFT) & PML4_INDEX_MASK);
}

pub fn getPdptIndex(va: u64) u9 {
    return @truncate((va >> PDPT_INDEX_SHIFT) & PDPT_INDEX_MASK);
}

test "paging indices" {
    const va: u64 = 0x00000001_23456000;
    try std.testing.expect(getPml4Index(va) == 0);
    try std.testing.expect(getPdptIndex(va) == 0x48);
}
