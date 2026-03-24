/* loongarch64 最小内核占位（1MiB；真机/固件地址以后可再调） */
OUTPUT_FORMAT("elf64-loongarch")
OUTPUT_ARCH(loongarch)
ENTRY(_start)

SECTIONS
{
    . = 0x100000;

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
        *(.bss .bss.*)
        *(COMMON)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.note.GNU-stack)
    }
}
