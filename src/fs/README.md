# fs — File System（本仓库边界）

完整系统中：**VFS、IRP_MJ_READ、缓存管理器**。

**本仓库不实现** 文件系统。资源路径见 `desktop/luna/resources.zig`，由宿主按路径加载位图。
