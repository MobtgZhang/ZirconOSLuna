//! 与 `wallpapers/bliss_default.png` 缩略图同步（320×180 RGBA，运行时拉伸铺满工作区）。

pub const width: u32 = 320;
pub const height: u32 = 180;
pub const rgba = @embedFile("data/wallpaper_bliss_320x180.rgba");
