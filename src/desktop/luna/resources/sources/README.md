# 矢量 / 源文件说明

本主题光栅图由仓库根目录下的 [`scripts/gen_luna_resources.py`](../../../../../scripts/gen_luna_resources.py) **程序化绘制**（Pillow），不依赖外部位图素材。若需修改造型或配色，请编辑该脚本后重新运行：

```bash
python3 scripts/gen_luna_resources.py
```

未单独维护逐文件的 SVG，以避免与 PNG 漂移；**脚本即单一事实来源（SSOT）**。

内核 `luna` 桌面（`src/kernel/gui/luna_desktop.zig`）无 PNG 解码器，使用与上相同的 PNG 经脚本导出的 `src/kernel/gui/data/*.rgba`（32×32 RGBA8）；修改图标后请重新运行 `python3 scripts/gen_luna_resources.py`。
