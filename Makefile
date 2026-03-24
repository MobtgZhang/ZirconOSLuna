# ZirconOSLuna — Luna Shell / NT 5.2 对照内核
# 构建系统从 build.conf 读取配置。覆盖：make DESKTOP=luna OPTIMIZE=ReleaseFast
#
# 需：zig, qemu-system-x86_64, xorriso, dosfstools(mkfs.fat), mtools(mcopy)

-include build.conf
# 与 DESKTOP 同义，仅命名上与 KERNEL_DESKTOP 对称（可不设置，默认随 DESKTOP）
HOST_DESKTOP ?= $(DESKTOP)
ZIG ?= zig
OUT ?= zig-out
OPTIMIZE ?= Debug
KERNEL_OPTIMIZE ?= Debug
QEMU ?= qemu-system-x86_64
QEMU_MEM ?= 512M
# 1 = 无图形（仅串口，适合 SSH/CI）；0 = 默认弹出 QEMU 窗口，串口仍在终端
QEMU_NOGRAPHIC ?= 0

# 若 build.conf 未定义则回退（与 build.zig 默认一致；PC QEMU 常用 KERNEL_ARCH=x86_64）
BOOT_METHOD ?= mbr
KERNEL_ARCH ?= loongarch64
KERNEL_DESKTOP ?= cmd
KERNEL_DEBUG_LOG ?=
ZBM_FB_WIDTH ?= 1024
ZBM_FB_HEIGHT ?= 768
# 与 build.conf 一致：edk2-nightly RELEASE X64（make fetch-ovmf 下载到 firmware/ovmf/）
OVMF_CODE ?= firmware/ovmf/RELEASEX64_OVMF_CODE.fd
OVMF_VARS ?= firmware/ovmf/RELEASEX64_OVMF_VARS.fd

QEMU_HEADLESS_FLAG := $(if $(filter 1,$(QEMU_NOGRAPHIC)),-Dqemu-nographic=true,)
ZIG_KERNEL_OPTS := -Dkernel-arch=$(KERNEL_ARCH) -Dkernel-desktop=$(KERNEL_DESKTOP) -Dzbm-fb-width=$(ZBM_FB_WIDTH) -Dzbm-fb-height=$(ZBM_FB_HEIGHT)
ZIG_QEMU_OPTS := -Dboot-method=$(BOOT_METHOD) -Dovmf-code=$(OVMF_CODE) -Dovmf-vars=$(OVMF_VARS)

.PHONY: all help build build-release test run run-release run-desktop kernel iso run-kernel clean fetch-resources fetch-ovmf

# ══════════════════════════════════════════════════════
# 默认目标：构建并 QEMU 启动系统（参考 ZirconOS）
# ══════════════════════════════════════════════════════

all: run

help:
	@echo "ZirconOSLuna — Luna / NT 5.2 对照"
	@echo ""
	@echo "  make             - 构建 + QEMU 启动系统（默认）"
	@echo "  make run         - 同上"
	@echo "  make build       - 仅构建宿主可执行与内核"
	@echo "  make build-release  - ReleaseSafe 构建"
	@echo "  make kernel     - 编译内核 (-Dkernel-arch，默认见 build.conf / zig build)"
	@echo "  make iso        - 生成 ZBM UEFI 可引导 ISO"
	@echo "  make run-kernel - QEMU 运行内核（默认 GUI；QEMU_NOGRAPHIC=1 仅串口）"
	@echo "  调试/发行：OPTIMIZE=ReleaseSafe + KERNEL_DEBUG_LOG=false 安静内核日志"
	@echo "  内核 Luna 桌面：KERNEL_DESKTOP=luna + BOOT_METHOD=uefi（需 OVMF，make fetch-ovmf）"
	@echo "  make run-desktop - 宿主运行 Luna 桌面（非 QEMU）"
	@echo "  make test       - 运行测试"
	@echo "  make fetch-resources - 下载壁纸等资源"
	@echo "  make fetch-ovmf      - 下载 UEFI OVMF（edk2-nightly，见 build.conf）"
	@echo "  make clean      - 删除 zig-out 与 .zig-cache"
	@echo ""
	@echo "编译参数：编辑 build.conf（KERNEL_ARCH、BOOT_METHOD、DESKTOP/KERNEL_DESKTOP 等）"
	@echo "NT 5.2 架构：docs/NT52_KERNEL_ARCH_CN.md"

build:
	$(ZIG) build -Doptimize=$(OPTIMIZE) $(ZIG_KERNEL_OPTS)

build-release:
	$(ZIG) build -Doptimize=ReleaseSafe

test:
	$(ZIG) build test -Doptimize=$(OPTIMIZE) $(ZIG_KERNEL_DEBUG)

# run: 构建内核+ISO 并在 QEMU 中启动（主入口）
run:
	$(ZIG) build run-kernel -Doptimize=$(OPTIMIZE) $(ZIG_KERNEL_OPTS) $(ZIG_KERNEL_DEBUG) $(ZIG_QEMU_OPTS) -Dqemu=$(QEMU) -Dqemu-mem=$(QEMU_MEM) $(QEMU_HEADLESS_FLAG)

# ReleaseSafe 内核 + ZBM；需安静串口可设 KERNEL_DEBUG_LOG=false
run-release:
	$(ZIG) build run-kernel -Doptimize=ReleaseSafe $(ZIG_KERNEL_OPTS) $(ZIG_KERNEL_DEBUG) $(ZIG_QEMU_OPTS) -Dqemu=$(QEMU) -Dqemu-mem=$(QEMU_MEM) $(QEMU_HEADLESS_FLAG)

# run-desktop: 宿主直接运行 Luna 桌面（非 QEMU）
run-desktop:
	$(ZIG) build run -Doptimize=$(OPTIMIZE)

kernel:
	$(ZIG) build kernel -Doptimize=$(KERNEL_OPTIMIZE) $(ZIG_KERNEL_OPTS) $(ZIG_KERNEL_DEBUG)

iso:
	$(ZIG) build iso -Doptimize=$(OPTIMIZE) $(ZIG_KERNEL_OPTS) $(ZIG_KERNEL_DEBUG)

run-kernel:
	$(ZIG) build run-kernel -Doptimize=$(OPTIMIZE) $(ZIG_KERNEL_OPTS) $(ZIG_KERNEL_DEBUG) $(ZIG_QEMU_OPTS) -Dqemu=$(QEMU) -Dqemu-mem=$(QEMU_MEM) $(QEMU_HEADLESS_FLAG)

fetch-resources:
	@chmod +x scripts/fetch-resources.sh
	@./scripts/fetch-resources.sh

fetch-ovmf:
	@chmod +x scripts/fetch-ovmf.sh
	@./scripts/fetch-ovmf.sh

clean:
	rm -rf $(OUT) .zig-cache
