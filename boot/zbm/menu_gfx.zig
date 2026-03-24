//! Windows XP 风格 GOP 底图：Luna 标题条 + 经典「对话框灰」客户区。
//! 高亮由 ConOut 文本属性完成；本模块仅在整页重绘时填充底图（换选项时与 `clearScreen` 后衔接）。

const uefi = @import("std").os.uefi;

fn fillRect(gop: *uefi.protocol.GraphicsOutput, x: u32, y: u32, w: u32, h: u32, r: u8, g: u8, b: u8) void {
    if (w == 0 or h == 0) return;
    var px = uefi.protocol.GraphicsOutput.BltPixel{
        .blue = b,
        .green = g,
        .red = r,
        .reserved = 0xFF,
    };
    const src: [*]uefi.protocol.GraphicsOutput.BltPixel = @ptrCast(&px);
    gop.blt(src, .blt_video_fill, 0, 0, x, y, w, h, 0) catch {};
}

/// 绘制一次 XP 风格全屏底图（标题栏渐变 + 3D 底边线 + 客户区灰底）。与文本菜单叠加时由 ConOut 前景/背景色分区配合。
pub fn paintXpChrome(gop: *uefi.protocol.GraphicsOutput) void {
    const mode = gop.mode.*;
    const w = mode.info.horizontal_resolution;
    const h = mode.info.vertical_resolution;
    if (w < 80 or h < 200) return;

    const title_h: u32 = @min(52, @max(36, h / 14));

    // 标题栏：Luna 蓝上下分层（#4A7DD7 → #2454B5，RGB）
    const h1 = title_h / 2;
    fillRect(gop, 0, 0, w, h1, 0x4A, 0x7D, 0xD7);
    fillRect(gop, 0, h1, w, title_h - h1, 0x24, 0x54, 0xB5);
    // 标题栏下沿深色线（#18364A）
    fillRect(gop, 0, title_h - 1, w, 1, 0x18, 0x36, 0x4A);
    // 客户区 #ECE9D8
    if (title_h < h) {
        fillRect(gop, 0, title_h, w, h - title_h, 0xEC, 0xE9, 0xD8);
    }
}
