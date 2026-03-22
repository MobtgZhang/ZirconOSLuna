//! 用户态「视频路径」：连接 render 脏区与 HAL 帧缓冲呈现（非 KMD）。

const render = @import("../../desktop/luna/render.zig");
const fb = @import("../../hal/framebuffer.zig");

/// 一帧绘制结束：推进 render 帧序号，并通知宿主表面（双缓冲 flip 等）。
pub fn endFrameToHost(surface: ?*const fb.FramebufferSurface) void {
    render.presentComplete();
    if (surface) |s| {
        s.present();
    }
}

/// 当前是否仍有未呈现的脏区（供宿主循环查询）。
pub fn needsRedraw() bool {
    return render.needsRedraw();
}

pub const snapshotDirty = render.snapshotDirty;
