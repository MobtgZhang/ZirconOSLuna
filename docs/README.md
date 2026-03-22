# 文档索引

面向 **复现 / 对照 Windows XP Professional x64（NT 5.2）** 与理解本仓库边界时，建议按下表顺序阅读。

| 文档 | 内容 |
|------|------|
| [NT52_KERNEL_ARCH_CN.md](NT52_KERNEL_ARCH_CN.md) | NT 5.2 x64：VA、WOW64、执行体、驱动签名与 PatchGuard、引导与调试生态 |
| [REFERENCES_CN.md](REFERENCES_CN.md) | **开发者论坛与资料**（MSFN x64 版块、OSR、OSDev、微软存档文档等） |
| [PLAN_KERNEL_ARCH_CN.md](PLAN_KERNEL_ARCH_CN.md) | 内核规范层规划与 **当前代码落地** 对照 |
| [KERNEL_AND_STACK_CN.md](KERNEL_AND_STACK_CN.md) | 自底向上 NT 型栈、WOW64 位置、Multiboot 实验内核与 **本仓库落点** |
| [REPOSITORY_LAYOUT_CN.md](REPOSITORY_LAYOUT_CN.md) | `src/` 与完整 NT 型工程目录对照 |
| `../src/desktop/luna/docs/TARGET_NT.md` | NT 5.1/5.2 与 SDK 宏（Shell 目标） |

---

## 复现「XP x64 体验」时的推荐阅读路径

1. **先定边界**：本仓库主体是 **Luna Shell / 主题 / 呈现协调** 与用户态规范桩；完整 `ntoskrnl` 与官方二进制引导链不在范围内（见 [KERNEL_AND_STACK_CN.md](KERNEL_AND_STACK_CN.md)）。  
2. **再对齐版本**：NT 5.2 与 **WOW64、强制驱动签名、PatchGuard** 等与 32 位 XP（NT 5.1）差异见 [NT52_KERNEL_ARCH_CN.md](NT52_KERNEL_ARCH_CN.md)。  
3. **查社区与官方存档**：驱动、整合盘、新硬件兼容、KMD 调试等以 [REFERENCES_CN.md](REFERENCES_CN.md) 为入口。  
4. **对照代码常量**：`src/kernel/nt52/spec.zig`、`src/mm/va_layout.zig` 等与文档交叉验证。
