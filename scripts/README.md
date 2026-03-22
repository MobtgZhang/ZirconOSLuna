# scripts

| 脚本 | 说明 |
|------|------|
| `fetch-resources.sh` | 从网络下载壁纸等资源至 `src/desktop/luna/resources/`（由 `make fetch-resources` 调用） |
| `fetch-ovmf.sh` | 从 [edk2-nightly](https://retrage.github.io/edk2-nightly/) 下载 `RELEASEX64_OVMF_{CODE,VARS}.fd` 至 `firmware/ovmf/`（`make fetch-ovmf`；UEFI+QEMU 用） |
