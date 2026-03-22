# hal — 呈现用硬件抽象（非内核 HAL 全集）

完整内核中的 **HAL** 封装 CPU 特定中断、计时器、总线、DMA 等。

本仓库的 `framebuffer.zig` 仅描述 **帧缓冲 / 离屏表面** 的宿主侧契约，供 Shell 合成与驱动侧 `display_manager` 对接。  
**不**实现真实端口读写或内核态映射。
