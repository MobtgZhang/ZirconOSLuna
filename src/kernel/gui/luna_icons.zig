//! 与 `resources/icons/` 同步的 32×32 RGBA 原始像素（由 `scripts/gen_luna_resources.py` 写入 `data/*.rgba`）。

pub const size: u32 = 32;
pub const bytes_per_icon: usize = 32 * 32 * 4;

pub const my_computer = @embedFile("data/icon_mycomputer.rgba");
pub const my_documents = @embedFile("data/icon_mydocuments.rgba");
pub const recycle_empty = @embedFile("data/icon_recyclebin_empty.rgba");
pub const network = @embedFile("data/icon_network.rgba");
pub const internet = @embedFile("data/icon_internet.rgba");
