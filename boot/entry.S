/* ZirconOSLuna x86-64 bootstrap
 * Multiboot2 入口 → 长模式切换 → 跳转 kernel_main
 * 由 ZirconOS Boot Manager（UEFI）或兼容 Multiboot2 的引导器载入
 */

/* Multiboot2 常量 */
.set MB2_MAGIC,        0xE85250D6
.set MB2_ARCH,         0
.set MB2_HEADER_LEN,   (multiboot2_header_end - multiboot2_header)
.set MB2_CHECKSUM,     -(MB2_MAGIC + MB2_ARCH + MB2_HEADER_LEN)
.set MB2_TAG_END,      0
.set MB2_TAG_END_SIZE, 8

/* 页表地址（物理 0x1000 起，避免覆盖 0-1MB 低端内存） */
.set PML4_ADDR,  0x1000
.set PDPT_ADDR,  0x2000
.set PD_ADDR,    0x3000

.set PTE_PRESENT,  1
.set PTE_WRITE,    2
/* PD 项上的 PS=1 → 2MiB 大页（恒等映射低 1GiB，覆盖 GRUB 按 ELF 加载的高位物理） */
.set PTE_PS,       (1 << 7)

.set CR0_PG,   (1 << 31)
.set CR0_PE,   (1 << 0)
.set CR4_PAE,  (1 << 5)
.set EFER_MSR, 0xC0000080
.set EFER_LME, (1 << 8)

/* GRUB 传入：EAX=0x36D76289, EBX=Multiboot2 info 物理地址 */

.section .multiboot2
.align 8
multiboot2_header:
    .long MB2_MAGIC
    .long MB2_ARCH
    .long MB2_HEADER_LEN
    .long MB2_CHECKSUM
    /* Tag 1: information request — mmap(6) + framebuffer(8)，便于 UEFI 上 GRUB 提供 GOP 信息 */
    .short 1
    .short 0
    .long 16
    .long 6
    .long 8
    /* Tag 5: framebuffer — 声明图形控制台偏好（UEFI 下避免默认识别为 EGA 文本 → “no console” 警告） */
    .short 5
    .short 0
    .long 20
    .long 0
    .long 0
    .long 32
    .balign 8
    /* Tag 0: end */
    .short MB2_TAG_END
    .short 0
    .long MB2_TAG_END_SIZE
multiboot2_header_end:

.section .text
.code32
.global _start
.type _start, @function
_start:
    cli
    /* 保存 Multiboot magic 与 info 指针（32 位地址） */
    movl %eax, mb2_magic
    movl %ebx, mb2_info

    /* 清零 PML4 + PDPT + PD（3 页） */
    movl $PML4_ADDR, %edi
    xorl %eax, %eax
    movl $3072, %ecx
    rep stosl

    /* PML4[0] -> PDPT */
    movl $PDPT_ADDR, %eax
    orl  $(PTE_PRESENT | PTE_WRITE), %eax
    movl %eax, (PML4_ADDR)
    movl $0, (PML4_ADDR + 4)

    /* PDPT[0] -> PD */
    movl $PD_ADDR, %eax
    orl  $(PTE_PRESENT | PTE_WRITE), %eax
    movl %eax, (PDPT_ADDR)
    movl $0, (PDPT_ADDR + 4)

    /* PD：512 × 2MiB 大页 = 1GiB 恒等映射（物理 0 起；GOP 帧缓冲常在低端以下，PMM 页表亦在此范围） */
    movl $PD_ADDR, %edi
    xorl %esi, %esi
    movl $512, %ecx
map2m:
    movl %esi, %eax
    orl  $(PTE_PRESENT | PTE_WRITE | PTE_PS), %eax
    movl %eax, (%edi)
    movl $0, 4(%edi)
    addl $8, %edi
    addl $0x200000, %esi
    loop map2m

    /* CR3 = PML4 */
    movl $PML4_ADDR, %eax
    movl %eax, %cr3

    /* CR4.PAE = 1 */
    movl %cr4, %eax
    orl  $CR4_PAE, %eax
    movl %eax, %cr4

    /* EFER.LME = 1 */
    movl $EFER_MSR, %ecx
    rdmsr
    orl  $EFER_LME, %eax
    wrmsr

    /* CR0.PG + CR0.PE */
    movl %cr0, %eax
    orl  $(CR0_PG | CR0_PE), %eax
    movl %eax, %cr0

    /* 远跳转入 64 位模式 */
    lgdt gdt64_pointer
    ljmp $0x08, $long_mode_entry

.code64
long_mode_entry:
    /* 设置数据段 */
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    /* 设置栈（内核加载在 1MB，栈向下生长） */
    leaq _stack_top(%rip), %rsp

    /* 调用 Zig 内核入口：magic(u32), info(物理指针) */
    movl mb2_magic(%rip), %edi
    movq mb2_info(%rip), %rsi
    call kernel_main

halt:
    cli
    hlt
    jmp halt

/* GDT: Null + Code64 + Data64 */
.align 8
gdt64:
    .quad 0
    .quad 0x00AF9A000000FFFF  /* Code: 64-bit, exec, present */
    .quad 0x00CF92000000FFFF  /* Data: 64-bit, rw, present */
gdt64_pointer:
    .word gdt64_pointer - gdt64 - 1
    .quad gdt64

.section .bss
.align 16
mb2_magic:
    .long 0
mb2_info:
    .quad 0

/* 栈：2MiB（Debug 下 Luna 主循环栈帧极大，256KiB 曾致返回地址破坏与 #PF） */
.space (2 * 1024 * 1024)
.global _stack_top
_stack_top:
