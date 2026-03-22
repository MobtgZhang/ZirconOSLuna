# drivers/video — 用户态显示管线

将 `desktop/luna` 中的 **脏区（render）** 与 `hal/framebuffer` 中的 **表面** 联系起来：  
宿主在合成一帧后调用 `display_manager.endFrameToHost`，内部触发 `render.presentComplete()` 与可选 `surface.present()`。
