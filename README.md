# ZirconOSLuna — Windows XP Luna 风格 Shell / 主题库

**独立 Zig 仓库**，实现 Luna 视觉下的桌面 Shell 状态机、主题常量、脏区渲染协调与资源路径。**不是**完整操作系统内核；若需要「从引导到 Shell」的全栈说明，见 **`docs/KERNEL_AND_STACK_CN.md`**；**文档总索引与 XP x64 复现阅读路径** 见 [`docs/README.md`](docs/README.md)。

## 仓库目录（与 NT 型 OS 工程顶层同名对照）

下列布局便于与 **经典 Windows NT 风格内核/子系统工程** 对照阅读：带 `README.md` 的目录已说明「完整系统里是什么 / 本仓库里是什么」。

```
├── docs/
│   ├── README.md                      # 文档索引
│   ├── KERNEL_AND_STACK_CN.md         # 内核→Shell 全栈与本仓库边界
│   └── REPOSITORY_LAYOUT_CN.md        # src/ 与完整 OS 工程对照
├── build.zig
├── build.zig.zon
├── README.md
└── src/
    ├── root.zig                       # Zig 模块根（导出 Luna + config/hal/drivers…）
    ├── main.zig                       # 本包 CLI / 自测（非内核入口）
    ├── config/                        # Shell/主题默认配置
    ├── arch/                          # 宿主 ABI（LLP64 等），非引导
    ├── hal/                           # 帧缓冲表面（呈现用 HAL，非内核 HAL 全集）
    ├── drivers/video/                 # 用户态显示管线（脏区+present）
    ├── ke/  mm/  ob/  ps/  se/         # 占位：与内核子系统边界说明
    ├── io/  lpc/                      # 占位
    ├── rtl/                           # 轻量日志等
    ├── fs/  loader/                   # 占位
    ├── libs/win32/                    # HWND/NT 常量转发
    ├── kernel/nt52/                   # NT 5.2 规范常量（非内核镜像）
    ├── servers/                       # 占位：与 csrss 等服务边界
    └── desktop/
        └── luna/                      # Luna 实现主体（Shell、控件、主题、资源）
```

## 内核 / 驱动 / 开发结构 在哪里？

| 需求 | 位置 |
|------|------|
| **内核、调度、内存、对象、安全、I/O、IPC** 的分层说明 | [`docs/KERNEL_AND_STACK_CN.md`](docs/KERNEL_AND_STACK_CN.md) |
| **为何有 `ke/`、`mm/` 等空目录** | 各目录 `README.md` + [`docs/REPOSITORY_LAYOUT_CN.md`](docs/REPOSITORY_LAYOUT_CN.md) |
| **驱动** | 本仓库仅有 **用户态** `drivers/video/`（与 KMD 不同）；硬件 DMA 等不在此范围 |
| **HAL** | `src/hal/framebuffer.zig` 仅描述 **帧缓冲契约** |
| **可编译 API 入口** | `src/desktop/luna/root.zig` 导出 `config`、`hal`、`drivers.video`、`win32` 等 |

## 构建

推荐使用 **Makefile**（与常见 Zig OS 工程一致；`make help` 查看目标）：

```bash
make build          # zig build
make test           # zig build test
make run            # 构建 ISO 并用 QEMU 启动内核（默认弹出图形窗口；串口日志仍在终端）
make fetch-resources   # 下载 Bliss 壁纸等到 src/desktop/luna/resources/
make clean
```

无图形环境或 CI：`make run QEMU_NOGRAPHIC=1` 或 `zig build run-kernel -Dqemu-nographic=true`。

亦可直接使用 Zig：

```bash
zig build
zig build test
zig build run
zig build run-kernel              # QEMU 图形 + -serial stdio
zig build run-kernel -Dqemu-nographic=true   # 无窗口，仅串口
```

- **NT 5.2 架构长文**：[`docs/NT52_KERNEL_ARCH_CN.md`](docs/NT52_KERNEL_ARCH_CN.md)（与 [`ideas/arch_doc.md`](ideas/arch_doc.md) 同步）  
- **论坛与资料**：[`docs/REFERENCES_CN.md`](docs/REFERENCES_CN.md)  
- **规范常量（非内核镜像）**：[`src/kernel/nt52/spec.zig`](src/kernel/nt52/spec.zig)  

> 说明：本仓库 **不实现** 完整 `ntoskrnl`；`kernel/nt52` 仅作 NT 5.2 产品线对照。完整微内核工程可参考独立 OS 仓库的目录与引导链；[ZirconOSAero](https://github.com/MobtgZhang/ZirconOSAero) 为 **NT 6.1** 路线示例，**勿与 NT 5.2 目标混淆**。

## 许可

见 `LICENSE`。
