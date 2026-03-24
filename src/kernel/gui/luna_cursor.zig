//! 与 `resources/cursors/cursor_arrow.png` 同步的 32×32 RGBA（脚本写入 `data/cursor_arrow.rgba`）。

pub const width: u32 = 32;
pub const height: u32 = 32;
/// 箭头尖端像素（与脚本生成的多边形一致）。
pub const hotspot_x: u32 = 1;
pub const hotspot_y: u32 = 1;
pub const rgba = @embedFile("data/cursor_arrow.rgba");
