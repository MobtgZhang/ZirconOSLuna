//! 输入事件形状占位：与内核 PS/2 路径对齐时可共用同一套字段语义。
//!
//! 对照：[ps2_mouse.zig](../../kernel/hal/ps2_mouse.zig)（`dx`/`dy`/`left`）、[kbd.zig](../../kernel/hal/kbd.zig)（扫描码流）。

/// 指针设备增量（宿主可填绝对坐标时 `dx`/`dy` 即绝对值）。
pub const PointerSample = struct {
    dx: i16 = 0,
    dy: i16 = 0,
    left: bool = false,
    right: bool = false,
    middle: bool = false,
};

/// 键盘按键（简化：仅 ASCII / VK 低 8 位；扩展键由宿主约定 `flags`）。
pub const KeySample = struct {
    vk: u8 = 0,
    /// bit0=按下  bit1=Alt 修饰（与 Shell `param2!=0` 约定一致时可映射）
    flags: u8 = 0,
};
