/* ZirconOSLuna 内核链接脚本
 * Multiboot2 约定：加载到 1MB (0x100000)
 */
OUTPUT_FORMAT("elf64-x86-64")
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

SECTIONS
{
    /* LLD 中 `1M` 可能被解析为 0x1000000；显式 1MiB */
    . = 0x100000;

    .multiboot2 : ALIGN(8) {
        *(.multiboot2)
    }

    .text : ALIGN(4096) {
        *(.text .text.*)
    }

    .rodata : ALIGN(4096) {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(4096) {
        *(.data .data.*)
    }

    .bss : ALIGN(4096) {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.note.GNU-stack)
    }
}
